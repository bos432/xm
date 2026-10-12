<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Support\Role;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

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

        $token = $user->createToken('deploy-health-check');
        $token->accessToken->delete();

        $this->info("Health login passed for [{$username}].");

        return self::SUCCESS;
    }
}
