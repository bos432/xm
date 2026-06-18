<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

abstract class TestCase extends BaseTestCase
{
    protected function validCaptchaPayload(int $answer = 12): array
    {
        $id = (string) Str::uuid();
        Cache::put('auth:captcha:'.$id, $answer, now()->addMinutes(5));

        return [
            'captcha_id' => $id,
            'captcha_answer' => $answer,
        ];
    }
}
