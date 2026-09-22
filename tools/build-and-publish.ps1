<#
.SYNOPSIS
  构建 RzdMusic（default + pc）→ 上传签名 HAP 到 WebDAV → 发推送通知（含下载直链）。

.DESCRIPTION
  一条命令走完：编译 → 找产物 → WebDAV PUT → 推送。
  推送正文里的下载直链做了「双重编码」，否则会 400（见下方说明）。

.PARAMETER Products
  要构建的 product 列表，默认 default + pc。

.PARAMETER SkipBuild
  跳过编译，只上传已有产物。

.PARAMETER SkipNotify
  只构建 + 上传，不发推送。

.PARAMETER DryRun
  只打印将要执行的动作，不真正上传/推送。

.PARAMETER RemoteSuffix
  远端文件名后缀（插在 -signed.hap 之前）。默认空 = 覆盖正式产物
  `RzdMusic-<product>-signed.hap`；用 -RemoteSuffix -pr1 可以让旁支构建
  （例如上游 PR 预览）不覆盖正在用的安装包。

.EXAMPLE
  pwsh -File tools/build-and-publish.ps1
  pwsh -File tools/build-and-publish.ps1 -Products default -SkipNotify
#>
[CmdletBinding()]
param(
  [string[]]$Products = @('default', 'pc'),
  [switch]$SkipBuild,
  [switch]$SkipNotify,
  [switch]$DryRun,
  [string]$RemoteSuffix = ''
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

# 说明：这里**故意**不用 'Stop'。脚本大量调用原生命令（hvigorw / curl.exe），
# PowerShell 5.1 只要在原生命令的 stderr 上看到任何一行输出就抛 NativeCommandError，
# 而 hvigor 会把 WARN（如「no executable target in module」）写到 stderr ——
# 用 'Stop' 会出现「构建其实成功了，脚本却报失败」的假故障。
# 所有失败路径都由 try/catch、显式 throw 和 $LASTEXITCODE 判断兜住。

# ---------------------------------------------------------------------------
# 配置（可用环境变量覆盖，避免把口令硬编码进仓库）
# ---------------------------------------------------------------------------
$RepoRoot   = if ($env:RZD_REPO_ROOT) { $env:RZD_REPO_ROOT } else { Split-Path -Parent $PSScriptRoot }
$DavBase    = if ($env:RZD_DAV_BASE) { $env:RZD_DAV_BASE } else { 'https://pan.rzdpai.com/dav/' }
$DavUser    = if ($env:RZD_DAV_USER) { $env:RZD_DAV_USER } else { '3420176748@qq.com' }
$DavPass    = if ($env:RZD_DAV_PASS) { $env:RZD_DAV_PASS } else { 'fsj1stu3t0z3tdx4x7yjxjb8qxm1o62n' }
$PushBase   = if ($env:RZD_PUSH_BASE) { $env:RZD_PUSH_BASE } else { 'https://api.chuckfang.com/RzdPai' }

$DevecoSdk     = if ($env:DEVECO_SDK_HOME) { $env:DEVECO_SDK_HOME } else { 'D:\command-line-tools\sdk' }
$HvigorUserHome = if ($env:HVIGOR_USER_HOME) { $env:HVIGOR_USER_HOME } else { (Join-Path $RepoRoot '..\.buildcache\hvigor') }
$NpmCache      = if ($env:npm_config_cache) { $env:npm_config_cache } else { (Join-Path $RepoRoot '..\.buildcache\npm') }
$JdkHome       = if ($env:RZD_JDK_HOME) { $env:RZD_JDK_HOME } else { 'C:\Users\Administrator\Tools\jdk\jdk-17.0.2' }
$Hvigorw       = if ($env:RZD_HVIGORW) { $env:RZD_HVIGORW } else { 'D:\command-line-tools\bin\hvigorw.bat' }

$Stamp = Get-Date -Format 'yyyyMMdd-HHmm'

function Write-Step([string]$msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "  [OK]   $msg" -ForegroundColor Green }
function Write-Warn2([string]$msg){ Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err2([string]$msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 推送
#
# 通知服务是「路径段」形式： /<用户>/<标题>/<正文>，标题与正文都要 URL 编码。
# 正文里【不要】放下载直链：链接含 '/' 和 '?'，普通 EscapeDataString 之后服务端
# 会把 %2F 当路径分隔符，Tomcat 直接 400 Bad Request（必须再把 %2F 编成 %252F
# 才能发出去）。现在通知只报「构建完成」，所以这条坑已经不需要了。
# 另注意：该服务限流 3 秒 1 条（非会员）。
# ---------------------------------------------------------------------------
function ConvertTo-PushSegment([string]$text) {
  return [uri]::EscapeDataString($text)
}

function Send-Push([string]$Title, [string]$Body) {
  $url = "$PushBase/$(ConvertTo-PushSegment $Title)/$(ConvertTo-PushSegment $Body)"
  if ($DryRun) { Write-Host "  [dry-run] push: $Title | $Body"; return $true }
  try {
    $resp = & curl.exe -sS -m 30 $url 2>&1 | Out-String
    if ($resp -match '"data":true') { Write-Ok "推送成功: $Title"; return $true }
    Write-Warn2 "推送返回: $($resp.Trim())"
    return $false
  } catch {
    Write-Err2 "推送异常: $($_.Exception.Message)"
    return $false
  }
}

# ---------------------------------------------------------------------------
# 环境准备
# ---------------------------------------------------------------------------
function Initialize-BuildEnv {
  $env:DEVECO_SDK_HOME    = $DevecoSdk
  $env:HVIGOR_USER_HOME   = $HvigorUserHome
  $env:npm_config_cache   = $NpmCache
  if (Test-Path $JdkHome) {
    $env:JAVA_HOME = $JdkHome
    $env:PATH      = "$JdkHome\bin;$env:PATH"
  } else {
    Write-Warn2 "未找到 JDK: $JdkHome（assembleHap 打包阶段需要 java，可能失败）"
  }
  New-Item -ItemType Directory -Force -Path $HvigorUserHome, $NpmCache | Out-Null
}

function Invoke-Build([string]$Product) {
  Write-Step "构建 product=$Product"
  $log = Join-Path $env:TEMP "rzdmusic-build-$Product.log"
  # ⚠️ hvigor 会把 WARN 写到 stderr（例如「Current product is 'default'... no executable
  # target in module: 'musichomepcsample'」）。PowerShell 5.1 只要在原生命令的 stderr 上
  # 看到任何一行，就抛 NativeCommandError；而脚本顶部是 $ErrorActionPreference = 'Stop'，
  # 于是**构建成功也会被当成失败**退出。这里临时切回 Continue，成败只认退出码。
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Hvigorw assembleHap --mode module -p "product=$Product" -p buildMode=debug --no-daemon *> $log
    $code = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEap
  }
  if ($code -ne 0) {
    Get-Content $log -Encoding UTF8 |
      Select-String -Pattern 'Error Message|COMPILE RESULT|BUILD FAILED|ERROR' |
      Select-Object -First 25 | ForEach-Object { Write-Host "    $($_.Line.Trim())" }
    throw "构建失败 product=$Product (exit=$code)，完整日志: $log"
  }
  Write-Ok "BUILD SUCCESSFUL (product=$Product)"
  Write-Host "    日志: $log"
}

# ---------------------------------------------------------------------------
# 产物收集
# ---------------------------------------------------------------------------
function Get-SignedHaps([string]$Product) {
  $dir = Join-Path $RepoRoot "products\$Product\build"
  if (-not (Test-Path $dir)) { return @() }
  return @(Get-ChildItem -Path $dir -Recurse -File -Filter '*-signed.hap' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1)
}

# ---------------------------------------------------------------------------
# WebDAV
# ---------------------------------------------------------------------------
function Get-DavCredentialHeader {
  $cred = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("${DavUser}:${DavPass}"))
  return @{ Authorization = "Basic $cred" }
}

# 远端资源是否已存在（PROPFIND Depth:0，207 = 存在）。
function Test-DavExists([string]$RemoteName) {
  $seg = [uri]::EscapeDataString($RemoteName)
  $args = @('-sS', '-o', 'NUL', '-w', '%{http_code}', '-X', 'PROPFIND',
    '-H', 'Depth: 0', '-u', "${DavUser}:${DavPass}", ($DavBase + $seg))
  $code = (& curl.exe @args 2>&1 | Out-String).Trim()
  if ($code -eq '207' -or $code -eq '200') { return $true }
  if ($code -eq '404') { return $false }
  throw "PROPFIND 返回 $code（预期 207/404），无法确定远端是否存在 $RemoteName"
}

# 删除远端同名文件（204/200 = 成功，404 = 本来就不存在）。
function Remove-DavFile([string]$RemoteName) {
  if ($DryRun) { Write-Host "  [dry-run] DELETE $RemoteName"; return $true }
  $seg = [uri]::EscapeDataString($RemoteName)
  $args = @('-sS', '-o', 'NUL', '-w', '%{http_code}', '-X', 'DELETE',
    '-u', "${DavUser}:${DavPass}", ($DavBase + $seg))
  $code = (& curl.exe @args 2>&1 | Out-String).Trim()
  if ($code -eq '204' -or $code -eq '200' -or $code -eq '404') {
    Write-Ok "已删除同名文件 $RemoteName (http=$code)"
    return $true
  }
  Write-Err2 "删除失败 $RemoteName (http=$code)"
  return $false
}

# 上传前先清掉同名文件（要求：有同名先删）。
# PUT 本身是覆盖语义，但显式 DELETE 可以避免旧对象残留在部分 WebDAV 网盘上
# 造成配额/列表不刷新。
function Send-DavFile([string]$LocalPath, [string]$RemoteName) {
  $size = (Get-Item $LocalPath).Length
  if ($DryRun) {
    Write-Host "  [dry-run] 检查同名 -> DELETE(如存在) -> PUT $RemoteName ($size bytes)"
    return $true
  }
  try {
    if (Test-DavExists $RemoteName) {
      if (-not (Remove-DavFile $RemoteName)) { return $false }
    } else {
      Write-Host "  远端无同名文件"
    }
  } catch {
    Write-Warn2 $_.Exception.Message
    # 无法确认时不阻断上传：PUT 至少是覆盖语义
  }

  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    Invoke-WebRequest -Uri ($DavBase + [uri]::EscapeDataString($RemoteName)) -Method Put `
      -InFile $LocalPath -Headers (Get-DavCredentialHeader) -TimeoutSec 1800 -UseBasicParsing | Out-Null
    $sw.Stop()
    Write-Ok ("上传 {0}  {1:N0} bytes  {2:N1}s" -f $RemoteName, $size, $sw.Elapsed.TotalSeconds)
    return $true
  } catch {
    $sw.Stop()
    $status = ''
    if ($_.Exception.Response) { $status = " HTTP $([int]$_.Exception.Response.StatusCode)" }
    Write-Err2 "上传失败 $RemoteName$status : $($_.Exception.Message)"
    return $false
  }
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
$published = @()   # @{ name=; size= }

if (-not $SkipBuild) { Initialize-BuildEnv }

foreach ($product in $Products) {
  if (-not $SkipBuild) { Invoke-Build $product }

  # 注意：必须 @() 包一层。PowerShell 会把「空结果」解包成 $null、「单元素」解包成
  # 裸对象，两种情况都没有 .Count（Set-StrictMode 下会直接抛错）。
  $haps = @(Get-SignedHaps $product)
  if ($haps.Count -eq 0) {
    Write-Warn2 "product=$product 没找到 *-signed.hap，跳过"
    continue
  }

  $hap = $haps[0]
  # 远端固定名，便于覆盖更新；中文/空格会按 URL 段编码
  # RemoteSuffix 用于旁支构建（例如上游 PR 预览），避免覆盖正在使用的正式包
  $remote = "RzdMusic-$product$RemoteSuffix-signed.hap"
  Write-Step "上传 product=$product"
  Write-Host "  本地: $($hap.FullName)"
  Write-Host "  远端: $DavBase$remote"

  if (Send-DavFile $hap.FullName $remote) {
    $published += [pscustomobject]@{ name = $remote; size = $hap.Length }
  }
}

if ($published.Count -eq 0) {
  Write-Err2 '没有成功上传任何产物'
  if (-not $SkipNotify) { Send-Push 'RzdMusic 构建失败' '构建或上传未成功，请查看本地日志' | Out-Null }
  exit 1
}

Write-Step '上传结果'
$published | ForEach-Object { Write-Host ("  {0}  ({1:N1} MB)" -f $_.name, ($_.size / 1MB)) }

if (-not $SkipNotify) {
  Write-Step '发送推送'
  $totalMb = [Math]::Round((($published | Measure-Object -Property size -Sum).Sum / 1MB), 1)
  $names = ($published | ForEach-Object { $_.name }) -join '、'
  Send-Push 'RzdMusic 构建完成' "已上传：$names`n合计 $totalMb MB" | Out-Null
}

Write-Host ''
Write-Ok "全部完成（$Stamp）"
