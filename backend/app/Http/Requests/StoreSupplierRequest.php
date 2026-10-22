<?php

namespace App\Http\Requests;

use App\Support\Workflow\UserRole;
use Illuminate\Foundation\Http\FormRequest;

class StoreSupplierRequest extends FormRequest
{
    public function authorize(): bool
    {
        $roles = [UserRole::SPV, UserRole::MANAGEMENT, UserRole::AREA_MANAGER];
        if (! $this->is('api/*')) $roles = [UserRole::HR];

        return $this->user()?->is_active && in_array($this->user()->role, $roles, true);
    }

    protected function prepareForValidation(): void
    {
        if (is_array($this->input('items'))) {
            $this->merge(['items' => array_map(fn ($item) => is_string($item) ? trim($item) : $item, $this->input('items'))]);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'pic_name' => ['required', 'string', 'max:255'],
            'phone_number' => ['required', 'string', 'max:32', 'regex:/^\+?[0-9][0-9\s().-]{5,30}$/'],
            'territory_province' => ['nullable', 'required_if:location_source,manual', 'string', 'max:255'],
            'territory_city' => ['nullable', 'required_if:location_source,manual', 'string', 'max:255'],
            'territory_district' => ['nullable', 'required_if:location_source,manual', 'string', 'max:255'],
            'address' => ['nullable', 'required_if:location_source,manual', 'string', 'max:1000'],
            'location_source' => ['required', 'in:manual,gps,map'],
            'latitude' => ['nullable', 'required_with:longitude', 'required_if:location_source,gps,map', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'required_if:location_source,gps,map', 'numeric', 'between:-180,180'],
            'items' => ['required', 'array', 'min:1', 'max:50'],
            'items.*' => ['required', 'string', 'max:255', 'distinct:ignore_case'],
            'notes' => ['nullable', 'string', 'max:3000'],
        ];
    }

    public function attributes(): array
    {
        return ['name' => 'nama supplier', 'pic_name' => 'nama PIC supplier', 'phone_number' => 'nomor HP', 'territory_province' => 'provinsi',
            'territory_city' => 'kota/kabupaten', 'territory_district' => 'kecamatan', 'address' => 'alamat',
            'items' => 'jenis kebutuhan', 'items.*' => 'nama barang', 'notes' => 'catatan'];
    }
}
