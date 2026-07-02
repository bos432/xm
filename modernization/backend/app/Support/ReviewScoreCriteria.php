<?php

namespace App\Support;

use App\Models\DictionaryItem;
use Illuminate\Validation\ValidationException;

final class ReviewScoreCriteria
{
    public const GROUP = 'expert_review_criterion';

    public static function active(): array
    {
        return DictionaryItem::query()
            ->where('group', self::GROUP)
            ->where('is_active', true)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn (DictionaryItem $item): array => self::normalize($item))
            ->filter(fn (array $item): bool => $item['max_score'] > 0)
            ->values()
            ->all();
    }

    public static function applyExpertScores(array $data): array
    {
        $criteria = self::active();
        if ($criteria === []) {
            return $data;
        }

        $submittedScores = self::submittedScoreMap(data_get($data, 'metadata.score_criteria', []));
        $requiresScores = ! in_array($data['decision'] ?? null, ['return', 'reject'], true);
        if (! $requiresScores && ! self::hasAnySubmittedScore($submittedScores)) {
            return $data;
        }

        $errors = [];
        $items = [];
        $total = 0.0;
        $maxTotal = 0.0;

        foreach ($criteria as $criterion) {
            $code = $criterion['code'];
            $maxScore = (float) $criterion['max_score'];
            $maxTotal += $maxScore;
            $rawScore = $submittedScores[$code] ?? null;

            if ($rawScore === null || $rawScore === '') {
                $errors[] = '请填写评分项：'.$criterion['label'];
                continue;
            }

            if (! is_numeric($rawScore)) {
                $errors[] = '评分项“'.$criterion['label'].'”必须是数字';
                continue;
            }

            $score = round((float) $rawScore, 2);
            if ($score < 0 || $score > $maxScore) {
                $errors[] = '评分项“'.$criterion['label'].'”必须在 0-'.$maxScore.' 分之间';
                continue;
            }

            $total += $score;
            $items[] = $criterion + ['score' => $score];
        }

        if ($errors !== []) {
            throw ValidationException::withMessages([
                'metadata.score_criteria' => implode('；', $errors),
            ]);
        }

        $metadata = $data['metadata'] ?? [];
        if (! is_array($metadata)) {
            $metadata = [];
        }

        $metadata['score_criteria'] = $items;
        $metadata['score_total'] = round($total, 2);
        $metadata['score_max'] = round($maxTotal, 2);
        $metadata['score_source'] = self::GROUP;

        $data['metadata'] = $metadata;
        $data['score'] = round($total, 2);

        return $data;
    }

    public static function scoreMapFromReviewMetadata(?array $metadata): array
    {
        $items = $metadata['score_criteria'] ?? [];
        if (! is_array($items)) {
            return [];
        }

        return collect($items)
            ->filter(fn ($item): bool => is_array($item) && isset($item['code']))
            ->mapWithKeys(fn (array $item): array => [(string) $item['code'] => $item['score'] ?? null])
            ->all();
    }

    private static function normalize(DictionaryItem $item): array
    {
        $metadata = is_array($item->metadata) ? $item->metadata : [];

        return [
            'code' => (string) $item->code,
            'label' => (string) $item->label,
            'section' => (string) ($metadata['section'] ?? '专家评分'),
            'description' => (string) ($metadata['description'] ?? ''),
            'max_score' => round((float) ($metadata['max_score'] ?? 0), 2),
            'sort_order' => (int) $item->sort_order,
        ];
    }

    private static function submittedScoreMap(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        if (array_is_list($value)) {
            $map = [];
            foreach ($value as $item) {
                if (is_array($item) && isset($item['code'])) {
                    $map[(string) $item['code']] = $item['score'] ?? null;
                }
            }

            return $map;
        }

        return $value;
    }

    private static function hasAnySubmittedScore(array $scores): bool
    {
        foreach ($scores as $score) {
            if ($score !== null && $score !== '') {
                return true;
            }
        }

        return false;
    }
}
