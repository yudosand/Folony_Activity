<?php

namespace App\Services;

use App\Models\ApprovalStep;
use App\Models\LeaveRequest;
use App\Models\PushDeviceToken;
use App\Models\WfaRequest;
use App\Support\Workflow\ApprovalStepStatus;
use App\Support\Workflow\WorkflowModule;
use Illuminate\Support\Arr;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    public function notifyPendingApproversForLeave(LeaveRequest $leaveRequest): void
    {
        $steps = $leaveRequest->approvalSteps
            ->where('status', ApprovalStepStatus::PENDING)
            ->sortBy('sequence')
            ->groupBy('sequence');

        $firstSequence = $steps->keys()->first();
        if ($firstSequence === null) {
            return;
        }

        $pendingSteps = $steps->get($firstSequence) ?? collect();
        $approverIds = $pendingSteps->pluck('approver_id')->filter()->values()->all();

        $this->sendToUsers(
            $approverIds,
            title: 'Approval cuti / izin baru',
            body: "{$leaveRequest->requester_name} mengajukan {$leaveRequest->category}.",
            data: [
                'type' => 'approval_pending',
                'module' => WorkflowModule::LEAVE,
                'reference_id' => $leaveRequest->id,
            ],
        );
    }

    public function notifyPendingApproversForWfa(WfaRequest $wfaRequest): void
    {
        $steps = $wfaRequest->approvalSteps
            ->where('status', ApprovalStepStatus::PENDING)
            ->sortBy('sequence')
            ->groupBy('sequence');

        $firstSequence = $steps->keys()->first();
        if ($firstSequence === null) {
            return;
        }

        $pendingSteps = $steps->get($firstSequence) ?? collect();
        $approverIds = $pendingSteps->pluck('approver_id')->filter()->values()->all();

        $this->sendToUsers(
            $approverIds,
            title: 'Approval WFH / WFA baru',
            body: "{$wfaRequest->requester_name} mengajukan {$wfaRequest->mode}.",
            data: [
                'type' => 'approval_pending',
                'module' => WorkflowModule::WFA,
                'reference_id' => $wfaRequest->id,
            ],
        );
    }

    public function notifyNextApprovers(ApprovalStep $step): void
    {
        $query = ApprovalStep::query()
            ->where('module', $step->module)
            ->where('reference_id', $step->reference_id)
            ->where('status', ApprovalStepStatus::PENDING);

        $nextSequence = $query->min('sequence');
        if ($nextSequence === null) {
            return;
        }

        $nextSteps = ApprovalStep::query()
            ->where('module', $step->module)
            ->where('reference_id', $step->reference_id)
            ->where('status', ApprovalStepStatus::PENDING)
            ->where('sequence', $nextSequence)
            ->get();

        if ($nextSteps->isEmpty()) {
            return;
        }

        $referenceLabel = $step->module === WorkflowModule::LEAVE
            ? 'cuti / izin'
            : 'WFH / WFA';

        $this->sendToUsers(
            $nextSteps->pluck('approver_id')->filter()->values()->all(),
            title: 'Approval menunggu keputusan',
            body: "Ada pengajuan {$referenceLabel} baru yang menunggu review Anda.",
            data: [
                'type' => 'approval_pending',
                'module' => $step->module,
                'reference_id' => $step->reference_id,
            ],
        );
    }

    public function notifyRequesterStatusChanged(
        string $requesterId,
        string $module,
        string $status,
        string $requesterName,
        string $summary
    ): void {
        $moduleLabel = $module === WorkflowModule::LEAVE ? 'Cuti / izin' : 'WFH / WFA';
        $statusLabel = $status === 'approved' ? 'disetujui' : 'ditolak';

        $this->sendToUsers(
            [$requesterId],
            title: "{$moduleLabel} {$statusLabel}",
            body: "{$requesterName}, pengajuan {$summary} {$statusLabel}.",
            data: [
                'type' => 'approval_result',
                'module' => $module,
                'status' => $status,
            ],
        );
    }

    /**
     * @param array<int, string> $userIds
     * @param array<string, scalar|null> $data
     */
    public function sendToUsers(array $userIds, string $title, string $body, array $data = []): void
    {
        $tokens = PushDeviceToken::query()
            ->whereIn('user_id', array_values(array_unique(array_filter($userIds))))
            ->pluck('token')
            ->filter()
            ->unique()
            ->values();

        if ($tokens->isEmpty()) {
            return;
        }

        $projectId = (string) config('services.firebase.project_id');
        $accessToken = $this->firebaseAccessToken();

        if ($projectId === '' || $accessToken === null) {
            Log::warning('Firebase push notification skipped because server credentials are incomplete.', [
                'project_id_present' => $projectId !== '',
                'token_count' => $tokens->count(),
                'title' => $title,
            ]);

            return;
        }

        foreach ($tokens as $token) {
            $response = Http::withToken($accessToken)
                ->acceptJson()
                ->post(
                    "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send",
                    [
                        'message' => [
                            'token' => $token,
                            'notification' => [
                                'title' => $title,
                                'body' => $body,
                            ],
                            'data' => collect($data)
                                ->map(fn ($value) => $value === null ? '' : (string) $value)
                                ->all(),
                            'android' => [
                                'priority' => 'high',
                            ],
                        ],
                    ]
                );

            if (! $response->successful()) {
                Log::warning('Firebase push send failed.', [
                    'status' => $response->status(),
                    'body' => $response->json() ?? $response->body(),
                ]);
            }
        }
    }

    private function firebaseAccessToken(): ?string
    {
        $serviceAccount = $this->serviceAccountPayload();
        if ($serviceAccount === null) {
            return null;
        }

        return Cache::remember('firebase.server_access_token', now()->addMinutes(50), function () use ($serviceAccount) {
            $issuedAt = time();
            $expiresAt = $issuedAt + 3600;
            $jwtHeader = $this->base64UrlEncode(json_encode([
                'alg' => 'RS256',
                'typ' => 'JWT',
            ]));
            $jwtPayload = $this->base64UrlEncode(json_encode([
                'iss' => $serviceAccount['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $issuedAt,
                'exp' => $expiresAt,
            ]));

            $signatureInput = "{$jwtHeader}.{$jwtPayload}";
            $signature = '';
            $signed = openssl_sign(
                $signatureInput,
                $signature,
                $serviceAccount['private_key'],
                'sha256WithRSAEncryption'
            );

            if (! $signed) {
                Log::warning('Firebase JWT signing failed.');

                return null;
            }

            $jwt = "{$signatureInput}.{$this->base64UrlEncode($signature)}";
            $response = Http::asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            if (! $response->successful()) {
                Log::warning('Firebase access token request failed.', [
                    'status' => $response->status(),
                    'body' => $response->json() ?? $response->body(),
                ]);

                return null;
            }

            return (string) Arr::get($response->json(), 'access_token', '');
        });
    }

    /**
     * @return array<string, string>|null
     */
    private function serviceAccountPayload(): ?array
    {
        $rawJson = config('services.firebase.service_account_json');
        if (is_string($rawJson) && trim($rawJson) !== '') {
            $decoded = json_decode($rawJson, true);

            return is_array($decoded) ? $decoded : null;
        }

        $path = config('services.firebase.service_account_path');
        if (! is_string($path) || trim($path) === '' || ! is_file($path)) {
            return null;
        }

        $decoded = json_decode((string) file_get_contents($path), true);

        return is_array($decoded) ? $decoded : null;
    }

    private function base64UrlEncode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }
}
