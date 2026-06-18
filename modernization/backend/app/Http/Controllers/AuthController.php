<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Support\AuditLogger;
use App\Support\Role;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    public function captcha()
    {
        $left = random_int(1, 9);
        $right = random_int(1, 9);
        $id = (string) Str::uuid();

        Cache::put($this->captchaCacheKey($id), $left + $right, now()->addMinutes(5));

        return response()->json([
            'captcha_id' => $id,
            'question' => "{$left} + {$right} = ?",
        ]);
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'username' => ['required', 'string', 'max:100'],
            'password' => ['required', 'string', 'max:200'],
            'captcha_id' => ['required', 'string', 'max:100'],
            'captcha_answer' => ['required', 'integer'],
        ]);

        if (! $this->captchaIsValid($data['captcha_id'], (int) $data['captcha_answer'])) {
            $this->auditLogger->record($request, 'auth.captcha_failed', null, [
                'username' => $data['username'],
                'reason' => 'invalid_captcha',
            ]);

            return response()->json(['message' => '验证码错误'], 422);
        }

        $user = User::query()
            ->with('unit')
            ->where('username', $data['username'])
            ->first();

        if (! $user) {
            $this->recordFailedLogin($request, $data['username'], 'unknown_account');

            return response()->json(['message' => '账号或密码错误'], 422);
        }

        if (! $user->is_active) {
            $this->recordFailedLogin($request, $data['username'], 'inactive_account', $user);

            return response()->json(['message' => '账号或密码错误'], 422);
        }

        if (! Hash::check($data['password'], $user->password)) {
            $this->recordFailedLogin($request, $data['username'], 'invalid_password', $user);

            return response()->json(['message' => '账号或密码错误'], 422);
        }

        $user->forceFill([
            'last_login_at' => now(),
            'last_login_ip' => $request->ip(),
        ])->save();
        $this->auditLogger->record($request, 'auth.login', $user, [
            'username' => $user->username,
            'role' => $user->role,
        ]);

        return response()->json([
            'token' => $user->createToken('web')->plainTextToken,
            'user' => $this->userPayload($user),
        ]);
    }

    public function me(Request $request)
    {
        return response()->json($this->userPayload($request->user()->load('unit')));
    }

    public function updatePassword(Request $request)
    {
        $data = $request->validate([
            'current_password' => ['required', 'string', 'max:200'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'max:200'],
        ]);

        if (! Hash::check($data['current_password'], $request->user()->password)) {
            return response()->json(['message' => '当前密码错误'], 422);
        }

        $request->user()->update(['password' => $data['password']]);
        $this->auditLogger->record($request, 'auth.password_updated', $request->user());
        $request->user()->tokens()->delete();

        return response()->noContent();
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'email' => ['nullable', 'email', 'max:120', Rule::unique('users', 'email')->ignore($user->id)],
            'mobile' => ['nullable', 'string', 'max:40'],
        ]);

        $user->update($data);
        $this->auditLogger->record($request, 'auth.profile_updated', $user, [
            'email' => $user->email,
            'mobile' => $user->mobile,
        ]);

        return response()->json($this->userPayload($user->refresh()->load('unit')));
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->noContent();
    }

    private function userPayload(User $user): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'username' => $user->username,
            'email' => $user->email,
            'mobile' => $user->mobile,
            'role' => $user->role,
            'unit_id' => $user->unit_id,
            'is_active' => $user->is_active,
            'last_login_at' => $user->last_login_at,
            'last_login_ip' => $user->last_login_ip,
            'unit' => $user->unit,
            ...Role::profile($user->role),
        ];
    }

    private function recordFailedLogin(Request $request, string $username, string $reason, ?User $user = null): void
    {
        $this->auditLogger->record($request, 'auth.login_failed', $user, [
            'username' => $username,
            'reason' => $reason,
            'role' => $user?->role,
        ]);
    }

    private function captchaIsValid(string $id, int $answer): bool
    {
        $key = $this->captchaCacheKey($id);
        $expected = Cache::pull($key);

        return $expected !== null && (int) $expected === $answer;
    }

    private function captchaCacheKey(string $id): string
    {
        return 'auth:captcha:'.$id;
    }
}
