# Run eml front-end operation(s) on every sample under samples/.
#
# Usage:
#   pwsh -File scripts/run_samples.ps1
#   pwsh -File scripts/run_samples.ps1 -Operations tokenize
#   pwsh -File scripts/run_samples.ps1 -Operations tokenize,parse,preproc
#   pwsh -File scripts/run_samples.ps1 --operations tokenize parse
#
# -Operations / --operations: one or more of preproc, tokenize, parse.
# If omitted (or empty), all operations are run.
#
# Results are written under .results/<operation>/. Exit 0 if every sample
# succeeds for every requested operation, otherwise 1.
#
# For parse, each sample is written in all four formats:
#   .syntaxtree (mermaid), .md, .dot, .svg

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [Alias("Operation")]
    [string[]] $Operations = @(),

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $RemainingArguments = @()
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $PSScriptRoot
$SamplesDir = Join-Path $Root "samples"
$Eml = Join-Path $Root "bin" "eml"
$AllOperations = @("preproc", "tokenize", "parse")

# Dummy bindings for parameterized samples; --warn none suppresses unused warnings.
$SampleVarArgs = @(
    "-v", '$X=1',
    "-v", '$A=1',
    "-v", '$B=1',
    "-v", '$R=1',
    "-v", '$M=1',
    "-v", '$C=1',
    "-v", '$THETA=1',
    "-w", "none"
)

function Expand-OperationList {
    param([string[]] $Items)

    $Expanded = [System.Collections.Generic.List[string]]::new()
    foreach ($Item in $Items) {
        foreach ($Part in ($Item -split ',')) {
            $Trimmed = $Part.Trim()
            if ($Trimmed.Length -eq 0) {
                continue
            }
            if ($AllOperations -notcontains $Trimmed) {
                Write-Error "unknown operation '$Trimmed' (expected: $($AllOperations -join ', '))."
                exit 1
            }
            if (-not $Expanded.Contains($Trimmed)) {
                [void]$Expanded.Add($Trimmed)
            }
        }
    }
    return ,@($Expanded)
}

# Accept unix-style: --operations tokenize parse  (or tokenize,parse)
$Collected = [System.Collections.Generic.List[string]]::new()
foreach ($Item in $Operations) {
    [void]$Collected.Add($Item)
}

$i = 0
while ($i -lt $RemainingArguments.Count) {
    $Arg = $RemainingArguments[$i]
    if ($Arg -eq "--operations" -or $Arg -eq "-operations") {
        $i++
        if ($i -ge $RemainingArguments.Count) {
            Write-Error "missing value for --operations (expected: $($AllOperations -join ', '))."
            exit 1
        }
        while ($i -lt $RemainingArguments.Count -and $RemainingArguments[$i] -notmatch '^-') {
            [void]$Collected.Add($RemainingArguments[$i])
            $i++
        }
        continue
    }

    if ($Arg -notmatch '^-' -and $Collected.Count -gt 0) {
        [void]$Collected.Add($Arg)
        $i++
        continue
    }

    Write-Error "unexpected argument '$Arg'."
    exit 1
}

if ($Collected.Count -eq 0) {
    $Operations = $AllOperations
}
else {
    $Operations = Expand-OperationList -Items @($Collected)
}

if (-not (Test-Path -LiteralPath $Eml)) {
    Write-Error "eml executable not found at '$Eml'. Run 'alr build' first."
    exit 1
}

if (-not (Test-Path -LiteralPath $SamplesDir)) {
    Write-Error "samples directory not found at '$SamplesDir'."
    exit 1
}

$Samples = @(Get-ChildItem -LiteralPath $SamplesDir -Filter "*.teml" | Sort-Object Name)
if ($Samples.Count -eq 0) {
    Write-Error "no .teml samples found in '$SamplesDir'."
    exit 1
}

$Failed = 0

function Invoke-PreprocSamples {
    param(
        [System.IO.FileInfo[]] $SampleList,
        [string] $ResultsDir
    )

    $LocalFailed = 0
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

    foreach ($Sample in $SampleList) {
        $OutName = $Sample.Name
        $OutPath = Join-Path $ResultsDir $OutName
        Write-Host "preproc $($Sample.Name) -> .results/preproc/$OutName"

        & $script:Eml --no-logo --no-color preproc -i $Sample.FullName @SampleVarArgs -o $OutPath
        $Code = $LASTEXITCODE
        if ($Code -ne 0) {
            Write-Host "FAIL: $($Sample.Name) (exit $Code)"
            $LocalFailed = 1
        }
    }
    return $LocalFailed
}

function Invoke-TokenizeSamples {
    param(
        [System.IO.FileInfo[]] $SampleList,
        [string] $ResultsDir
    )

    $LocalFailed = 0
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

    foreach ($Sample in $SampleList) {
        $OutName = [System.IO.Path]::ChangeExtension($Sample.Name, ".tokens")
        $OutPath = Join-Path $ResultsDir $OutName
        Write-Host "tokenize $($Sample.Name) -> .results/tokenize/$OutName"

        & $script:Eml --no-logo --no-color tokenize -i $Sample.FullName @SampleVarArgs -o $OutPath
        $Code = $LASTEXITCODE
        if ($Code -ne 0) {
            Write-Host "FAIL: $($Sample.Name) (exit $Code)"
            $LocalFailed = 1
        }
    }
    return $LocalFailed
}

function Invoke-ParseAllFormats {
    param(
        [System.IO.FileInfo] $Sample,
        [string] $ResultsDir
    )

    $Base = [System.IO.Path]::GetFileNameWithoutExtension($Sample.Name)
    $Formats = @(
        @{ Of = "mermaid"; Ext = ".syntaxtree" },
        @{ Of = "md"; Ext = ".md" },
        @{ Of = "dot"; Ext = ".dot" },
        @{ Of = "svg"; Ext = ".svg" }
    )

    foreach ($Fmt in $Formats) {
        $OutName = $Base + $Fmt.Ext
        $OutPath = Join-Path $ResultsDir $OutName
        Write-Host "parse $($Sample.Name) -of $($Fmt.Of) -> .results/parse/$OutName"

        & $script:Eml --no-logo --no-color parse -i $Sample.FullName @SampleVarArgs -of $Fmt.Of -o $OutPath
        $Code = $LASTEXITCODE
        if ($Code -ne 0) {
            Write-Host "FAIL: $($Sample.Name) format $($Fmt.Of) (exit $Code)"
            return 1
        }
    }
    return 0
}

function Invoke-ParseSamples {
    param(
        [System.IO.FileInfo[]] $SampleList,
        [string] $ResultsDir
    )

    $LocalFailed = 0
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

    foreach ($Sample in $SampleList) {
        $Code = Invoke-ParseAllFormats -Sample $Sample -ResultsDir $ResultsDir
        if ($Code -ne 0) {
            $LocalFailed = 1
        }
    }
    return $LocalFailed
}

foreach ($Op in $Operations) {
    $ResultsDir = Join-Path $Root ".results" $Op
    Write-Host "=== operation: $Op ==="

    if ($Op -eq "preproc") {
        $Code = Invoke-PreprocSamples -SampleList $Samples -ResultsDir $ResultsDir
    }
    elseif ($Op -eq "tokenize") {
        $Code = Invoke-TokenizeSamples -SampleList $Samples -ResultsDir $ResultsDir
    }
    elseif ($Op -eq "parse") {
        $Code = Invoke-ParseSamples -SampleList $Samples -ResultsDir $ResultsDir
    }
    else {
        Write-Error "unknown operation '$Op'."
        exit 1
    }

    if ($Code -ne 0) {
        $Failed = 1
    }
}

if ($Failed -ne 0) {
    Write-Host "run_samples: FAILED"
    exit 1
}

$OpList = ($Operations -join ", ")
Write-Host "run_samples: OK ($($Samples.Count) samples; operations: $OpList)"
exit 0
