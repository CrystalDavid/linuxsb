[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'entry\src\main\ets'
$loginRoot = (Join-Path $sourceRoot 'services\auth')
$officialLoginPage = (Join-Path $loginRoot 'OfficialLoginPage.ets')

$violations = [System.Collections.Generic.List[string]]::new()
$sourceFiles = Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.ets'

foreach ($file in $sourceFiles) {
  $fullPath = $file.FullName
  $relativePath = $fullPath.Substring($projectRoot.Length)
  while ($relativePath.StartsWith('\') -or $relativePath.StartsWith('/')) {
    $relativePath = $relativePath.Substring(1)
  }
  $lines = Get-Content -LiteralPath $fullPath

  for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
    $line = $lines[$lineIndex]
    $lineNumber = $lineIndex + 1

    if ($line -match '@ohos\.web' -or $line -match '\bWebComponent\b') {
      $violations.Add("$relativePath`:$lineNumber forbidden legacy Web API")
    }

    if ($line -match '@kit\.ArkWeb' -and
        -not $fullPath.StartsWith($loginRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      $violations.Add("$relativePath`:$lineNumber ArkWeb import outside services/auth")
    }

    if ($line -match '\bWeb\s*\(' -and
        -not $fullPath.Equals($officialLoginPage, [System.StringComparison]::OrdinalIgnoreCase)) {
      $violations.Add("$relativePath`:$lineNumber Web node outside OfficialLoginPage")
    }
  }
}

if ($violations.Count -gt 0) {
  $violations | ForEach-Object { Write-Error $_ }
  throw "NoWebOutsideLogin FAIL: $($violations.Count) violation(s)."
}

Write-Output "NoWebOutsideLogin PASS: ArkWeb imports are confined to services/auth and Web nodes to OfficialLoginPage."
