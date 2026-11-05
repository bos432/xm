"""Read-only, bounded validator for the site's private-file tar.gz backups."""

import argparse
import gzip
import json
from pathlib import Path
import re
import tarfile
import gzip


def _safe_name(name):
    if not name or len(name) > 4096 or "\x00" in name or "\\" in name:
        raise ValueError("unsafe archive member path")
    if name.startswith("/") or re.match(r"^[A-Za-z]:", name):
        raise ValueError("absolute archive member path")
    parts = [part for part in name.split("/") if part not in ("", ".")]
    if len(parts) > 64:
        raise ValueError("archive path exceeds depth limit")
    if not parts or any(part == ".." for part in parts):
        if name in (".", "./"):
            return ""
        raise ValueError("traversal or empty archive member path")
    return "/".join(parts)


def inspect_archive(path, *, max_archive_bytes=32 * 1024 * 1024,
                    max_members=10_000, max_file_bytes=64 * 1024 * 1024,
                    max_expanded_bytes=256 * 1024 * 1024):
    if any(value < 0 for value in (max_archive_bytes, max_members, max_file_bytes,
                                  max_expanded_bytes)):
        raise ValueError("archive resource limits must be nonnegative")
    path = Path(path)
    compressed_size = path.stat().st_size
    if compressed_size < 1 or compressed_size > max_archive_bytes:
        raise ValueError("archive size outside allowed bounds")

    seen = set()
    files = set()
    required_directories = set()
    count = file_count = dir_count = expanded = 0
    try:
        # Tar readers may stop before the gzip footer; drain separately to check CRC
        # and bound all expanded bytes, including padding and extended headers.
        with gzip.open(path, 'rb') as compressed:
            consumed = 0
            while True:
                chunk = compressed.read(min(1024 * 1024, max_expanded_bytes - consumed + 1))
                if not chunk:
                    break
                consumed += len(chunk)
                if consumed > max_expanded_bytes:
                    raise ValueError("expanded archive size exceeds limit")
        with tarfile.open(path, mode="r:gz") as archive:
            for member in archive:
                count += 1
                if count > max_members:
                    raise ValueError("archive member count exceeds limit")
                name = _safe_name(member.name)
                if name == "":
                    if not member.isdir():
                        raise ValueError("archive root entry must be a directory")
                    if name in seen:
                        raise ValueError("duplicate normalized archive path")
                    seen.add(name)
                    dir_count += 1
                    continue
                if name in seen:
                    raise ValueError("duplicate normalized archive path")
                seen.add(name)
                if not (member.isdir() or member.isreg()) or member.sparse is not None:
                    raise ValueError("links and special archive entries are forbidden")
                ancestors = name.split("/")[:-1]
                if any("/".join(ancestors[:index]) in files
                       for index in range(1, len(ancestors) + 1)):
                    raise ValueError("archive file used as a parent directory")
                required_directories.update("/".join(ancestors[:index])
                                            for index in range(1, len(ancestors) + 1))
                if member.isdir():
                    dir_count += 1
                    continue
                if name in required_directories:
                    raise ValueError("archive file used as a parent directory")
                if member.size < 0 or member.size > max_file_bytes:
                    raise ValueError("archive file size outside allowed bounds")
                expanded += member.size
                if expanded > max_expanded_bytes:
                    raise ValueError("expanded archive size exceeds limit")
                stream = archive.extractfile(member)
                if stream is None:
                    raise ValueError("archive file body is missing")
                remaining = member.size
                while remaining:
                    chunk = stream.read(min(1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError("truncated archive file body")
                    remaining -= len(chunk)
                if stream.read(1):
                    raise ValueError("archive file body exceeds declared size")
                files.add(name)
                file_count += 1
        if count == 0:
            raise ValueError("empty archive")
    except (tarfile.TarError, OSError, EOFError) as error:
        raise ValueError("invalid or truncated gzip/tar archive") from error

    return {"members": count, "files": file_count, "directories": dir_count,
            "file_bytes": expanded}


_TOKEN = re.compile(r"`((?:``|[^`])*)`|([A-Za-z_][A-Za-z0-9_$]*)|(\*)|([.])")


def _bounded_lines(stream, *, max_bytes, max_line_bytes):
    pending = bytearray()
    total = 0
    while True:
        chunk = stream.read(64 * 1024)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise ValueError("expanded SQL dump exceeds limit")
        start = 0
        while True:
            end = chunk.find(b'\n', start)
            piece = chunk[start:] if end < 0 else chunk[start:end + 1]
            if len(pending) + len(piece) > max_line_bytes:
                raise ValueError("SQL line exceeds limit")
            pending.extend(piece)
            if end < 0:
                break
            yield pending.decode('utf-8', errors='strict')
            pending.clear()
            start = end + 1
    if pending:
        yield pending.decode('utf-8', errors='strict')


def _check_sql_statement(statement):
    tokens = []
    for match in _TOKEN.finditer(statement):
        quoted, word, star, dot = match.groups()
        tokens.append((quoted.replace('``', '`') if quoted is not None else
                       word.upper() if word else '*' if star else '.'))
    if not tokens:
        return False
    first = tokens[0]
    second = tokens[1] if len(tokens) > 1 else ''
    third = tokens[2] if len(tokens) > 2 else ''
    if first in {'USE', 'GRANT', 'REVOKE', 'SHUTDOWN', 'SOURCE', 'SYSTEM', 'CALL',
                 'DO', 'PREPARE', 'EXECUTE'}:
        raise ValueError("database selection or privileged SQL statement is forbidden")
    if first in {'CREATE', 'ALTER', 'DROP'} and second in {'DATABASE', 'SCHEMA', 'USER', 'ROLE'}:
        raise ValueError("database or account DDL is forbidden")
    if first in {'CREATE', 'ALTER', 'DROP'} and second == 'EVENT':
        raise ValueError("scheduled event DDL is forbidden")
    if first == 'SET' and second in {'GLOBAL', 'PERSIST', 'PERSIST_ONLY'}:
        raise ValueError("global server setting is forbidden")
    if first in {'INSTALL', 'UNINSTALL'} and second in {'PLUGIN', 'COMPONENT'}:
        raise ValueError("server plugin DDL is forbidden")
    if first == 'LOAD' and second in {'DATA', 'XML'}:
        raise ValueError("server-side data loading is forbidden")
    if 'INTO' in tokens:
        into = tokens.index('INTO')
        if tokens[into + 1:into + 2] in (['OUTFILE'], ['DUMPFILE']):
            raise ValueError("filesystem export is forbidden")
    # Single-database dumps do not need schema-qualified object references.
    for index, token in enumerate(tokens[:-1]):
        if token in {'TABLE', 'VIEW', 'TRIGGER', 'EVENT', 'PROCEDURE', 'FUNCTION'}:
            target = index + 1
            if tokens[target:target + 2] == ['IF', 'EXISTS']:
                target += 2
            elif tokens[target:target + 3] == ['IF', 'NOT', 'EXISTS']:
                target += 3
        elif token in {'FROM', 'JOIN', 'UPDATE', 'INTO'}:
            target = index + 1
            if token == 'INTO' and tokens[target:target + 1] in (['OUTFILE'], ['DUMPFILE']):
                continue
        elif first == 'RENAME' and token == 'TO':
            target = index + 1
        else:
            continue
        if target + 1 < len(tokens) and tokens[target + 1] == '.':
            raise ValueError("schema-qualified object reference is forbidden")
    return True


def inspect_sql_dump(path, *, max_archive_bytes=32 * 1024 * 1024,
                     max_expanded_bytes=256 * 1024 * 1024,
                     max_statement_bytes=256 * 1024,
                     max_line_bytes=1024 * 1024):
    path = Path(path)
    compressed_size = path.stat().st_size
    if min(max_archive_bytes, max_expanded_bytes, max_statement_bytes, max_line_bytes) < 1:
        raise ValueError("SQL dump limits must be positive")
    if compressed_size < 1 or compressed_size > max_archive_bytes:
        raise ValueError("SQL archive size outside allowed bounds")

    total = statements = 0
    delimiter = ';'
    statement = []
    quote = None
    block_comment = False
    executable_comment = False
    line_comment = False
    escaped = False
    try:
        with gzip.open(path, 'rb') as source:
            for line in _bounded_lines(source, max_bytes=max_expanded_bytes,
                                       max_line_bytes=max_line_bytes):
                total += len(line.encode('utf-8'))
                if not ''.join(statement).strip() and quote is None and not block_comment:
                    statement.clear()
                    directive = re.match(r'^\s*DELIMITER\s+(\S+)\s*$', line, re.IGNORECASE)
                    if directive:
                        delimiter = directive.group(1)
                        if len(delimiter) > 16:
                            raise ValueError("SQL delimiter exceeds limit")
                        continue
                    if re.match(r'^\s*\\', line):
                        raise ValueError("mysql client command is forbidden")
                index = 0
                while index < len(line):
                    char = line[index]
                    following = line[index + 1] if index + 1 < len(line) else ''
                    if line_comment:
                        if char in '\r\n':
                            line_comment = False
                        index += 1
                        continue
                    if block_comment:
                        if char == '*' and following == '/':
                            block_comment = False
                            executable_comment = False
                            index += 2
                        elif executable_comment:
                            statement.append(char)
                            index += 1
                        else:
                            index += 1
                        continue
                    if quote:
                        if escaped:
                            escaped = False
                        elif char == '\\' and quote != '`':
                            escaped = True
                        elif char == quote:
                            if following == quote:
                                index += 2
                                continue
                            quote = None
                            statement.append(' ' if char != '`' else '`')
                        elif quote == '`':
                            statement.append(char)
                        index += 1
                        continue
                    if char in "'\"`":
                        quote = char
                        statement.append(' ' if char != '`' else '`')
                        index += 1
                        continue
                    if char == '#' or (char == '-' and following == '-' and
                                       (index + 2 == len(line) or line[index + 2].isspace())):
                        line_comment = True
                        index += 1 if char == '#' else 2
                        continue
                    if char == '/' and following == '*':
                        block_comment = True
                        executable_comment = line[index + 2:index + 3] == '!'
                        index += 3 if executable_comment else 2
                        if executable_comment:
                            while index < len(line) and (line[index].isdigit() or line[index].isspace()):
                                index += 1
                        continue
                    if line.startswith(delimiter, index):
                        if _check_sql_statement(''.join(statement)):
                            statements += 1
                        statement.clear()
                        index += len(delimiter)
                        continue
                    statement.append(char)
                    if len(statement) > max_statement_bytes:
                        raise ValueError("SQL statement exceeds limit")
                    index += 1
        if quote or block_comment or escaped:
            raise ValueError("unterminated SQL string, identifier or comment")
        if _check_sql_statement(''.join(statement)):
            statements += 1
    except (OSError, EOFError, UnicodeError) as error:
        raise ValueError("invalid or truncated SQL gzip archive") from error
    if statements == 0:
        raise ValueError("SQL dump contains no statements")
    return {"statements": statements, "expanded_bytes": total}


def main():
    parser = argparse.ArgumentParser(description="Read-only bounded tar.gz safety inspection")
    parser.add_argument("archive", type=Path)
    parser.add_argument("--kind", choices=['private-files', 'database'], default='private-files')
    parser.add_argument("--max-archive-bytes", type=int, default=32 * 1024 * 1024)
    parser.add_argument("--max-members", type=int, default=10_000)
    parser.add_argument("--max-file-bytes", type=int, default=64 * 1024 * 1024)
    parser.add_argument("--max-expanded-bytes", type=int, default=256 * 1024 * 1024)
    args = parser.parse_args()
    try:
        if args.kind == 'database':
            report = inspect_sql_dump(args.archive, max_archive_bytes=args.max_archive_bytes,
                                      max_expanded_bytes=args.max_expanded_bytes)
        else:
            report = inspect_archive(args.archive, max_archive_bytes=args.max_archive_bytes,
                                     max_members=args.max_members,
                                     max_file_bytes=args.max_file_bytes,
                                     max_expanded_bytes=args.max_expanded_bytes)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
