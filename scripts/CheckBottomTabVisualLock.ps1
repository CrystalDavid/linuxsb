$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$targetPath = Join-Path $projectRoot 'entry\src\main\ets\views\components\ImmersiveBottomTabBar.ets'
$expectedSha256 = 'C21D5B4C60E83415B2160EC0131D8A32917AD59091F283C27ED52D0FE3D101FE'
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
