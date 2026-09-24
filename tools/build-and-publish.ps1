<#
.SYNOPSIS
  构建 RzdMusic（默认只构建 default）→ 上传签名 HAP 到 WebDAV → 发推送通知（含下载直链）。

.DESCRIPTION
  一条命令走完：编译 → 找产物 → WebDAV PUT → 推送。
  推送正文里的下载直链做了「双重编码」，否则会 400（见下方说明）。

  默认**只构建 default（手机/平板）**；pc 版按需显式传 -Products pc 才会构建
  （2026-09-24 起：以后不用构建/上传 pc 版）。

.PARAMETER Products
  要构建的 product 列表，默认只有 default。

.PARAMETER Release
  正式上架包：改用 assembleApp + buildMode=release，产物是 App Pack（*.app，给 AGC 提审用），
  远端名 RzdMusic-<product>.app。不加这个开关就是日常自测用的 debug HAP。

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
  pwsh -File tools/build-and-publish.ps1 -Release
  pwsh -File tools/build-and-publish.ps1 -Products default -SkipNotify
#>
[CmdletBinding()]
param(
  [string[]]$Products = @('default'),
  [switch]$Release,
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
  # -Release：正式上架包 = assembleApp + buildMode=release（产出 App Pack，给 AGC 提审）
  # 不加：日常自测包 = assembleHap + buildMode=debug（可直接 hdc install 的签名 HAP）
  #
  # ⚠️ mode 必须跟着任务换：`assembleApp` 是**工程级**任务，用 `--mode module` 会报
  #    「00306054 Specification Limit Violation: Task ['assembleApp'] was not found in
  #     the project」；module 级任务（assembleHap）反过来要用 `--mode module`。
  $task = if ($Release) { 'assembleApp' } else { 'assembleHap' }
  $mode = if ($Release) { 'release' } else { 'debug' }
  $scope = if ($Release) { 'project' } else { 'module' }
  Write-Step "构建 product=$Product（$task / $mode）"
  $log = Join-Path $env:TEMP "rzdmusic-build-$Product-$mode.log"
  # ⚠️ hvigor 会把 WARN 写到 stderr（例如「Current product is 'default'... no executable
  # target in module: 'musichomepcsample'」）。PowerShell 5.1 只要在原生命令的 stderr 上
  # 看到任何一行，就抛 NativeCommandError；而脚本顶部是 $ErrorActionPreference = 'Stop'，
  # 于是**构建成功也会被当成失败**退出。这里临时切回 Continue，成败只认退出码。
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $Hvigorw $task --mode $scope -p "product=$Product" -p "buildMode=$mode" --no-daemon *> $log
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

# App Pack（*.app，上架用）：assembleApp 的产物在**工程根目录**的
# `build/outputs/<product>/`（不是 products/<product>/build/... —— 这点和 HAP 不一样，
# 找错了会「构建成功却报没找到产物」）。顺手把 module 目录也扫一遍当兜底。
function Get-AppPacks([string]$Product) {
  $roots = @(
    (Join-Path $RepoRoot "build\outputs\$Product"),
    (Join-Path $RepoRoot "products\$Product\build")
  )
  foreach ($dir in $roots) {
    if (-not (Test-Path $dir)) { continue }
    # 优先签名包（AGC 提审要签名的那个），没有就退回未签名的
    $hit = @(Get-ChildItem -Path $dir -Recurse -File -Filter '*-signed.app' |
      Sort-Object LastWriteTime -Descending)
    if ($hit.Count -eq 0) {
      $hit = @(Get-ChildItem -Path $dir -Recurse -File -Filter '*.app' |
        Sort-Object LastWriteTime -Descending)
    }
    if ($hit.Count -gt 0) { return @($hit[0]) }
  }
  return @()
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
  # ⚠️ PUT 必须重试：上面的 DELETE 已经把旧包删掉了，此时 PUT 失败 = **远端一个包都没有**
  #    （2026-09-23 的 pc 包就踩过：上传过程连接被重置，远端直接 404，
  #     而脚本当时还报了「全部完成」并推了「构建完成」——那是假消息，已一并修掉）。
  $attempts = 3
  for ($attempt = 1; $attempt -le $attempts; $attempt++) {
    try {
      Invoke-WebRequest -Uri ($DavBase + [uri]::EscapeDataString($RemoteName)) -Method Put `
        -InFile $LocalPath -Headers (Get-DavCredentialHeader) -TimeoutSec 1800 -UseBasicParsing | Out-Null
      $sw.Stop()
      Write-Ok ("上传 {0}  {1:N0} bytes  {2:N1}s" -f $RemoteName, $size, $sw.Elapsed.TotalSeconds)
      return $true
    } catch {
      $status = ''
      if ($_.Exception.Response) { $status = " HTTP $([int]$_.Exception.Response.StatusCode)" }
      if ($attempt -lt $attempts) {
        Write-Warn2 "上传失败（第 $attempt/$attempts 次）$RemoteName$status，稍后重试…"
        Start-Sleep -Seconds (2 * $attempt)
      } else {
        $sw.Stop()
        Write-Err2 "上传失败 $RemoteName$status : $($_.Exception.Message)"
        return $false
      }
    }
  }
  return $false
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
$published = @()   # @{ name=; size= }
$failed = @()      # 上传失败的远端名（重试过仍失败）

if (-not $SkipBuild) { Initialize-BuildEnv }

foreach ($product in $Products) {
  if (-not $SkipBuild) { Invoke-Build $product }

  # 注意：必须 @() 包一层。PowerShell 会把「空结果」解包成 $null、「单元素」解包成
  # 裸对象，两种情况都没有 .Count（Set-StrictMode 下会直接抛错）。
  $arts = @(if ($Release) { Get-AppPacks $product } else { Get-SignedHaps $product })
  if ($arts.Count -eq 0) {
    $what = if ($Release) { '*.app' } else { '*-signed.hap' }
    Write-Warn2 "product=$product 没找到 $what，跳过"
    continue
  }

  $art = $arts[0]
  # 远端固定名，便于覆盖更新；中文/空格会按 URL 段编码
  # RemoteSuffix 用于旁支构建（例如上游 PR 预览），避免覆盖正在使用的正式包
  $suffix = if ($Release) { '.app' } else { '-signed.hap' }
  $remote = "RzdMusic-$product$RemoteSuffix$suffix"
  Write-Step "上传 product=$product"
  Write-Host "  本地: $($art.FullName)"
  Write-Host "  远端: $DavBase$remote"

  if (Send-DavFile $art.FullName $remote) {
    $published += [pscustomobject]@{ name = $remote; size = $art.Length }
  } else {
    $failed += $remote
  }
}

if ($published.Count -eq 0) {
  Write-Err2 '没有成功上传任何产物'
  if (-not $SkipNotify) { Send-Push 'RzdMusic 构建失败' '构建或上传未成功，请查看本地日志' | Out-Null }
  exit 1
}

Write-Step '上传结果'
$published | ForEach-Object { Write-Host ("  {0}  ({1:N1} MB)" -f $_.name, ($_.size / 1MB)) }

# 有产物没传上去就不能报「全部完成」：远端此刻可能是**空的**（旧包已被 DELETE），
# 推送也必须说实话，否则用户会以为能装最新包。
if ($failed.Count -gt 0) {
  Write-Err2 ("以下产物上传失败: {0}" -f ($failed -join '、'))
  if (-not $SkipNotify) {
    $okNames = ($published | ForEach-Object { $_.name }) -join '、'
    Send-Push 'RzdMusic 部分产物上传失败' "失败：$($failed -join '、')`n已成功：$okNames" | Out-Null
  }
  exit 1
}

if (-not $SkipNotify) {
  Write-Step '发送推送'
  $totalMb = [Math]::Round((($published | Measure-Object -Property size -Sum).Sum / 1MB), 1)
  $names = ($published | ForEach-Object { $_.name }) -join '、'
  Send-Push 'RzdMusic 构建完成' "已上传：$names`n合计 $totalMb MB" | Out-Null
}

Write-Host ''
Write-Ok "全部完成（$Stamp）"
