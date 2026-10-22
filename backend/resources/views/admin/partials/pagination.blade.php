@if ($paginator->hasPages())
    <nav aria-label="Halaman daftar">
        <div>{{ $paginator->firstItem() ?? 0 }}–{{ $paginator->lastItem() ?? 0 }} dari {{ number_format($paginator->total(), 0, ',', '.') }} data</div>
        <div class="page-controls">
            @if ($paginator->onFirstPage())
                <span aria-disabled="true">‹ Sebelumnya</span>
            @else
                <a href="{{ $paginator->previousPageUrl() }}" rel="prev">‹ Sebelumnya</a>
            @endif
            @foreach ($elements as $element)
                @if (is_string($element))
                    <span aria-disabled="true">{{ $element }}</span>
                @else
                    @foreach ($element as $page => $url)
                        @if ($page == $paginator->currentPage())
                            <span aria-current="page" aria-label="Halaman {{ $page }}">{{ $page }}</span>
                        @else
                            <a href="{{ $url }}" aria-label="Halaman {{ $page }}">{{ $page }}</a>
                        @endif
                    @endforeach
                @endif
            @endforeach
            @if ($paginator->hasMorePages())
                <a href="{{ $paginator->nextPageUrl() }}" rel="next">Berikutnya ›</a>
            @else
                <span aria-disabled="true">Berikutnya ›</span>
            @endif
        </div>
    </nav>
@endif
