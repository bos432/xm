<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Support\Role;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;

class HealthCheckLogin extends Command
{
    protected $signature = 'health:login-check';

    protected $description = 'Validate that the configured health-check account can authenticate.';

    public function handle(): int
    {
        $username = (string) config('modernization.health_check_username');
        $password = (string) config('modernization.health_check_password');

        if ($username === '' || $password === '') {
            $this->error('Health login failed: credentials are not configured.');

            return self::FAILURE;
        }

        $user = User::query()
            ->with('unit')
            ->where('username', $username)
            ->first();

        if (! $user) {
            $this->error("Health login failed: account [{$username}] does not exist.");

            return self::FAILURE;
        }

        if ($user->role !== Role::UNIT || ! ($user->metadata['health_check'] ?? false)) {
            $this->error("Health login failed: account [{$username}] is not a dedicated health-check account.");

            return self::FAILURE;
        }

        if (! $user->is_active) {
            $this->error("Health login failed: account [{$username}] is inactive.");

            return self::FAILURE;
        }

        if ($user->unit && $user->unit->status !== 'active') {
            $this->error("Health login failed: unit for [{$username}] is not active.");

            return self::FAILURE;
        }

        if (! Hash::check($password, $user->password)) {
            $this->error("Health login failed: password mismatch for [{$username}].");

            return self::FAILURE;
        }

        $appUrl = rtrim((string) config('app.url'), '/');
        $url = parse_url($appUrl);
        if (! is_array($url)
            || ($url['scheme'] ?? null) !== 'https'
            || strtolower((string) ($url['host'] ?? '')) !== 'nxm.zlck888.com'
            || isset($url['user'])
            || isset($url['pass'])
            || (isset($url['port']) && (int) $url['port'] !== 443)) {
            $this->error('Health login failed: APP_URL must use the production HTTPS host.');

            return self::FAILURE;
        }

        try {
            $captcha = Http::acceptJson()->timeout(15)->get($appUrl.'/api/auth/captcha')->throw()->json();
            if (! is_array($captcha) || empty($captcha['captcha_id']) || empty($captcha['question'])) {
                throw new \RuntimeException('Invalid captcha response.');
            }

            if (! preg_match('/^\s*(\d{1,3})\s*\+\s*(\d{1,3})\s*=\s*\?\s*$/', (string) $captcha['question'], $matches)) {
                throw new \RuntimeException('Unsupported captcha question.');
            }
            $answer = (int) $matches[1] + (int) $matches[2];
            $login = Http::acceptJson()->asJson()->timeout(15)->post($appUrl.'/api/auth/login', [
                'username' => $username,
                'password' => $password,
                'captcha_id' => $captcha['captcha_id'],
                'captcha_answer' => $answer,
            ])->throw()->json();

            if (! is_array($login) || empty($login['token'])) {
                throw new \RuntimeException('Login response did not contain a token.');
            }

            $logout = Http::acceptJson()->withToken($login['token'])->timeout(15)
                ->post($appUrl.'/api/auth/logout')->throw();
            if (! $logout->successful()) {
                throw new \RuntimeException('Logout failed.');
            }
        } catch (\Throwable $exception) {
            $this->error('Health HTTP login failed; check the application URL and authentication endpoints.');

            return self::FAILURE;
        }

        $this->info("Health HTTP login passed for [{$username}]; token revoked via logout.");

        return self::SUCCESS;
    }
}
