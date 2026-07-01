<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class HealthCheckLogin extends Command
{
    protected $signature = 'health:login-check {--username=} {--password=}';

    protected $description = 'Validate that the configured health-check account can authenticate.';

    public function handle(): int
    {
        $username = (string) ($this->option('username') ?: env('HEALTH_CHECK_USERNAME', 'health_check_user'));
        $password = (string) ($this->option('password') ?: env('HEALTH_CHECK_PASSWORD', ''));

        if ($username === '' || $password === '') {
            $this->warn('Health login skipped: HEALTH_CHECK_USERNAME or HEALTH_CHECK_PASSWORD is not configured.');

            return self::SUCCESS;
        }

        $user = User::query()
            ->with('unit')
            ->where('username', $username)
            ->first();

        if (! $user) {
            $this->error("Health login failed: account [{$username}] does not exist.");

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

        $token = $user->createToken('deploy-health-check');
        $token->accessToken->delete();

        $this->info("Health login passed for [{$username}].");

        return self::SUCCESS;
    }
}
