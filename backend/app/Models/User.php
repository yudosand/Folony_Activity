<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
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
        'employee_code',
        'full_name',
        'phone_number',
        'area_name',
        'work_location',
        'office_latitude',
        'office_longitude',
        'attendance_radius_meters',
        'territory_scope',
        'territory_province',
        'territory_city',
        'territory_district',
        'territory_subdistrict',
        'territory_assignments',
        'role',
        'job_title',
        'spv_id',
        'management_id',
        'is_active',
        'leave_balance_days',
        'joined_at',
        'address',
        'emergency_contact_name',
        'emergency_contact_phone',
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
            'leave_balance_days' => 'decimal:2',
            'office_latitude' => 'decimal:7',
            'office_longitude' => 'decimal:7',
            'attendance_radius_meters' => 'integer',
            'joined_at' => 'date',
            'territory_assignments' => 'array',
            'password' => 'hashed',
        ];
    }

    public function isHrAdmin(): bool
    {
        return $this->role === 'hr';
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

    public function faceProfile(): HasOne
    {
        return $this->hasOne(FaceProfile::class, 'user_id');
    }

    public function faceVerificationLogs(): HasMany
    {
        return $this->hasMany(FaceVerificationLog::class, 'user_id');
    }

    public function performanceTargets(): HasMany
    {
        return $this->hasMany(PerformanceTarget::class, 'user_id');
    }

    public function pushDeviceTokens(): HasMany
    {
        return $this->hasMany(PushDeviceToken::class, 'user_id');
    }
}
