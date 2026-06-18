<?php

namespace App\Support;

final class CsvExport
{
    public static function writeRow($output, array $row): void
    {
        fputcsv($output, array_map(self::safeCell(...), $row));
    }

    private static function safeCell(mixed $value): mixed
    {
        if (! is_string($value)) {
            return $value;
        }

        if (preg_match('/^\s*[=+\-@]/u', $value) === 1) {
            return "'".$value;
        }

        return $value;
    }
}
