<?php

namespace App\Support;

final class IpRange
{
    public static function isValid(string $value): bool
    {
        $parts = explode('/', $value);
        if (count($parts) > 2 || filter_var($parts[0], FILTER_VALIDATE_IP) === false) {
            return false;
        }

        if (count($parts) === 1) {
            return true;
        }

        $maxBits = str_contains($parts[0], ':') ? 128 : 32;

        return ctype_digit($parts[1]) && strlen($parts[1]) <= 3 && (int) $parts[1] <= $maxBits;
    }
}
