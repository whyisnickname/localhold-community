# SPDX-License-Identifier: MPL-2.0
<#
.SYNOPSIS
Runs record/search and attachment evidence on one physical ADB device.

.DESCRIPTION
The device may be local USB hardware or a reviewed remote real device exposed
through ADB. The script rejects emulators, ambiguous devices, uncommitted source,
failed release instrumentation and invalid evidence. Tests use only generated
records, synthetic keys and synthetic attachment bytes.
#>
[CmdletBinding()]
param(
    [string]$DeviceSerial = '',

    [ValidateSet('local-usb', 'selectel-mobile-farm')]
    [string]$DeviceSource = 'selectel-mobile-farm',

    [ValidateSet(1, 5)]
    [int]$AttachmentGib = 1,

    [string]$EvidenceDirectory = ''
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$appApk = Join-Path $repositoryRoot 'community\spikes\mobile_stress\android\app\build\outputs\apk\release\app-release.apk'
$testApk = Join-Path $repositoryRoot 'community\spikes\mobile_stress\android\app\build\outputs\apk\androidTest\release\app-release-androidTest.apk'
$validator = Join-Path $repositoryRoot 'community\spikes\mobile_stress\tools\validate_results.py'

function Resolve-AdbExecutable {
    $pathAdb = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($null -ne $pathAdb) { return $pathAdb.Source }
    foreach ($sdkRoot in @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)) {
        if (-not [string]::IsNullOrWhiteSpace($sdkRoot)) {
            $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
        }
    }
    $userProfileDirectory = [Environment]::GetFolderPath('UserProfile')
    $bundled = Join-Path $userProfileDirectory '.cache\localhold-tools\android-sdk\platform-tools\adb.exe'
    if (Test-Path -LiteralPath $bundled -PathType Leaf) { return $bundled }
    throw 'adb.exe is unavailable. Install Android SDK Platform-Tools first.'
}

function Invoke-SelectedAdb {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $result = & $script:adb -s $script:DeviceSerial @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')`n$($result -join "`n")"
    }
    return $result
}

foreach ($requiredFile in @($appApk, $testApk, $validator)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Required file is missing: $requiredFile"
    }
}
$revisionOutput = & git -C $repositoryRoot rev-parse HEAD 2>$null
$revision = if ($null -eq $revisionOutput) { '' } else { ([string]$revisionOutput).Trim() }
if ($LASTEXITCODE -ne 0 -or $revision -notmatch '^[0-9a-fA-F]{40,64}$') {
    throw 'A real committed Git revision is required before collecting release evidence.'
}
$workingTree = & git -C $repositoryRoot status --porcelain 2>$null
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($workingTree -join "`n"))) {
    throw 'A clean working tree is required so evidence matches the recorded revision.'
}

$adb = Resolve-AdbExecutable
$deviceLines = & $adb devices
if ($LASTEXITCODE -ne 0) { throw 'adb devices failed.' }
$readyDevices = @(
    $deviceLines | ForEach-Object {
        if ($_ -match '^([^\s]+)\s+device(?:\s|$)') { $Matches[1] }
    }
)
if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
    if ($readyDevices.Count -ne 1) {
        throw "Exactly one authorized ADB device is required; found $($readyDevices.Count)."
    }
    $DeviceSerial = $readyDevices[0]
} elseif ($DeviceSerial -notin $readyDevices) {
    throw 'The selected ADB serial is not present in the authorized device list.'
}

$qemu = ((Invoke-SelectedAdb -Arguments @('shell', 'getprop', 'ro.kernel.qemu')) -join '').Trim()
$hypervisor = ((Invoke-SelectedAdb -Arguments @('shell', 'getprop', 'ro.build.hv.platform')) -join '').Trim()
$abi = ((Invoke-SelectedAdb -Arguments @('shell', 'getprop', 'ro.product.cpu.abi')) -join '').Trim()
$api = ((Invoke-SelectedAdb -Arguments @('shell', 'getprop', 'ro.build.version.sdk')) -join '').Trim()
$model = ((Invoke-SelectedAdb -Arguments @('shell', 'getprop', 'ro.product.model')) -join '').Trim()
if ($DeviceSerial -match '^(127\.0\.0\.1|localhost):' -or
    $qemu -eq '1' -or
    -not [string]::IsNullOrWhiteSpace($hypervisor) -or
    $model -match '(?i)emulator|sdk_gphone|vbox' -or
    $api -notmatch '^\d+$') {
    throw 'Physical-device evidence cannot be collected from an emulator or unidentified runtime.'
}
if ($DeviceSource -eq 'selectel-mobile-farm' -and $DeviceSerial -notmatch '^adb\.mobfarm\.selectel\.ru:\d+$') {
    throw 'Selectel evidence requires the ADB endpoint issued by Selectel Mobile Farm.'
}
if ([int]$api -lt 24 -or $abi -ne 'arm64-v8a') {
    throw "A physical ARM64 Android API 24+ device is required; found ABI=$abi API=$api."
}

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
    $EvidenceDirectory = Join-Path $repositoryRoot "output\stage2-android\$($revision.Substring(0, 12))\mobile-stress-$($AttachmentGib)gib"
}
$EvidenceDirectory = [System.IO.Path]::GetFullPath($EvidenceDirectory)
[System.IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null
$logPath = Join-Path $EvidenceDirectory "mobile-stress-$($AttachmentGib)gib.log"
$recordPath = Join-Path $EvidenceDirectory 'record.json'
$attachmentPath = Join-Path $EvidenceDirectory "attachment-$($AttachmentGib)gib.json"
$metadataPath = Join-Path $EvidenceDirectory "mobile-stress-$($AttachmentGib)gib-run.json"
$appHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $appApk).Hash
$testHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $testApk).Hash
Write-Host "Physical device selected: $model, API $api, $abi ($DeviceSource)."
Write-Host "App APK SHA-256: $appHash"
Write-Host "Test APK SHA-256: $testHash"
Write-Host 'Only generated records, synthetic keys and synthetic attachment bytes are used.'

Invoke-SelectedAdb -Arguments @('install', '-r', '-t', $appApk) | Out-Host
Invoke-SelectedAdb -Arguments @('install', '-r', '-t', $testApk) | Out-Host
Invoke-SelectedAdb -Arguments @('logcat', '-c') | Out-Null
$target = 'dev.localhold.mobilestress.MobileStressInstrumentedTest#selectedPhysicalEvidence'
$instrumentation = Invoke-SelectedAdb -Arguments @(
    'shell', 'am', 'instrument', '-w', '-r',
    '-e', 'class', $target,
    '-e', 'attachmentGib', $AttachmentGib.ToString(),
    '-e', 'buildRevision', $revision,
    'dev.localhold.mobilestress.test/androidx.test.runner.AndroidJUnitRunner'
)
$logcat = Invoke-SelectedAdb -Arguments @(
    'logcat', '-d', '-v', 'threadtime', 'TestRunner:I', 'System.out:I', 'AndroidJUnitRunner:I', '*:S'
)
$combinedLog = (@($instrumentation) + @($logcat)) -join "`n"
[System.IO.File]::WriteAllText($logPath, $combinedLog + "`n", [System.Text.UTF8Encoding]::new($false))
if ($combinedLog -match 'FAILURES!!!|INSTRUMENTATION_FAILED|Process crashed' -or $combinedLog -notmatch 'OK \(') {
    throw "Instrumentation did not finish successfully. Inspect $logPath"
}

& python $validator $logPath $recordPath $attachmentPath
if ($LASTEXITCODE -ne 0) { throw "Evidence validation failed. Inspect $logPath" }
@{
    schema_version = 1
    device_source = $DeviceSource
    model = $model
    android_api = [int]$api
    abi = $abi
    revision = $revision
    app_apk_sha256 = $appHash
    test_apk_sha256 = $testHash
    record_evidence_file = [System.IO.Path]::GetFileName($recordPath)
    attachment_evidence_file = [System.IO.Path]::GetFileName($attachmentPath)
} | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8NoBOM
Write-Host "Validated record evidence: $recordPath"
Write-Host "Validated attachment evidence: $attachmentPath"
