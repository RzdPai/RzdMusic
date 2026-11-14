# Static self-check for the "lock screen keeps playing" setting (261018-2247).
# ASCII only on purpose: Windows PowerShell 5.1 + non-ASCII in .ps1 breaks quoting.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-lock-screen-play.ps1

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$fail = 0

function Check([string]$id, [string]$file, [string]$pattern, [string]$what) {
  $path = Join-Path $root $file
  if (-not (Test-Path $path)) {
    Write-Output "[FAIL] $id file missing: $file"
    $script:fail++
    return
  }
  if (Select-String -Path $path -Pattern $pattern -Quiet) {
    Write-Output "[PASS] $id $what"
  } else {
    Write-Output "[FAIL] $id $what"
    $script:fail++
  }
}

$store = 'common\musicbasic\src\main\ets\util\MusicStoreService.ets'
$media = 'features\player\src\main\ets\model\MediaService.ets'
$page = 'features\setting\src\main\ets\view\SettingsDetailPage.ets'

Write-Output '=== A. persistence (default must be ON) ==='
Check 'A1' $store "KEY_LOCK_SCREEN_PLAY: string = 'lock_screen_play'" 'storage key declared'
Check 'A2' $store 'getSync\(KEY_LOCK_SCREEN_PLAY, true\)' 'default value is true (not false)'
Check 'A3' $store 'getLockScreenPlay\(\): boolean' 'getter exists'
Check 'A4' $store 'setLockScreenPlay\(enabled: boolean\)' 'setter exists'
Check 'A5' $store 'return true;' 'missing store still resolves to ON'

Write-Output '=== B. player honours the setting ==='
Check 'B1' $media 'getLockScreenPlay\(\)' 'background task reads the setting'
Check 'B2' $media 'public applyLockScreenPlay\(enabled: boolean\)' 'immediate apply entry exists'
Check 'B3' $media 'stopContinuousTask' 'continuous task can be stopped'
Check 'B4' $media 'startContinuousTask' 'continuous task is started on play paths'

Write-Output '=== C. playback settings row ==='
Check 'C1' $page '@Local lockScreenPlay: boolean = true' 'local state defaults to ON'
Check 'C2' $page 'this\.lockScreenPlay = MusicStoreService\.getInstance\(\)\.getLockScreenPlay\(\)' 'reads persisted value on appear'
Check 'C3' $page 'setting_sub_lock_screen_play' 'row title uses the new string resource'
Check 'C4' $page 'applyLockScreenPlay\(isOn\)' 'toggle applies immediately'
Check 'C5' $page 'setLockScreenPlay\(isOn\)' 'toggle is persisted'
Check 'C6' 'features\setting\src\main\resources\base\element\string.json' 'setting_sub_lock_screen_play' 'string resource declared'

Write-Output '=== D. platform prerequisites (already present) ==='
Check 'D1' 'products\default\src\main\module.json5' '"audioPlayback"' 'backgroundModes audioPlayback'
Check 'D2' 'products\default\src\main\module.json5' 'KEEP_BACKGROUND_RUNNING' 'KEEP_BACKGROUND_RUNNING permission'
Check 'D3' 'products\default\src\main\ets\entryability\EntryAbility.ets' 'onApplicationBackground\(\)' 'ability background hook wired'

Write-Output ''
if ($fail -eq 0) {
  Write-Output 'STATIC CHECK OK. Still device-only: audio keeps playing after screen lock; lock-screen media card shows.'
} else {
  Write-Output "STATIC CHECK FAILED: $fail assertion(s)."
  exit 1
}
