<?php

namespace App\Support;

use App\Models\SystemSetting;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Schema;

final class RuntimeConfig
{
    public static function value(string $key, ?string $default = null): ?string
    {
        if (! Schema::hasTable('system_settings')) {
            return $default;
        }

        $setting = SystemSetting::query()->where('key', $key)->first();
        if (! $setting || $setting->value === null || $setting->value === '') {
            return $default;
        }

        if (! $setting->is_secret) {
            return $setting->value;
        }

        return self::decrypt($setting->value) ?? $setting->value;
    }

    public static function intValue(string $key, int $default): int
    {
        $value = self::value($key);

        return is_numeric($value) ? (int) $value : $default;
    }

    public static function boolValue(string $key, bool $default = false): bool
    {
        $value = self::value($key);
        if ($value === null) {
            return $default;
        }

        return in_array(strtolower((string) $value), ['1', 'true', 'yes', 'on'], true);
    }

    public static function set(string $key, ?string $value, string $group, bool $secret, string $description = ''): SystemSetting
    {
        return SystemSetting::updateOrCreate(
            ['key' => $key],
            [
                'value' => $secret && filled($value) ? Crypt::encryptString((string) $value) : $value,
                'group' => $group,
                'is_secret' => $secret,
                'description' => $description,
            ]
        );
    }

    public static function mask(?string $value): string
    {
        $value = (string) $value;
        if ($value === '') {
            return '';
        }

        if (strlen($value) <= 4) {
            return '****';
        }

        return substr($value, 0, 2).'****'.substr($value, -2);
    }

    public static function maskedSettingValue(SystemSetting $setting): string
    {
        if (! $setting->is_secret) {
            return (string) $setting->value;
        }

        $plain = self::decrypt((string) $setting->value);

        return self::mask($plain ?? $setting->value);
    }

    public static function applyMailSettings(): void
    {
        $mailer = self::value('mail.mailer', config('mail.default', 'log')) ?: 'log';
        $host = self::value('mail.host', config('mail.mailers.smtp.host'));
        $port = self::value('mail.port', (string) config('mail.mailers.smtp.port'));
        $encryption = self::value('mail.encryption', config('mail.mailers.smtp.encryption'));
        $username = self::value('mail.username', config('mail.mailers.smtp.username'));
        $password = self::value('mail.password', config('mail.mailers.smtp.password'));
        $fromAddress = self::value('mail.from_address', config('mail.from.address'));
        $fromName = self::value('mail.from_name', config('mail.from.name'));

        config([
            'mail.default' => $mailer,
            'mail.mailers.smtp.host' => $host,
            'mail.mailers.smtp.port' => is_numeric($port) ? (int) $port : $port,
            'mail.mailers.smtp.encryption' => $encryption ?: null,
            'mail.mailers.smtp.username' => $username ?: null,
            'mail.mailers.smtp.password' => $password ?: null,
            'mail.from.address' => $fromAddress ?: config('mail.from.address'),
            'mail.from.name' => $fromName ?: config('mail.from.name'),
        ]);
    }

    private static function decrypt(string $value): ?string
    {
        if ($value === '') {
            return '';
        }

        try {
            return Crypt::decryptString($value);
        } catch (\Throwable) {
            return null;
        }
    }
}
