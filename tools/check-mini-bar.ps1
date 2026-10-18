# ============================================================================
# Static self-check for the level-1 mini bar (goal-a29f6835).
#
# Usage (from the RzdMusic root):
#     powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\check-mini-bar.ps1
#
# ASCII-only on purpose: Windows PowerShell 5.1 reads .ps1 as ANSI, so any
# non-ASCII text here would be mangled and break parsing.
#
# What is NOT covered (device-only): whether the immersive material actually
# renders for the nested HdsTabs, whether the whole bar squashes on close,
# and whether only one bar is on screen.
# ============================================================================

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$idx = Join-Path $root 'products\default\src\main\ets\pages\Index.ets'
$cap = Join-Path $root 'features\playlist\src\main\ets\view\MiniBarMaterialCapsule.ets'
$bar = Join-Path $root 'features\playlist\src\main\ets\view\HomeMiniBarPlayer.ets'
$aside = Join-Path $root 'features\playlist\src\main\ets\view\HomeMiniBarPlayerAside.ets'
$state = Join-Path $root 'common\musicbasic\src\main\ets\model\PlayerExpandState.ets'
$helper = Join-Path $root 'common\musicbasic\src\main\ets\util\BarScrollHelper.ets'
$collapse = Join-Path $root 'common\musicbasic\src\main\ets\logic\BarCollapse.ets'

$script:fail = 0
function Chk([string] $name, [string] $file, [string] $needle) {
  if (-not (Test-Path $file)) { Write-Output ("[FAIL] missing file: " + $file); $script:fail++; return }
  $ok = Select-String -Path $file -Pattern $needle -SimpleMatch -Quiet
  if ($ok) { Write-Output ("[PASS] " + $name) } else { Write-Output ("[FAIL] " + $name); $script:fail++ }
}

Write-Output '=== A. host structure: level-1 owns an HdsTabs capsule (material + squash same layer) ==='
Chk 'A1 level-1 uses MiniBarMaterialCapsule as host' $idx 'MiniBarMaterialCapsule({'
Chk 'A2 outer HDS cell draws no plate (upstream NoBg)' $idx 'enableMiniBarBackground: false,'
Chk 'A3 content draws no plate (material comes from inner HdsTabs)' $idx 'showSelfDrawnBackplate: false,'
Chk 'A4 squash owned by capsule layer (the one with material)' $idx 'contentOwnsSquash: false,'
Chk 'A5 material level from app setting (ambientTitleMaterial -> buildTitleMaterial)' $idx 'material: this.ambientTitleMaterial(),'
Chk 'A6 capsule height uses upstream estimate branch (56 / 40)' $idx 'private homeMiniBarSlotHVp(): number {'
Chk 'A7 capsule width = min(measured slot, floating bar width)' $idx 'return Math.min(this.homeMiniBarSlotWVpRaw, want);'
Chk 'A8 diag log printed when slot width is measured' $idx 'plate=inner-hds-tabs slotW='

Write-Output '=== B. capsule container: official 3 conditions + material + squash ==='
Chk 'B1 barPosition(BarPosition.End)' $cap '.barPosition(BarPosition.End)'
Chk 'B2 barOverlap(true)' $cap '.barOverlap(true)'
Chk 'B3 vertical(false)' $cap '.vertical(false)'
Chk 'B4 systemMaterialEffect: this.material' $cap 'systemMaterialEffect: this.material,'
Chk 'B5 squash on capsule root Stack' $cap '.scale({ x: 1, y: this.expandState.morphSquashY })'

Write-Output '=== C. hide real bar during morph (upstream miniOut per-frame invariant) ==='
Chk 'C1 syncMiniOut() exists' $state 'public syncMiniOut(): void {'
Chk 'C2 called at end of per-frame geometry' $state 'this.syncMiniOut();'
Chk 'C3 all visibility gates include miniOut' $idx 'this.expandState.miniOut'

Write-Output '=== D. action cluster is a direct child of the capsule Row (upstream :69451-69474) ==='
Chk 'D1 HomeMiniBarPlayer renders MiniBarActions' $bar 'MiniBarActions({'
Chk 'D2 Aside supports meta-only mode' $aside '@Param actionsOutside: boolean = false;'

Write-Output '=== E. bottom bar expand/collapse (BarCollapse port + upstream mapping and sign) ==='
Chk 'E1 threshold 1.5 (wujie.pa:84165)' $collapse 'public static readonly THRESHOLD: number = 1.5;'
Chk 'E2 throttle 250 (wujie.pa:84077)' $collapse 'public static readonly THROTTLE_MS: number = 250;'
Chk 'E3 action -> intent uses upstream reverse mapping (:145779)' $helper 'const expand: boolean = action === BarAction.COLLAPSE;'
Chk 'E4 scroll y sign follows upstream (:83990)' $helper 'BarScrollHelper.virtualY - delta;'

Write-Output ''
if ($script:fail -eq 0) {
  Write-Output 'STATIC CHECK OK. Still device-only: material visible / whole bar squashes on close / only one bar.'
  exit 0
} else {
  Write-Output ("STATIC CHECK FAILED: " + $script:fail + " item(s).")
  exit 1
}
