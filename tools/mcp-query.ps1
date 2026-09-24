# Huawei Developer Knowledge MCP client (ASCII only on purpose: PowerShell 5.1 reads
# .ps1 without BOM as ANSI, and non-ASCII here would break parsing).
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\mcp-query.ps1 -Query "bindSheet reopen"
#   powershell ... -File tools\mcp-query.ps1 -Tool getDocumentsById -Ids "document/cn/..."
#   powershell ... -File tools\mcp-query.ps1 -Tool tools/list -NoArgs
#   powershell ... -File tools\mcp-query.ps1 -Query "..." -Brief -Top 3
#
# Protocol notes (learned the hard way):
#   * JSON-RPC over HTTP POST, responses come back as SSE frames ("data: {...}");
#   * initialize -> take Mcp-Session-Id from the response headers, echo it on later calls;
#   * notifications/initialized must be sent once before tools/call, else the server errors.
param(
  [string]$Query = '',
  [string]$Tool = 'searchDocuments',
  [string]$Ids = '',
  [string]$ArgsJson = '',
  [int]$Top = 5,
  [switch]$Brief,
  [switch]$NoArgs,
  [switch]$ListTools,
  [switch]$Raw
)

$ErrorActionPreference = 'Continue'
$base = 'https://connect-api.cloud.huawei.com/api/developerknowledge/mcp'
$hdr = @{
  'Accept'       = 'application/json, text/event-stream'
  'Content-Type' = 'application/json'
}

function Invoke-Mcp {
  param([string]$Body, [hashtable]$Extra)
  $h = @{}
  foreach ($k in $hdr.Keys) { $h[$k] = $hdr[$k] }
  if ($Extra) { foreach ($k in $Extra.Keys) { $h[$k] = $Extra[$k] } }
  $resp = Invoke-WebRequest -Uri $base -Method Post -Body $Body -Headers $h -TimeoutSec 180 -UseBasicParsing
  $text = $resp.Content
  if ($text -is [byte[]]) { $text = [System.Text.Encoding]::UTF8.GetString($text) }
  $sid = $null
  foreach ($k in $resp.Headers.Keys) { if ($k -ieq 'Mcp-Session-Id') { $sid = $resp.Headers[$k] } }
  if ($sid -is [array]) { $sid = $sid[0] }
  return @{ Text = $text; Sid = $sid }
}

function Get-SsePayload {
  param([string]$Text)
  $out = @()
  foreach ($line in ($Text -split "`n")) {
    $l = $line.Trim()
    if ($l.StartsWith('data:')) { $out += $l.Substring(5).Trim() }
  }
  if ($out.Count -eq 0 -and $Text.Trim().StartsWith('{')) { $out += $Text.Trim() }
  return $out
}

$init = Invoke-Mcp -Body '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"rzdmusic-doc","version":"1.0.0"}}}'
if (-not $init.Sid) { Write-Host '[MCP] no Mcp-Session-Id header:'; Write-Host $init.Text; exit 1 }
$sid = @{ 'Mcp-Session-Id' = $init.Sid }
$null = Invoke-Mcp -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' -Extra $sid

if ($ListTools) {
  $r = Invoke-Mcp -Body '{"jsonrpc":"2.0","id":9,"method":"tools/list"}' -Extra $sid
  Write-Host $r.Text
  exit 0
}

if ($ArgsJson.Length -gt 0) {
  $argsObj = $ArgsJson
} elseif ($NoArgs) {
  $argsObj = '{}'
} elseif ($Tool -eq 'getDocumentsById') {
  $idList = @()
  foreach ($one in ($Ids -split ',')) { if ($one.Trim().Length -gt 0) { $idList += $one.Trim() } }
  # Schema: { GetDocumentsByIdRequest: { names: string[] } }
  $argsObj = (@{ GetDocumentsByIdRequest = @{ names = $idList } } | ConvertTo-Json -Depth 8 -Compress)
} else {
  $argsObj = (@{ SearchDocumentsReq = @{ query = $Query; top = $Top } } | ConvertTo-Json -Depth 8 -Compress)
}

$req = (@{ jsonrpc = '2.0'; id = 2; method = 'tools/call'; params = @{ name = $Tool; arguments = ($argsObj | ConvertFrom-Json) } } | ConvertTo-Json -Depth 14 -Compress)
$call = Invoke-Mcp -Body $req -Extra $sid

if ($Raw) { Write-Host $call.Text; exit 0 }

foreach ($p in (Get-SsePayload $call.Text)) {
  try { $obj = $p | ConvertFrom-Json } catch { Write-Host "[MCP] raw: $p"; continue }
  $content = $obj.result.content
  if (-not $content) { Write-Host $p; continue }
  foreach ($c in $content) {
    if (-not $c.text) { continue }
    if (-not $Brief) { Write-Host $c.text; continue }
    # Brief: searchDocuments returns {resultList:[{parent,content}]}; print only row summaries
    try {
      $inner = $c.text | ConvertFrom-Json
      $i = 0
      foreach ($row in $inner.resultList) {
        $i++
        $body = $row.content
        if ($body.Length -gt 700) { $body = $body.Substring(0, 700) + ' ...' }
        Write-Host ("[{0}] {1}" -f $i, $row.parent)
        Write-Host ("    {0}" -f $body)
      }
      if ($i -eq 0) { Write-Host $c.text }
    } catch {
      Write-Host $c.text
    }
  }
}
