# Run an elm front-end operation on every sample under samples/.
#
# Usage:
#   pwsh -File scripts/run_samples.ps1 -Operation tokenize
#
# Results are written under .results/<operation>/. Exit 0 if every sample
# succeeds, otherwise 1.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("tokenize")]
    [string] $Operation
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$SamplesDir = Join-Path $Root "samples"
$ResultsDir = Join-Path $Root ".results" $Operation
$Elm = Join-Path $Root "bin" "elm"

if (-not (Test-Path -LiteralPath $Elm)) {
    Write-Error "elm executable not found at '$Elm'. Run 'alr build' first."
    exit 1
}

if (-not (Test-Path -LiteralPath $SamplesDir)) {
    Write-Error "samples directory not found at '$SamplesDir'."
    exit 1
}

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

$Samples = @(Get-ChildItem -LiteralPath $SamplesDir -Filter "*.telm" | Sort-Object Name)
if ($Samples.Count -eq 0) {
    Write-Error "no .telm samples found in '$SamplesDir'."
    exit 1
}

$Failed = 0

foreach ($Sample in $Samples) {
    $OutName = [System.IO.Path]::ChangeExtension($Sample.Name, ".tokens")
    $OutPath = Join-Path $ResultsDir $OutName
    Write-Host "tokenize $($Sample.Name) -> .results/$Operation/$OutName"

    & $Elm --no-logo --no-color tokenize -i $Sample.FullName -o $OutPath
    $Code = $LASTEXITCODE
    if ($Code -ne 0) {
        Write-Host "FAIL: $($Sample.Name) (exit $Code)"
        $Failed = 1
    }
}

if ($Failed -ne 0) {
    Write-Host "run_samples: FAILED"
    exit 1
}

Write-Host "run_samples: OK ($($Samples.Count) samples)"
exit 0
