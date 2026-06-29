<?php

namespace App\Http\Controllers;

use App\Models\Unit;
use App\Models\User;
use App\Support\AuditLogger;
use App\Support\MailCenter;
use App\Support\Role;
use App\Support\SecurityService;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AuthController extends Controller
{
    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly MailCenter $mailCenter,
        private readonly SecurityService $securityService,
    )
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

        $this->securityService->assertLoginAllowed($request, $data['username']);

        if (! $this->captchaIsValid($data['captcha_id'], (int) $data['captcha_answer'])) {
            $this->auditLogger->record($request, 'auth.captcha_failed', null, [
                'username' => $data['username'],
                'reason' => 'invalid_captcha',
            ]);
            $this->securityService->recordFailure($request, $data['username'], 'invalid_captcha');

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
        $this->securityService->recordSuccess($request, $user);

        return response()->json([
            'token' => $user->createToken('web')->plainTextToken,
            'user' => $this->userPayload($user),
        ]);
    }

    public function registerUnit(Request $request)
    {
        $data = $request->validate([
            'unit_name' => ['required', 'string', 'max:200'],
            'credit_code' => ['required', 'string', 'max:80', 'unique:units,credit_code'],
            'contact_name' => ['required', 'string', 'max:100'],
            'contact_mobile' => ['required', 'string', 'max:40'],
            'email' => ['required', 'email', 'max:120', 'unique:users,email'],
            'address' => ['nullable', 'string', 'max:500'],
            'region_code' => ['nullable', 'string', 'max:50'],
            'username' => ['required', 'string', 'max:100', 'unique:users,username'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'max:200'],
            'captcha_id' => ['required', 'string', 'max:100'],
            'captcha_answer' => ['required', 'integer'],
        ]);

        if (! $this->captchaIsValid($data['captcha_id'], (int) $data['captcha_answer'])) {
            $this->auditLogger->record($request, 'auth.registration_captcha_failed', null, [
                'username' => $data['username'],
                'reason' => 'invalid_captcha',
            ]);

            return response()->json(['message' => '验证码错误'], 422);
        }

        [$unit, $user] = DB::transaction(function () use ($data) {
            $unit = Unit::create([
                'name' => $data['unit_name'],
                'credit_code' => $data['credit_code'],
                'contact_name' => $data['contact_name'],
                'contact_mobile' => $data['contact_mobile'],
                'email' => $data['email'],
                'address' => $data['address'] ?? null,
                'region_code' => $data['region_code'] ?? null,
                'status' => 'suspended',
                'metadata' => [
                    'registration_status' => 'pending',
                    'registered_at' => now()->toDateTimeString(),
                ],
            ]);

            $user = User::create([
                'unit_id' => $unit->id,
                'name' => $data['contact_name'],
                'username' => $data['username'],
                'email' => $data['email'],
                'mobile' => $data['contact_mobile'],
                'password' => $data['password'],
                'role' => Role::UNIT,
                'is_active' => false,
            ]);

            return [$unit, $user];
        });

        $this->auditLogger->record($request, 'auth.unit_registered', $user, [
            'unit_id' => $unit->id,
            'username' => $user->username,
            'registration_status' => 'pending',
        ]);
        $this->mailCenter->queueTemplate('registration_pending', $user->email, [
            'unit_name' => $unit->name,
            'username' => $user->username,
        ], $user, $user->name);

        return response()->json([
            'message' => '注册申请已提交，请等待管理员审核启用。',
            'unit' => $unit,
            'user' => $user->load('unit'),
        ], 201);
    }

    public function forgotPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:120'],
            'captcha_id' => ['required', 'string', 'max:100'],
            'captcha_answer' => ['required', 'integer'],
        ]);

        if (! $this->captchaIsValid($data['captcha_id'], (int) $data['captcha_answer'])) {
            $this->auditLogger->record($request, 'auth.password_reset_captcha_failed', null, [
                'email' => $data['email'],
                'reason' => 'invalid_captcha',
            ]);

            return response()->json(['message' => '验证码错误'], 422);
        }

        $user = User::query()->where('email', $data['email'])->first();

        if ($user) {
            $token = Str::random(64);
            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $data['email']],
                [
                    'token' => hash('sha256', $token),
                    'created_at' => now(),
                ]
            );

            $link = url('/reset-password?'.http_build_query([
                'email' => $data['email'],
                'token' => $token,
            ]));

            $this->mailCenter->queueTemplate('password_reset', $data['email'], [
                'reset_link' => $link,
                'expire_minutes' => (string) config('auth.passwords.users.expire', 60),
            ], $user, $user->name);

            $this->auditLogger->record($request, 'auth.password_reset_requested', $user, [
                'email' => $data['email'],
            ]);
        }

        return response()->json([
            'message' => '如果邮箱已绑定账号，系统将发送密码重置邮件。',
        ]);
    }

    public function resetPassword(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:120'],
            'token' => ['required', 'string', 'max:200'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'max:200'],
        ]);

        $row = DB::table('password_reset_tokens')->where('email', $data['email'])->first();
        $expiresAt = now()->subMinutes((int) config('auth.passwords.users.expire', 60));

        if (
            ! $row
            || ! hash_equals((string) $row->token, hash('sha256', $data['token']))
            || ! $row->created_at
            || Carbon::parse($row->created_at)->lt($expiresAt)
        ) {
            return response()->json(['message' => '密码重置链接无效或已过期'], 422);
        }

        $user = User::query()->where('email', $data['email'])->first();
        if (! $user) {
            DB::table('password_reset_tokens')->where('email', $data['email'])->delete();

            return response()->json(['message' => '密码重置链接无效或已过期'], 422);
        }

        $user->update(['password' => $data['password']]);
        $user->tokens()->delete();
        DB::table('password_reset_tokens')->where('email', $data['email'])->delete();
        $this->auditLogger->record($request, 'auth.password_reset_completed', $user, [
            'email' => $data['email'],
        ]);

        return response()->json(['message' => '密码已重置，请重新登录。']);
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
            ...Role::profile($user),
        ];
    }

    private function recordFailedLogin(Request $request, string $username, string $reason, ?User $user = null): void
    {
        $this->auditLogger->record($request, 'auth.login_failed', $user, [
            'username' => $username,
            'reason' => $reason,
            'role' => $user?->role,
        ]);
        $this->securityService->recordFailure($request, $username, $reason, $user);
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
