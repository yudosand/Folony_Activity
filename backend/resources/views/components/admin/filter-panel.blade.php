@php
    $activeFilters = collect(request()->except(['page', 'export']))->filter(fn ($value) => is_scalar($value) && (string) $value !== '');
@endphp
<details class="filter-panel disclosure">
    <summary>
        <span>Filter pencarian</span>
        <span class="filter-status">{{ $activeFilters->isEmpty() ? 'Semua data' : $activeFilters->count().' filter aktif' }}</span>
    </summary>
    <div class="disclosure-body">
        {{ $slot }}
        @if($activeFilters->isNotEmpty())
            <a class="filter-reset" href="{{ request()->url() }}">Reset semua filter</a>
        @endif
    </div>
</details>
