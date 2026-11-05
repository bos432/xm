import gzip
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest

from restore_archive_safety import inspect_archive, inspect_sql_dump


class ArchiveSafetyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.archive = Path(self.temp.name) / 'private.tar.gz'

    def tearDown(self):
        self.temp.cleanup()

    def make_archive(self, entries):
        with tarfile.open(self.archive, 'w:gz') as target:
            for name, kind, data in entries:
                member = tarfile.TarInfo(name)
                member.type = kind
                member.size = len(data) if kind == tarfile.REGTYPE else 0
                member.linkname = '../../outside' if kind in (tarfile.SYMTYPE, tarfile.LNKTYPE) else ''
                target.addfile(member, io.BytesIO(data))

    def test_valid_archive_is_read_only_and_returns_counts(self):
        self.make_archive([('.', tarfile.DIRTYPE, b''), ('./docs', tarfile.DIRTYPE, b''),
                           ('./docs/file.pdf', tarfile.REGTYPE, b'content')])
        before = self.archive.read_bytes()
        self.assertEqual(inspect_archive(self.archive),
                         {'members': 3, 'files': 1, 'directories': 2, 'file_bytes': 7})
        self.assertEqual(before, self.archive.read_bytes())
        self.assertEqual(len(list(self.archive.parent.iterdir())), 1)

    def test_unsafe_paths_are_rejected(self):
        for name in ['../escape', 'a/../../escape', '/etc/passwd', '//server/file',
                     'C:/windows/file', 'a\\..\\escape']:
            with self.subTest(name=name):
                self.make_archive([(name, tarfile.REGTYPE, b'x')])
                with self.assertRaises(ValueError):
                    inspect_archive(self.archive)

    def test_links_devices_and_fifo_are_rejected(self):
        for kind in [tarfile.SYMTYPE, tarfile.LNKTYPE, tarfile.CHRTYPE,
                     tarfile.BLKTYPE, tarfile.FIFOTYPE]:
            with self.subTest(kind=kind):
                self.make_archive([('entry', kind, b'')])
                with self.assertRaises(ValueError):
                    inspect_archive(self.archive)

    def test_normalized_duplicates_are_rejected(self):
        self.make_archive([('a/file', tarfile.REGTYPE, b'x'),
                           ('./a/file', tarfile.REGTYPE, b'y')])
        with self.assertRaises(ValueError):
            inspect_archive(self.archive)

    def test_file_as_parent_is_rejected_in_either_order(self):
        entries = [('a', tarfile.REGTYPE, b'x'), ('a/file', tarfile.REGTYPE, b'y')]
        for values in [entries, list(reversed(entries))]:
            self.make_archive(values)
            with self.assertRaises(ValueError):
                inspect_archive(self.archive)

    def test_resource_limits_are_enforced(self):
        self.make_archive([('file', tarfile.REGTYPE, b'12345')])
        for limits in [{'max_archive_bytes': 1}, {'max_members': 0},
                       {'max_file_bytes': 4}, {'max_expanded_bytes': 32}]:
            with self.subTest(limits=limits):
                with self.assertRaises(ValueError):
                    inspect_archive(self.archive, **limits)

    def test_corrupt_gzip_footer_is_rejected_after_tar_end(self):
        self.make_archive([('file', tarfile.REGTYPE, b'x')])
        data = bytearray(self.archive.read_bytes())
        data[-8] ^= 1
        self.archive.write_bytes(data)
        with self.assertRaises(ValueError):
            inspect_archive(self.archive)

    def test_non_tar_and_truncated_gzip_are_rejected(self):
        for data in [gzip.compress(b'not a tar'), gzip.compress(b'x' * 1024)[:-4]]:
            self.archive.write_bytes(data)
            with self.assertRaises(ValueError):
                inspect_archive(self.archive)

    def test_empty_archive_is_rejected(self):
        self.make_archive([])
        with self.assertRaises(ValueError):
            inspect_archive(self.archive)

    def test_invalid_limits_are_rejected(self):
        self.make_archive([('file', tarfile.REGTYPE, b'x')])
        for key in ['max_archive_bytes', 'max_members', 'max_file_bytes', 'max_expanded_bytes']:
            with self.subTest(key=key), self.assertRaises(ValueError):
                inspect_archive(self.archive, **{key: -1})

    def test_deep_and_long_paths_are_rejected(self):
        for name in ['a/' * 65 + 'file', 'a' * 4097]:
            self.make_archive([(name, tarfile.REGTYPE, b'x')])
            with self.assertRaises(ValueError):
                inspect_archive(self.archive)

    def test_cli_returns_only_counts_and_refuses_unsafe_archive(self):
        self.make_archive([('private-name.pdf', tarfile.REGTYPE, b'private contents')])
        command = [sys.executable, '-B', str(Path(__file__).with_name('restore_archive_safety.py')),
                   str(self.archive)]
        result = subprocess.run(command, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)['files'], 1)
        self.assertNotIn('private', result.stdout)
        self.make_archive([('../private', tarfile.REGTYPE, b'private contents')])
        result = subprocess.run(command, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, '')
        self.assertNotIn('private contents', result.stderr)


class SqlDumpSafetyTest(unittest.TestCase):
    def inspect_text(self, text, **limits):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'database.sql.gz'
            path.write_bytes(gzip.compress(text.encode('utf-8')))
            return inspect_sql_dump(path, **limits)

    def test_mysqldump_schema_rows_routines_and_delimiters_are_scanned(self):
        dump = '''-- MySQL dump
CREATE TABLE `users` (`id` int);
INSERT INTO `users` VALUES (1, 'semicolon; USE production');
DELIMITER ;;
CREATE DEFINER=`app`@`localhost` PROCEDURE `touch_user`() BEGIN
  UPDATE `users` SET `id` = 1;
END;;
DELIMITER ;
'''
        report = self.inspect_text(dump)
        self.assertGreaterEqual(report['statements'], 3)
        self.assertGreater(report['expanded_bytes'], 0)

    def test_schema_switch_and_global_or_os_effects_are_rejected(self):
        statements = ['USE `production`;', 'CREATE DATABASE production;',
                      'DROP DATABASE IF EXISTS production;',
                      'CREATE USER `x`@`%`;', 'ALTER USER `x`@`%` IDENTIFIED BY \'x\';',
                      'GRANT ALL ON *.* TO `x`@`%`;', 'REVOKE ALL ON *.* FROM `x`@`%`;',
                      'SET GLOBAL general_log = ON;', 'SET PERSIST max_connections = 5;',
                      "SELECT * INTO OUTFILE '/tmp/export';",
                      "SELECT * INTO DUMPFILE '/tmp/export';",
                      "LOAD DATA INFILE '/tmp/input' INTO TABLE users;",
                      "CREATE TABLE `production`.`users` (`id` int);",
                      "CREATE TABLE IF NOT EXISTS `production`.`users` (`id` int);",
                      "DROP TABLE IF EXISTS `production`.`users`;",
                      "INSERT INTO `production`.`users` VALUES (1);",
                      "UPDATE `production`.`users` SET `id`=2;",
                      "SELECT * FROM `production`.`users`;",
                      "SOURCE /tmp/extra.sql;", "SYSTEM id;",
                      "CALL dangerous_procedure();", "DO SLEEP(1);",
                      "CREATE EVENT ev ON SCHEDULE EVERY 1 SECOND DO SELECT 1;",
                      'INSTALL PLUGIN x SONAME \'x.so\';', 'UNINSTALL PLUGIN x;']
        for statement in statements:
            with self.subTest(statement=statement), self.assertRaises(ValueError):
                self.inspect_text(statement)

    def test_forbidden_words_in_comments_strings_and_identifiers_are_ignored(self):
        dump = "-- USE production;\nINSERT INTO `drop_database` VALUES ('DROP DATABASE');"
        self.assertEqual(self.inspect_text(dump)['statements'], 1)

    def test_mysql_executable_comments_are_scanned_but_regular_comments_are_not(self):
        self.assertEqual(self.inspect_text('/* DROP DATABASE safe_comment; */ '
                                           'CREATE TABLE t (id int);')['statements'], 1)
        with self.assertRaises(ValueError):
            self.inspect_text('/*!50000 DROP DATABASE production */;')

    def test_truncated_gzip_and_expansion_limit_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'database.sql.gz'
            compressed = gzip.compress(b'CREATE TABLE t (id int);')
            path.write_bytes(compressed[:-4])
            with self.assertRaises(ValueError):
                inspect_sql_dump(path)
            path.write_bytes(compressed)
            with self.assertRaises(ValueError):
                inspect_sql_dump(path, max_expanded_bytes=4)

    def test_sql_line_and_statement_memory_limits_are_enforced(self):
        with self.assertRaises(ValueError):
            self.inspect_text('INSERT INTO t VALUES (' + 'x' * 128 + ');', max_line_bytes=64)
        with self.assertRaises(ValueError):
            self.inspect_text('INSERT INTO t VALUES (' + 'x' * 128 + ');',
                              max_line_bytes=512, max_statement_bytes=64)

    def test_unterminated_literal_or_comment_is_rejected(self):
        for dump in ["INSERT INTO t VALUES ('unfinished);", '/* unfinished']:
            with self.subTest(dump=dump), self.assertRaises(ValueError):
                self.inspect_text(dump)

    def test_database_cli_outputs_only_counts_and_refuses_unsafe_dump(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'database.sql.gz'
            command = [sys.executable, '-B', str(Path(__file__).with_name('restore_archive_safety.py')),
                       '--kind', 'database', str(path)]
            path.write_bytes(gzip.compress(b'CREATE TABLE `private_name` (`id` int);'))
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn('private_name', result.stdout)
            path.write_bytes(gzip.compress(b'USE `production`;'))
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, '')
            self.assertNotIn('production', result.stderr)

    def test_mysql_client_meta_commands_are_rejected(self):
        for dump in ['\\P cat > /tmp/out\nSELECT 1;',
                     'SELECT 1;\n\\P cat > /tmp/out\n']:
            with self.subTest(dump=dump), self.assertRaises(ValueError):
                self.inspect_text(dump)


if __name__ == '__main__':
    unittest.main(verbosity=2)
