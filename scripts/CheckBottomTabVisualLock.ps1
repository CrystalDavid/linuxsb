$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $projectRoot 'entry\src\main\ets\views\components\ImmersiveBottomTabBar.ets'
$expectedSha256 = 'BD8B9E19E34DB24694961379BF5F5E3286987AA8BBE96319006164BDFAB5E0C0'
$source = [System.IO.File]::ReadAllText($targetPath).Replace("`r`n", "`n")
$bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($source)
$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
  $actualSha256 = ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '')
} finally {
  $sha256.Dispose()
}

if ($actualSha256 -ne $expectedSha256) {
  throw "Bottom tab visual lock failed. Expected $expectedSha256 but found $actualSha256. Do not change the tab design without explicit user approval."
}

Write-Output "BottomTabVisualLock PASS $actualSha256"
