<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    public $incrementing = false;

    protected $keyType = 'string';

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'id',
        'full_name',
        'phone_number',
        'area_name',
        'role',
        'spv_id',
        'management_id',
        'is_active',
        'email',
        'password',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'is_active' => 'boolean',
            'password' => 'hashed',
        ];
    }

    public function spv(): BelongsTo
    {
        return $this->belongsTo(self::class, 'spv_id');
    }

    public function management(): BelongsTo
    {
        return $this->belongsTo(self::class, 'management_id');
    }

    public function leaveRequests(): HasMany
    {
        return $this->hasMany(LeaveRequest::class, 'requester_id');
    }

    public function wfaRequests(): HasMany
    {
        return $this->hasMany(WfaRequest::class, 'requester_id');
    }

    public function networkProfiles(): HasMany
    {
        return $this->hasMany(NetworkProfile::class, 'owner_id');
    }

    public function attendanceRecords(): HasMany
    {
        return $this->hasMany(AttendanceRecord::class, 'user_id');
    }
}
