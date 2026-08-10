@extends('admin.layouts.app')

@php
    $title = 'Edit Karyawan';
    $heading = 'Edit Karyawan';
    $subheading = 'Perbarui data kepegawaian, saldo cuti, dan akses login mobile.';
@endphp

@section('content')
    @if($errors->any())
        <div class="error-banner">{{ $errors->first() }}</div>
    @endif
    <div class="grid cols-2">
        <div class="panel pad">
            <div class="eyebrow" style="margin-bottom:10px;">Pembaruan Data</div>
            <h3 style="margin:0 0 10px;">{{ $employee->full_name }}</h3>
            <p class="muted" style="margin:0 0 8px;">{{ $employee->employee_code }} &middot; {{ \App\Support\Workflow\UserRole::label($employee->role) }}</p>
            <p class="muted" style="margin:0;">Rapikan role, jabatan, lokasi kerja, dan saldo cuti agar sinkron dengan aplikasi mobile.</p>
        </div>
        <div class="panel pad">
            <form method="POST" action="{{ $action }}">
                @include('admin.employees._form')
            </form>
        </div>
    </div>
@endsection
