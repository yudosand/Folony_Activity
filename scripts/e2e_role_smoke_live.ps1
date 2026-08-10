param(
    [string]$BaseUrl = "https://absent.folony.co.id/api"
)

$ErrorActionPreference = "Stop"

$runId = Get-Date -Format "yyyyMMddHHmmss"

$users = @{
    management = @{
        identifier = "081111111111"
        password = "123456"
        id = "usr_mgt_001"
    }
    spv = @{
        identifier = "082222222222"
        password = "123456"
        id = "usr_spv_001"
    }
    staff = @{
        identifier = "083333333333"
        password = "123456"
        id = "usr_001"
    }
    areaManager = @{
        identifier = "084444444444"
        password = "123456"
        id = "usr_area_001"
    }
    fgg = @{
        identifier = "085555555555"
        password = "123456"
        id = "usr_fgg_001"
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "ASSERT FAILED: $Message"
    }
}

function Invoke-Api {
    param(
        [ValidateSet("GET", "POST", "PATCH", "DELETE")]
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [string]$Token = $null,
        [hashtable]$ExtraHeaders = @{}
    )

    $headers = @{
        Accept = "application/json"
    }

    foreach ($key in $ExtraHeaders.Keys) {
        $headers[$key] = $ExtraHeaders[$key]
    }

    if ($Token) {
        $headers["Authorization"] = "Bearer $Token"
    }

    $params = @{
        Method = $Method
        Uri = "$BaseUrl$Path"
        Headers = $headers
    }

    if ($null -ne $Body) {
        $params["ContentType"] = "application/json"
        $params["Body"] = ($Body | ConvertTo-Json -Depth 20)
    }

    return Invoke-RestMethod @params
}

function Login-User {
    param([string]$RoleKey)

    $credential = $users[$RoleKey]
    $response = Invoke-Api -Method POST -Path "/auth/login" -Body @{
        identifier = $credential.identifier
        password = $credential.password
    }

    Assert-True ($null -ne $response.data.token) "Token login untuk role $RoleKey tidak ada."
    Assert-True ($response.data.user.id -eq $credential.id) "User ID login untuk role $RoleKey tidak cocok."

    return $response.data
}

Write-Step "Login semua role"
$staffSession = Login-User -RoleKey "staff"
$spvSession = Login-User -RoleKey "spv"
$managementSession = Login-User -RoleKey "management"
$fggSession = Login-User -RoleKey "fgg"
$areaManagerSession = Login-User -RoleKey "areaManager"

Write-Step "Validasi /me semua role"
foreach ($session in @(
    @{ name = "staff"; token = $staffSession.token; id = $staffSession.user.id },
    @{ name = "spv"; token = $spvSession.token; id = $spvSession.user.id },
    @{ name = "management"; token = $managementSession.token; id = $managementSession.user.id },
    @{ name = "fgg"; token = $fggSession.token; id = $fggSession.user.id },
    @{ name = "areaManager"; token = $areaManagerSession.token; id = $areaManagerSession.user.id }
)) {
    $me = Invoke-Api -Method GET -Path "/me" -Token $session.token
    Assert-True ($me.data.id -eq $session.id) "/me untuk $($session.name) tidak cocok."
}

$today = Get-Date
$leaveStart = $today.Date.AddHours(8).AddMinutes(30)
$leaveEnd = $leaveStart.AddDays(1)
$wfaWorkDate = $today.Date
$attendanceCheckIn = $today.Date.AddHours(8).AddMinutes(35)
$attendanceCheckOut = $today.Date.AddHours(17).AddMinutes(20)

$staffLeaveId = "leave_staff_$runId"
$staffWfaId = "wfa_staff_$runId"
$spvLeaveId = "leave_spv_$runId"
$areaWfaId = "wfa_area_$runId"
$fggUkmId = "net_fgg_$runId"
$areaMitraId = "net_area_$runId"

Write-Step "Staff submit leave"
$staffLeave = Invoke-Api -Method POST -Path "/leave" -Token $staffSession.token -Body @{
    id = $staffLeaveId
    requester_id = $staffSession.user.id
    category = "izinPerHari"
    compensation_option = "tidakPotongGaji"
    start_at = $leaveStart.ToString("o")
    end_at = $leaveEnd.ToString("o")
    duration_value = 1
    reason = "E2E smoke leave $runId"
    delegate_to = "Backup Staff"
    note = "Smoke staff leave"
}
Assert-True ($staffLeave.data.id -eq $staffLeaveId) "Leave Staff gagal dibuat."
Assert-True ($staffLeave.data.status -eq "pending") "Status awal leave Staff harus pending."

Write-Step "Staff submit WFA overtime"
$staffWfa = Invoke-Api -Method POST -Path "/wfa" -Token $staffSession.token -Body @{
    id = $staffWfaId
    requester_id = $staffSession.user.id
    mode = "overtime"
    compensation_mode = "shiftMundur"
    work_date = $wfaWorkDate.ToString("o")
    start_time = "19:00"
    end_time = "21:00"
    location_label = "Rumah - smoke $runId"
    reason = "E2E smoke WFA staff"
    initial_task = "Follow up meeting malam"
    note = "Smoke staff WFA"
}
Assert-True ($staffWfa.data.id -eq $staffWfaId) "WFA Staff gagal dibuat."
Assert-True ($staffWfa.data.status -eq "pending") "Status awal WFA Staff harus pending."

Write-Step "Staff lihat data leave dan WFA miliknya"
$staffLeaves = Invoke-Api -Method GET -Path "/leave" -Token $staffSession.token
$staffWfas = Invoke-Api -Method GET -Path "/wfa" -Token $staffSession.token
Assert-True (@($staffLeaves.data | Where-Object { $_.id -eq $staffLeaveId }).Count -ge 1) "Leave Staff tidak muncul di list miliknya."
Assert-True (@($staffWfas.data | Where-Object { $_.id -eq $staffWfaId }).Count -ge 1) "WFA Staff tidak muncul di list miliknya."

Write-Step "SPV approve leave dan WFA Staff"
$spvInbox = Invoke-Api -Method GET -Path "/approvals/inbox" -Token $spvSession.token
$spvStaffLeave = $spvInbox.data | Where-Object { $_.module -eq "leave" -and $_.reference_id -eq $staffLeaveId } | Select-Object -First 1
$spvStaffWfa = $spvInbox.data | Where-Object { $_.module -eq "wfa" -and $_.reference_id -eq $staffWfaId } | Select-Object -First 1
Assert-True ($null -ne $spvStaffLeave) "SPV inbox tidak menemukan leave Staff."
Assert-True ($null -ne $spvStaffWfa) "SPV inbox tidak menemukan WFA Staff."

$null = Invoke-Api -Method POST -Path "/approvals/leave::$staffLeaveId/approve" -Token $spvSession.token -Body @{
    approver_id = $spvSession.user.id
    approver_name = $spvSession.user.full_name
    note = "SPV approve smoke leave"
}

$null = Invoke-Api -Method POST -Path "/approvals/wfa::$staffWfaId/approve" -Token $spvSession.token -Body @{
    approver_id = $spvSession.user.id
    approver_name = $spvSession.user.full_name
    note = "SPV approve smoke WFA"
}

Write-Step "SPV submit leave direct ke Management"
$spvLeave = Invoke-Api -Method POST -Path "/leave" -Token $spvSession.token -Body @{
    id = $spvLeaveId
    requester_id = $spvSession.user.id
    category = "cuti"
    compensation_option = "potongSaldoCuti"
    start_at = $leaveStart.AddDays(2).ToString("o")
    end_at = $leaveEnd.AddDays(2).ToString("o")
    duration_value = 1
    reason = "E2E smoke leave SPV"
    delegate_to = "Acting SPV"
    note = "Smoke SPV leave"
}
Assert-True ($spvLeave.data.id -eq $spvLeaveId) "Leave SPV gagal dibuat."

Write-Step "Area Manager submit WFA direct ke Management"
$areaWfa = Invoke-Api -Method POST -Path "/wfa" -Token $areaManagerSession.token -Body @{
    id = $areaWfaId
    requester_id = $areaManagerSession.user.id
    mode = "regular"
    work_date = $wfaWorkDate.AddDays(1).ToString("o")
    start_time = "08:30"
    end_time = "17:00"
    location_label = "Lapangan Depok smoke $runId"
    reason = "Kunjungan area manager"
    initial_task = "Monitoring UKM tim"
    note = "Smoke area manager WFA"
}
Assert-True ($areaWfa.data.id -eq $areaWfaId) "WFA Area Manager gagal dibuat."

Write-Step "Management approve semua yang relevan"
$managementInbox = Invoke-Api -Method GET -Path "/approvals/inbox" -Token $managementSession.token
$managementRefs = @($staffLeaveId, $staffWfaId, $spvLeaveId, $areaWfaId)
foreach ($referenceId in $managementRefs) {
    $item = $managementInbox.data | Where-Object { $_.reference_id -eq $referenceId } | Select-Object -First 1
    Assert-True ($null -ne $item) "Management inbox tidak menemukan reference $referenceId."
    $module = $item.module
    $null = Invoke-Api -Method POST -Path "/approvals/$module::$referenceId/approve" -Token $managementSession.token -Body @{
        approver_id = $managementSession.user.id
        approver_name = $managementSession.user.full_name
        note = "Management approve $referenceId"
    }
}

Write-Step "Validasi status final workflow setelah approval"
$staffLeaveAfter = Invoke-Api -Method GET -Path "/leave" -Token $staffSession.token
$staffWfaAfter = Invoke-Api -Method GET -Path "/wfa" -Token $staffSession.token
$spvLeaveAfter = Invoke-Api -Method GET -Path "/leave" -Token $spvSession.token
$areaWfaAfter = Invoke-Api -Method GET -Path "/wfa" -Token $areaManagerSession.token

$staffLeaveRecord = $staffLeaveAfter.data | Where-Object { $_.id -eq $staffLeaveId } | Select-Object -First 1
$staffWfaRecord = $staffWfaAfter.data | Where-Object { $_.id -eq $staffWfaId } | Select-Object -First 1
$spvLeaveRecord = $spvLeaveAfter.data | Where-Object { $_.id -eq $spvLeaveId } | Select-Object -First 1
$areaWfaRecord = $areaWfaAfter.data | Where-Object { $_.id -eq $areaWfaId } | Select-Object -First 1

Assert-True ($staffLeaveRecord.status -eq "approved") "Leave Staff harus approved setelah step Management."
Assert-True ($staffWfaRecord.status -eq "approved") "WFA Staff harus approved setelah step Management."
Assert-True ($spvLeaveRecord.status -eq "approved") "Leave SPV harus approved setelah Management."
Assert-True ($areaWfaRecord.status -eq "approved") "WFA Area Manager harus approved setelah Management."

Write-Step "Staff tambah task update ke WFA yang sudah approved"
$staffWfaUpdate = Invoke-Api -Method POST -Path "/wfa/$staffWfaId/task-updates" -Token $staffSession.token -Body @{
    actor_id = $staffSession.user.id
    message = "Task update smoke $runId"
    attachments = @()
}
Assert-True (@($staffWfaUpdate.data.task_updates | Where-Object { $_.message -eq "Task update smoke $runId" }).Count -ge 1) "Task update WFA Staff tidak tersimpan."

Write-Step "FGG tambah UKM dan follow-up"
$fggUkm = Invoke-Api -Method POST -Path "/network" -Token $fggSession.token -Body @{
    id = $fggUkmId
    type = "ukm"
    name = "UKM Smoke $runId"
    address = "Jl. Smoke FGG $runId"
    business_type = "Retail"
    phone_number = "081200000001"
    status = "followUp"
    reference_name = "Referral smoke"
    note = "Created by FGG smoke test"
    latitude = -6.3671
    longitude = 106.8291
}
Assert-True ($fggUkm.data.id -eq $fggUkmId) "UKM FGG gagal dibuat."

$fggFollowUp = Invoke-Api -Method POST -Path "/network/$fggUkmId/follow-ups" -Token $fggSession.token -Body @{
    title = "Follow up smoke"
    note = "FGG follow up smoke $runId"
    next_status = "completed"
}
Assert-True ($fggFollowUp.data.status -eq "completed") "Status UKM FGG tidak berubah setelah follow-up."

$fggNetworkList = Invoke-Api -Method GET -Path "/network?type=ukm&q=Smoke%20$runId" -Token $fggSession.token
Assert-True (@($fggNetworkList.data | Where-Object { $_.id -eq $fggUkmId }).Count -ge 1) "UKM FGG tidak muncul di list/search."

Write-Step "Area Manager lihat UKM tim FGG dan tambah Mitra"
$teamUkm = Invoke-Api -Method GET -Path "/network/team-ukm?q=Smoke%20$runId" -Token $areaManagerSession.token
Assert-True (@($teamUkm.data | Where-Object { $_.id -eq $fggUkmId }).Count -ge 1) "Area Manager tidak melihat UKM tim FGG."

$areaMitra = Invoke-Api -Method POST -Path "/network" -Token $areaManagerSession.token -Body @{
    id = $areaMitraId
    type = "mitra"
    name = "Mitra Smoke $runId"
    address = "Jl. Smoke Area $runId"
    business_type = "Distribusi"
    phone_number = "081200000002"
    status = "draft"
    reference_name = "Referral area"
    note = "Created by area manager smoke test"
    latitude = -6.3708
    longitude = 106.8333
}
Assert-True ($areaMitra.data.id -eq $areaMitraId) "Mitra Area Manager gagal dibuat."

$areaNetworkList = Invoke-Api -Method GET -Path "/network?type=mitra&q=Smoke%20$runId" -Token $areaManagerSession.token
Assert-True (@($areaNetworkList.data | Where-Object { $_.id -eq $areaMitraId }).Count -ge 1) "Mitra Area Manager tidak muncul di list/search."

Write-Step "Area Manager test attendance dan summary"
$null = Invoke-Api -Method DELETE -Path "/attendance" -Token $areaManagerSession.token
$checkIn = Invoke-Api -Method POST -Path "/attendance/check-in" -Token $areaManagerSession.token -Body @{
    recorded_at = $attendanceCheckIn.ToString("o")
    location = @{
        latitude = -6.3690
        longitude = 106.8300
        recorded_at = $attendanceCheckIn.ToString("o")
        address_label = "Depok Smoke"
        radius_meters = 150
        within_radius = $true
    }
    verification = @{
        verified_at = $attendanceCheckIn.AddSeconds(-20).ToString("o")
        match_score = 0.98
        liveness_score = 0.95
    }
    note = "Smoke check-in"
}
$checkOut = Invoke-Api -Method POST -Path "/attendance/check-out" -Token $areaManagerSession.token -Body @{
    recorded_at = $attendanceCheckOut.ToString("o")
    location = @{
        latitude = -6.3690
        longitude = 106.8300
        recorded_at = $attendanceCheckOut.ToString("o")
        address_label = "Depok Smoke"
        radius_meters = 150
        within_radius = $true
    }
    verification = @{
        verified_at = $attendanceCheckOut.AddSeconds(-20).ToString("o")
        match_score = 0.99
        liveness_score = 0.96
    }
    note = "Smoke check-out"
}
Assert-True ($checkIn.data.action -eq "checkIn") "Attendance check-in gagal."
Assert-True ($checkOut.data.action -eq "checkOut") "Attendance check-out gagal."

$attendanceSummary = Invoke-Api -Method GET -Path "/attendance/daily-summary?date=$($today.ToString("yyyy-MM-dd"))" -Token $areaManagerSession.token
Assert-True ($null -ne $attendanceSummary.data) "Attendance daily summary kosong."
Assert-True ($attendanceSummary.data.arrival_label -ne $null) "Attendance summary tidak memiliki arrival_label."
Assert-True ($attendanceSummary.data.departure_label -ne $null) "Attendance summary tidak memiliki departure_label."

Write-Step "Area Manager test heat map"
$heatMap = Invoke-Api -Method GET -Path "/heat-map?latitude=-6.3690&longitude=106.8300&radius_meters=5000" -Token $areaManagerSession.token
Assert-True ($null -ne $heatMap.data.points) "Heat map tidak mengembalikan data points."
Assert-True (@($heatMap.data.points | Where-Object { $_.id -eq $fggUkmId }).Count -ge 1) "Heat map tidak memuat UKM FGG baru."
Assert-True (@($heatMap.data.points | Where-Object { $_.id -eq $areaMitraId }).Count -ge 1) "Heat map tidak memuat Mitra Area Manager baru."

Write-Step "Logout semua role"
foreach ($token in @(
    $staffSession.token,
    $spvSession.token,
    $managementSession.token,
    $fggSession.token,
    $areaManagerSession.token
)) {
    $null = Invoke-Api -Method POST -Path "/auth/logout" -Token $token
}

Write-Step "E2E role smoke selesai"
[pscustomobject]@{
    base_url = $BaseUrl
    run_id = $runId
    staff_leave_id = $staffLeaveId
    staff_wfa_id = $staffWfaId
    spv_leave_id = $spvLeaveId
    area_manager_wfa_id = $areaWfaId
    fgg_ukm_id = $fggUkmId
    area_manager_mitra_id = $areaMitraId
    result = "PASS"
} | ConvertTo-Json -Depth 5
