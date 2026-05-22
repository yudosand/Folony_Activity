param(
    [string]$OutputPath = "dist\indonesia_territories_wilayah_id_2025.json"
)

$ErrorActionPreference = 'Stop'

function Invoke-WilayahApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    return Invoke-RestMethod -Uri $Uri -Headers @{
        'User-Agent' = 'FolonyActivity/1.0 TerritoryExport'
        'Accept' = 'application/json'
    }
}

function Normalize-Name {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return ($Value.Trim().ToLower() -replace '\s+', ' ')
}

$outputAbsolute = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath
} else {
    Join-Path (Get-Location) $OutputPath
}

$outputDirectory = Split-Path -Parent $outputAbsolute
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$rows = New-Object System.Collections.Generic.List[object]

Write-Host 'Mengambil daftar provinsi...'
$provinceResponse = Invoke-WilayahApi -Uri 'https://wilayah.id/api/provinces.json'
$provinces = @($provinceResponse.data)
$provinceCount = $provinces.Count

for ($provinceIndex = 0; $provinceIndex -lt $provinceCount; $provinceIndex++) {
    $province = $provinces[$provinceIndex]
    Write-Progress -Activity 'Export master wilayah Indonesia' -Status "Provinsi $($province.name) ($($provinceIndex + 1)/$provinceCount)" -PercentComplete ((($provinceIndex + 1) / [math]::Max($provinceCount, 1)) * 100)

    $rows.Add([ordered]@{
        code = $province.code
        level = 'province'
        name = $province.name
        normalized_name = Normalize-Name -Value $province.name
        parent_code = $null
        province_code = $province.code
        city_code = $null
        district_code = $null
        province_name = $province.name
        city_name = $null
        district_name = $null
    })

    $regencyResponse = Invoke-WilayahApi -Uri ("https://wilayah.id/api/regencies/{0}.json" -f $province.code)
    foreach ($city in @($regencyResponse.data)) {
        $rows.Add([ordered]@{
            code = $city.code
            level = 'city'
            name = $city.name
            normalized_name = Normalize-Name -Value $city.name
            parent_code = $province.code
            province_code = $province.code
            city_code = $city.code
            district_code = $null
            province_name = $province.name
            city_name = $city.name
            district_name = $null
        })

        $districtResponse = Invoke-WilayahApi -Uri ("https://wilayah.id/api/districts/{0}.json" -f $city.code)
        foreach ($district in @($districtResponse.data)) {
            $rows.Add([ordered]@{
                code = $district.code
                level = 'district'
                name = $district.name
                normalized_name = Normalize-Name -Value $district.name
                parent_code = $city.code
                province_code = $province.code
                city_code = $city.code
                district_code = $district.code
                province_name = $province.name
                city_name = $city.name
                district_name = $district.name
            })

            $villageResponse = Invoke-WilayahApi -Uri ("https://wilayah.id/api/villages/{0}.json" -f $district.code)
            foreach ($subdistrict in @($villageResponse.data)) {
                $rows.Add([ordered]@{
                    code = $subdistrict.code
                    level = 'subdistrict'
                    name = $subdistrict.name
                    normalized_name = Normalize-Name -Value $subdistrict.name
                    parent_code = $district.code
                    province_code = $province.code
                    city_code = $city.code
                    district_code = $district.code
                    province_name = $province.name
                    city_name = $city.name
                    district_name = $district.name
                })
            }
        }
    }
}

$json = $rows | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($outputAbsolute, $json, [System.Text.Encoding]::UTF8)

Write-Progress -Activity 'Export master wilayah Indonesia' -Completed
Write-Host ("Selesai. {0} baris disimpan ke {1}" -f $rows.Count, $outputAbsolute)
