@extends('admin.layouts.app')

@php
    $title = 'Detail Jaringan';
    $heading = $profile->name;
    $subheading = 'Rincian profil UKM/Mitra, owner, koordinat, dokumen, personality, dan histori follow-up.';

    $rawPhotos = $profile->photo_attachment;
    $photoItems = [];

    if (is_array($rawPhotos) && array_key_exists('url', $rawPhotos)) {
        $photoItems[] = $rawPhotos;
    } elseif (is_array($rawPhotos)) {
        $photoItems = array_values(array_filter($rawPhotos, fn ($item) => is_array($item) || is_string($item)));
    } elseif (is_string($rawPhotos) && $rawPhotos !== '') {
        $photoItems[] = ['file_name' => $rawPhotos];
    }

    $hasCoordinates = $profile->latitude !== null && $profile->longitude !== null;
    $coordinateLabel = $hasCoordinates
        ? number_format((float) $profile->latitude, 6, '.', '') . ', ' . number_format((float) $profile->longitude, 6, '.', '')
        : 'Belum ada koordinat';
    $googleMapsUrl = $hasCoordinates
        ? 'https://www.google.com/maps?q=' . $profile->latitude . ',' . $profile->longitude
        : null;
@endphp

@section('content')
    <div class="grid cols-4">
        <div class="card-kpi">
            <div class="label">Tipe</div>
            <div class="value">{{ strtoupper($profile->type) }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Status</div>
            <div class="value" style="font-size:24px;">{{ $profile->status }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Follow-up</div>
            <div class="value">{{ $profile->followUps->count() }}</div>
        </div>
        <div class="card-kpi">
            <div class="label">Area</div>
            <div class="value" style="font-size:24px;">{{ $profile->area_name ?: '-' }}</div>
        </div>
    </div>

    <div class="grid cols-2" style="margin-top:18px;">
        <div class="panel pad">
            <h3 style="margin-top:0;">Informasi Profil</h3>
            <div class="detail-list">
                <div class="detail-item"><strong>ID</strong><span>{{ $profile->id }}</span></div>
                <div class="detail-item"><strong>Owner</strong><span>{{ $profile->owner_name }} ({{ strtoupper($profile->owner_role) }})</span></div>
                <div class="detail-item"><strong>Bidang Usaha</strong><span>{{ $profile->business_type ?: '-' }}</span></div>
                <div class="detail-item"><strong>Alamat</strong><span>{{ $profile->address ?: '-' }}</span></div>
                <div class="detail-item"><strong>No. HP</strong><span>{{ $profile->phone_number ?: '-' }}</span></div>
                <div class="detail-item"><strong>Referensi</strong><span>{{ $profile->reference_name ?: '-' }}</span></div>
                <div class="detail-item"><strong>Catatan</strong><span>{{ $profile->note ?: '-' }}</span></div>
                <div class="detail-item">
                    <strong>Koordinat</strong>
                    <span>
                        <div class="stack" style="gap:6px;">
                            <span>{{ $coordinateLabel }}</span>
                            @if($googleMapsUrl)
                                <a class="attachment-link" href="{{ $googleMapsUrl }}" target="_blank" rel="noreferrer">Buka di Google Maps</a>
                            @endif
                        </div>
                    </span>
                </div>
            </div>
        </div>
        <div class="panel pad">
            <h3 style="margin-top:0;">Dokumen & Personality</h3>
            <div class="detail-list">
                <div class="detail-item">
                    <strong>Personality</strong>
                    <span>
                        @if(blank($profile->personality_metrics))
                            -
                        @else
                            <div class="stack">
                                @foreach($profile->personality_metrics as $metric)
                                    <span>{{ $metric['label'] ?? '-' }}: {{ $metric['score'] ?? '-' }}</span>
                                @endforeach
                            </div>
                        @endif
                    </span>
                </div>
                <div class="detail-item">
                    <strong>Dokumen</strong>
                    <span>
                        @if(blank($profile->documents))
                            -
                        @else
                            <div class="stack">
                                @foreach($profile->documents as $document)
                                    <div class="stack" style="gap:4px;">
                                        <span>{{ $document['label'] ?? '-' }}{{ isset($document['exists']) ? ' - ' . (($document['exists']) ? 'Ada' : 'Belum ada') : '' }}</span>
                                        @if(!empty($document['attachment']['url']))
                                            <a class="attachment-link" href="{{ $document['attachment']['url'] }}" target="_blank" rel="noreferrer">
                                                Buka lampiran{{ !empty($document['attachment']['file_name']) ? ': ' . $document['attachment']['file_name'] : '' }}
                                            </a>
                                        @endif
                                    </div>
                                @endforeach
                            </div>
                        @endif
                    </span>
                </div>
            </div>
        </div>
    </div>

    <div class="panel pad" style="margin-top:18px;">
        <div class="toolbar">
            <h3 style="margin:0;">Preview Foto</h3>
            <span class="muted">Foto UKM/Mitra yang dikirim dari aplikasi lapangan.</span>
        </div>
        @if(empty($photoItems))
            <div class="note-callout muted">Belum ada lampiran foto yang bisa dipreview.</div>
        @else
            <div class="attachment-gallery">
                @foreach($photoItems as $photo)
                    @php
                        $photoName = is_array($photo)
                            ? ($photo['file_name'] ?? $photo['label'] ?? $photo['url'] ?? 'Lampiran foto')
                            : (string) $photo;
                        $photoUrl = is_array($photo) ? ($photo['url'] ?? null) : null;
                        $photoThumb = is_array($photo) ? ($photo['thumbnail_url'] ?? $photoUrl) : null;
                    @endphp
                    <div class="attachment-card">
                        @if($photoThumb)
                            <a href="{{ $photoUrl ?: $photoThumb }}" target="_blank" rel="noreferrer">
                                <img src="{{ $photoThumb }}" alt="{{ $photoName }}">
                            </a>
                        @else
                            <div class="note-callout muted">Preview tidak tersedia</div>
                        @endif
                        <div class="attachment-meta">
                            <div class="attachment-name">{{ $photoName }}</div>
                            @if($photoUrl)
                                <a class="attachment-link" href="{{ $photoUrl }}" target="_blank" rel="noreferrer">Buka file</a>
                            @endif
                        </div>
                    </div>
                @endforeach
            </div>
        @endif
    </div>

    <div class="panel pad" style="margin-top:18px;">
        <h3 style="margin-top:0;">Histori Follow-up</h3>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Waktu</th><th>Judul</th><th>Catatan</th><th>Actor</th></tr></thead>
                <tbody>
                @forelse($profile->followUps as $followUp)
                    <tr>
                        <td>{{ $followUp->created_at?->format('d M Y H:i') ?: '-' }}</td>
                        <td>{{ $followUp->title }}</td>
                        <td>{{ $followUp->note }}</td>
                        <td>{{ $followUp->actor_name }}</td>
                    </tr>
                @empty
                    <tr><td colspan="4" class="muted">Belum ada follow-up.</td></tr>
                @endforelse
                </tbody>
            </table>
        </div>
    </div>
@endsection
