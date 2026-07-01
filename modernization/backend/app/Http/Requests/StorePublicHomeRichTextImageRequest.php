<?php

namespace App\Http\Requests;

use App\Support\RuntimeConfig;
use Closure;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Validation\Rules\File;

class StorePublicHomeRichTextImageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $extensions = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
        $blockedExtensions = $this->extensionList(RuntimeConfig::value('upload.blocked_extensions', config('modernization.upload_blocked_extensions')));

        return [
            'file' => [
                'required',
                File::image()->max(2048),
                $this->safeOriginalNameRule($extensions, $blockedExtensions),
            ],
        ];
    }

    private function extensionList(string $value): array
    {
        return array_values(array_filter(array_map(
            fn (string $extension) => strtolower(trim($extension, " \t\n\r\0\x0B.")),
            explode(',', $value)
        )));
    }

    private function safeOriginalNameRule(array $allowedExtensions, array $blockedExtensions): Closure
    {
        return function (string $attribute, UploadedFile $file, Closure $fail) use ($allowedExtensions, $blockedExtensions): void {
            $originalName = $file->getClientOriginalName();
            $extension = strtolower($file->getClientOriginalExtension());
            $nameParts = array_values(array_filter(array_map('strtolower', explode('.', $originalName))));

            if ($extension === '' || ! in_array($extension, $allowedExtensions, true)) {
                $fail('富文本图片扩展名不在允许范围内。');

                return;
            }

            if (in_array($extension, $blockedExtensions, true) || array_intersect($nameParts, $blockedExtensions) !== []) {
                $fail('富文本图片类型存在安全风险，已拒绝上传。');

                return;
            }

            if (str_contains($originalName, '/') || str_contains($originalName, '\\') || str_contains($originalName, '..')) {
                $fail('富文本图片文件名不能包含路径字符。');
            }
        };
    }
}
