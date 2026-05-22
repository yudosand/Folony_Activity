<?php

namespace App\Services;

use App\Models\FaceProfile;
use App\Models\FaceVerificationLog;
use App\Models\User;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;

class FaceVerificationService
{
    private const MATCH_THRESHOLD = 82.0;
    private const MATCH_RETRY_THRESHOLD = 74.0;
    private const LIVENESS_THRESHOLD = 72.0;
    private const LIVENESS_RETRY_THRESHOLD = 55.0;

    public function profileFor(User $user): FaceProfile
    {
        return FaceProfile::query()->firstOrCreate(
            ['user_id' => $user->id],
            [
                'id' => (string) Str::uuid(),
                'status' => 'pending',
                'samples' => [],
                'biometric_template' => [],
                'verification_mode' => 'lightweight_signature_v2',
                'note' => 'User belum menyelesaikan enrollment wajah.',
            ],
        );
    }

    public function enroll(User $user, array $payload): FaceProfile
    {
        $profile = $this->profileFor($user);
        $samples = collect(Arr::get($payload, 'samples', []))
            ->map(fn (array $sample) => [
                'id' => $sample['id'],
                'file_name' => $sample['file_name'],
                'mime_type' => $sample['mime_type'],
                'url' => $sample['url'],
                'thumbnail_url' => $sample['thumbnail_url'] ?? null,
                'size_in_bytes' => $sample['size_in_bytes'] ?? null,
            ])
            ->values()
            ->all();
        $biometricTemplate = collect(Arr::get($payload, 'biometric_template', []))
            ->map(fn ($value) => round((float) $value, 6))
            ->values()
            ->all();

        $profile->fill([
            'status' => count($samples) >= 3 && count($biometricTemplate) >= 64
                ? 'active'
                : 'pending',
            'samples' => $samples,
            'biometric_template' => $biometricTemplate,
            'enrolled_at' => now(),
            'verification_mode' => 'lightweight_signature_v2',
            'note' => Arr::get($payload, 'note')
                ?: 'Enrollment wajah aktif dengan lightweight signature v2.',
        ])->save();

        return $profile->refresh();
    }

    public function verify(User $user, array $payload): array
    {
        $profile = $this->profileFor($user);
        $samples = $profile->samples ?? [];
        $template = collect($profile->biometric_template ?? [])
            ->map(fn ($value) => (float) $value)
            ->values()
            ->all();
        $signature = collect(Arr::get($payload, 'signature', []))
            ->map(fn ($value) => (float) $value)
            ->values()
            ->all();
        $hasEnrollment = $profile->status === 'active'
            && count($samples) >= 3
            && count($template) >= 64;
        $matchScore = $hasEnrollment
            ? $this->cosineSimilarityScore($template, $signature)
            : 0.0;
        $livenessScore = (float) Arr::get($payload, 'liveness_score', 0);

        $decision = $this->decisionForResult(
            hasEnrollment: $hasEnrollment,
            matchScore: $matchScore,
            livenessScore: $livenessScore,
        );
        $verified = $decision === 'verified';
        $note = $this->noteForResult(
            decision: $decision,
            hasEnrollment: $hasEnrollment,
            matchScore: $matchScore,
            livenessScore: $livenessScore,
        );

        $log = FaceVerificationLog::query()->create([
            'id' => (string) Str::uuid(),
            'user_id' => $user->id,
            'face_profile_id' => $profile->id,
            'action' => Arr::get($payload, 'action', 'checkIn'),
            'result' => $decision,
            'match_score' => $matchScore,
            'liveness_score' => $livenessScore,
            'capture_attachment' => Arr::get($payload, 'capture'),
            'metadata' => [
                'verification_mode' => 'lightweight_signature_v2',
                'samples_count' => count($samples),
                'match_threshold' => self::MATCH_THRESHOLD,
                'match_retry_threshold' => self::MATCH_RETRY_THRESHOLD,
                'liveness_threshold' => self::LIVENESS_THRESHOLD,
                'liveness_retry_threshold' => self::LIVENESS_RETRY_THRESHOLD,
                'should_retry' => $decision === 'retry',
            ],
            'verified_at' => now(),
            'note' => Arr::get($payload, 'note') ?: $note,
        ]);

        if ($verified) {
            $profile->forceFill([
                'last_verified_at' => $log->verified_at,
            ])->save();
        }

        return [
            'profile' => $profile->refresh(),
            'log' => $log->refresh(),
            'verified' => $verified,
            'decision' => $decision,
            'match_score' => $matchScore,
            'liveness_score' => $livenessScore,
            'note' => $note,
        ];
    }

    private function decisionForResult(
        bool $hasEnrollment,
        float $matchScore,
        float $livenessScore,
    ): string {
        if (! $hasEnrollment) {
            return 'rejected';
        }

        if ($matchScore >= self::MATCH_THRESHOLD
            && $livenessScore >= self::LIVENESS_THRESHOLD) {
            return 'verified';
        }

        if ($matchScore >= self::MATCH_RETRY_THRESHOLD
            && $livenessScore >= self::LIVENESS_RETRY_THRESHOLD) {
            return 'retry';
        }

        return 'rejected';
    }

    private function cosineSimilarityScore(array $template, array $signature): float
    {
        if (count($template) === 0 || count($template) !== count($signature)) {
            return 0.0;
        }

        $dot = 0.0;
        $templateNorm = 0.0;
        $signatureNorm = 0.0;

        foreach ($template as $index => $templateValue) {
            $signatureValue = (float) $signature[$index];
            $templateValue = (float) $templateValue;
            $dot += $templateValue * $signatureValue;
            $templateNorm += $templateValue * $templateValue;
            $signatureNorm += $signatureValue * $signatureValue;
        }

        if ($templateNorm === 0.0 || $signatureNorm === 0.0) {
            return 0.0;
        }

        $similarity = $dot / (sqrt($templateNorm) * sqrt($signatureNorm));

        return round(max(0.0, min(100.0, (($similarity + 1) / 2) * 100)), 2);
    }

    private function noteForResult(
        string $decision,
        bool $hasEnrollment,
        float $matchScore,
        float $livenessScore,
    ): string {
        if (! $hasEnrollment) {
            return 'User belum menyelesaikan enrollment wajah dengan template biometrik aktif.';
        }

        if ($decision === 'retry') {
            return 'Verifikasi masih borderline. Ulangi scan di cahaya yang lebih stabil dengan wajah lurus, lalu kedip jelas sekali.';
        }

        if ($livenessScore < self::LIVENESS_RETRY_THRESHOLD) {
            return 'Liveness wajah terlalu lemah. Pastikan Anda benar-benar menoleh dan berkedip jelas.';
        }

        if ($livenessScore < self::LIVENESS_THRESHOLD) {
            return 'Liveness wajah belum cukup kuat. Ulangi scan dengan gerakan hidup yang lebih jelas.';
        }

        if ($matchScore < self::MATCH_RETRY_THRESHOLD) {
            return 'Wajah belum cukup mirip dengan template enrollment yang tersimpan.';
        }

        if ($matchScore < self::MATCH_THRESHOLD) {
            return 'Kemiripan wajah masih di batas bawah. Coba hadapkan wajah lebih lurus dan cahaya lebih rata.';
        }

        return 'Verifikasi wajah lolos dengan lightweight signature v2.';
    }
}
