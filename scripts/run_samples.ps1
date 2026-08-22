# Run eml front-end operation(s) on every sample under samples/.
#
# Usage:
#   pwsh -File scripts/run_samples.ps1
#   pwsh -File scripts/run_samples.ps1 -Operations tokenize
#   pwsh -File scripts/run_samples.ps1 -Operations tokenize,parse,preproc
#   pwsh -File scripts/run_samples.ps1 --operations tokenize parse
#
# -Operations / --operations: one or more of preproc, tokenize, parse, compile.
# If omitted (or empty), all operations are run.
#
# Input-format coverage:
#   preproc  — .mxeml and .teml samples
#   tokenize — .mxeml, .teml, and stack .eml (piped from compile)
#   parse    — .mxeml, .teml, .eml, .beml (IR formats piped from compile)
#   compile  — .mxeml, .teml → .beml/.eml; then .eml↔.beml conversion
#
# Results are written under .results/<operation>/. Intermediate IR for chaining
# lives under .results/_chain/. Exit 0 if every check succeeds, otherwise 1.

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
$ChainDir = Join-Path $Root ".results" "_chain"
$AllOperations = @("preproc", "tokenize", "parse", "compile")

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

function Write-Color {
    param(
        [string] $Text,
        [ConsoleColor] $Foreground = [ConsoleColor]::Gray,
        [switch] $NoNewline
    )
    if ($NoNewline) {
        Write-Host -NoNewline $Text -ForegroundColor $Foreground
    }
    else {
        Write-Host $Text -ForegroundColor $Foreground
    }
}

function Write-SectionHeader {
    param([string] $Title)

    Write-Host ""
    Write-Color ("=" * 60) Cyan
    Write-Color ("  $Title") Cyan
    Write-Color ("=" * 60) Cyan
}

function Get-SampleBaseName {
    param([System.IO.FileInfo] $Sample)
    return [System.IO.Path]::GetFileNameWithoutExtension($Sample.Name)
}

function Pad-Cell {
    param([string] $Text, [int] $Width)
    if ($null -eq $Text) {
        $Text = ""
    }
    if ($Text.Length -ge $Width) {
        return $Text
    }
    return $Text + (" " * ($Width - $Text.Length))
}

function Start-ResultTable {
    param(
        [string[]] $Samples = @(),
        [string[]] $Inputs = @(),
        [string[]] $Outputs = @(),
        [string[]] $OptionsList = @()
    )

    $HSample = "sample name"
    $HInput = "input format"
    $HOutput = "output format"
    $HOptions = "CLI options"
    $HResult = "result"

    $WSample = $HSample.Length
    $WInput = $HInput.Length
    $WOutput = $HOutput.Length
    $WOptions = $HOptions.Length
    $WResult = [Math]::Max($HResult.Length, "[FAIL]".Length)

    foreach ($S in $Samples) {
        if ($S.Length -gt $WSample) { $WSample = $S.Length }
    }
    foreach ($V in $Inputs) {
        if ($V.Length -gt $WInput) { $WInput = $V.Length }
    }
    foreach ($V in $Outputs) {
        if ($V.Length -gt $WOutput) { $WOutput = $V.Length }
    }
    foreach ($V in $OptionsList) {
        if ($null -ne $V -and $V.Length -gt $WOptions) { $WOptions = $V.Length }
    }

    $script:TableWidths = @{
        Sample  = $WSample
        Input   = $WInput
        Output  = $WOutput
        Options = $WOptions
        Result  = $WResult
    }

    Write-Host ""
    $Header =
        "| $(Pad-Cell $HSample $WSample) | $(Pad-Cell $HInput $WInput) | $(Pad-Cell $HOutput $WOutput) | $(Pad-Cell $HOptions $WOptions) | $(Pad-Cell $HResult $WResult) |"
    $Rule =
        "|-$("-" * $WSample)-|-$("-" * $WInput)-|-$("-" * $WOutput)-|-$("-" * $WOptions)-|-$("-" * $WResult)-|"
    Write-Color $Header DarkGray
    Write-Color $Rule DarkGray
}

function Write-ResultRow {
    param(
        [string] $Sample,
        [string] $InputFormat,
        [string] $OutputFormat,
        [string] $Options,
        [bool] $Ok,
        [string] $FailDetail = ""
    )

    $W = $script:TableWidths
    $Status = if ($Ok) { "[OK]" } else { "[FAIL]" }
    $Prefix =
        "| $(Pad-Cell $Sample $W.Sample) | $(Pad-Cell $InputFormat $W.Input) | $(Pad-Cell $OutputFormat $W.Output) | $(Pad-Cell $Options $W.Options) | "
    Write-Color $Prefix White -NoNewline
    if ($Ok) {
        Write-Color (Pad-Cell $Status $W.Result) Green -NoNewline
        Write-Color " |" White
    }
    else {
        Write-Color (Pad-Cell $Status $W.Result) Red -NoNewline
        Write-Color " |" White -NoNewline
        if ($FailDetail.Length -gt 0) {
            Write-Color "  $FailDetail" DarkRed
        }
        else {
            Write-Host ""
        }
    }
}

function Get-AllSampleNames {
    $Names = [System.Collections.Generic.List[string]]::new()
    foreach ($S in $script:MxemlSamples) {
        [void]$Names.Add((Get-SampleBaseName $S))
    }
    foreach ($S in $script:TemlSamples) {
        [void]$Names.Add((Get-SampleBaseName $S))
    }
    foreach ($S in $script:ChainSources) {
        $N = Get-SampleBaseName $S
        if (-not $Names.Contains($N)) {
            [void]$Names.Add($N)
        }
    }
    return ,$Names.ToArray()
}

function Write-OpSummary {
    param(
        [string] $Op,
        [int] $OkCount,
        [int] $FailCount,
        [int] $Total
    )
    Write-Host ""
    if ($FailCount -eq 0) {
        Write-Color "  ${Op}: $OkCount/$Total passed" Green
    }
    else {
        Write-Color "  ${Op}: $OkCount passed, $FailCount failed (of $Total)" Red
    }
}

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

$MxemlSamples = @(Get-ChildItem -LiteralPath $SamplesDir -Filter "*.mxeml" | Sort-Object Name)
$TemlSamples = @(Get-ChildItem -LiteralPath $SamplesDir -Filter "*.teml" | Sort-Object Name)
if ($MxemlSamples.Count -eq 0) {
    Write-Error "no .mxeml samples found in '$SamplesDir'."
    exit 1
}

# Skip huge trees when deriving .eml/.beml for tokenize/parse chaining.
$ChainSources = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($S in $MxemlSamples) {
    if ($S.Name -notmatch 'taylor') {
        [void]$ChainSources.Add($S)
    }
}
foreach ($S in $TemlSamples) {
    [void]$ChainSources.Add($S)
}

$Failed = 0
$TotalOk = 0
$TotalFail = 0

Write-Host ""
Write-Color "eml sample runner" White
Write-Color ("  mxeml:      $($MxemlSamples.Count)") DarkGray
Write-Color ("  teml:       $($TemlSamples.Count)") DarkGray
Write-Color ("  chain IR:   $($ChainSources.Count) (mxeml without taylor + teml)") DarkGray
Write-Color ("  operations: $($Operations -join ', ')") DarkGray
Write-Color ("  output:     .results/<operation>/") DarkGray

function Ensure-ChainArtifacts {
    New-Item -ItemType Directory -Force -Path $script:ChainDir | Out-Null
    $Ok = 0
    $Fail = 0
    foreach ($Sample in $script:ChainSources) {
        $Base = Get-SampleBaseName $Sample
        $EmlPath = Join-Path $script:ChainDir ($Base + ".eml")
        $BemlPath = Join-Path $script:ChainDir ($Base + ".beml")
        if ((Test-Path -LiteralPath $EmlPath) -and (Test-Path -LiteralPath $BemlPath)) {
            continue
        }

        & $script:Eml --no-logo --no-color compile `
            -i $Sample.FullName @SampleVarArgs -of eml -o $EmlPath
        if ($LASTEXITCODE -ne 0) {
            $Fail++
            continue
        }
        & $script:Eml --no-logo --no-color compile `
            -i $Sample.FullName @SampleVarArgs -of beml -o $BemlPath
        if ($LASTEXITCODE -ne 0) {
            $Fail++
            continue
        }
        $Ok++
    }
    return @{ Ok = $Ok; Fail = $Fail }
}

function Invoke-PreprocSamples {
    $OkCount = 0
    $FailCount = 0
    $ResultsDir = Join-Path $Root ".results" "preproc"
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
    $CliOpts = "-v … -w none"

    Start-ResultTable `
        -Samples (Get-AllSampleNames) `
        -Inputs @("mxeml", "teml") `
        -Outputs @("mxeml", "teml") `
        -OptionsList @($CliOpts)

    foreach ($Sample in $script:MxemlSamples) {
        $Base = Get-SampleBaseName $Sample
        $OutPath = Join-Path $ResultsDir $Sample.Name
        & $script:Eml --no-logo --no-color preproc `
            -i $Sample.FullName @SampleVarArgs -o $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-ResultRow $Base "mxeml" "mxeml" $CliOpts $false "exit $LASTEXITCODE"
            $FailCount++
        }
        else {
            Write-ResultRow $Base "mxeml" "mxeml" $CliOpts $true
            $OkCount++
        }
    }

    foreach ($Sample in $script:TemlSamples) {
        $Base = Get-SampleBaseName $Sample
        $OutPath = Join-Path $ResultsDir $Sample.Name
        & $script:Eml --no-logo --no-color preproc `
            -i $Sample.FullName @SampleVarArgs -o $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-ResultRow $Base "teml" "teml" $CliOpts $false "exit $LASTEXITCODE"
            $FailCount++
        }
        else {
            Write-ResultRow $Base "teml" "teml" $CliOpts $true
            $OkCount++
        }
    }

    $Total = $OkCount + $FailCount
    Write-OpSummary -Op "preproc" -OkCount $OkCount -FailCount $FailCount -Total $Total
    return @{ Failed = $(if ($FailCount -gt 0) { 1 } else { 0 }); Ok = $OkCount; Fail = $FailCount }
}

function Invoke-TokenizeSamples {
    $OkCount = 0
    $FailCount = 0
    $ResultsDir = Join-Path $Root ".results" "tokenize"
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
    $CliOpts = "-v … -w none"

    Start-ResultTable `
        -Samples (Get-AllSampleNames) `
        -Inputs @("mxeml", "teml", "eml") `
        -Outputs @("tokens") `
        -OptionsList @($CliOpts, "")

    foreach ($Sample in $script:MxemlSamples) {
        $Base = Get-SampleBaseName $Sample
        $OutPath = Join-Path $ResultsDir ($Base + ".tokens")
        & $script:Eml --no-logo --no-color tokenize `
            -i $Sample.FullName @SampleVarArgs -o $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-ResultRow $Base "mxeml" "tokens" $CliOpts $false "exit $LASTEXITCODE"
            $FailCount++
        }
        else {
            Write-ResultRow $Base "mxeml" "tokens" $CliOpts $true
            $OkCount++
        }
    }

    foreach ($Sample in $script:TemlSamples) {
        $Base = Get-SampleBaseName $Sample
        $OutPath = Join-Path $ResultsDir ($Base + ".tokens")
        & $script:Eml --no-logo --no-color tokenize `
            -i $Sample.FullName @SampleVarArgs -o $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-ResultRow $Base "teml" "tokens" $CliOpts $false "exit $LASTEXITCODE"
            $FailCount++
        }
        else {
            Write-ResultRow $Base "teml" "tokens" $CliOpts $true
            $OkCount++
        }
    }

    $null = Ensure-ChainArtifacts
    $EmlFiles = @(Get-ChildItem -LiteralPath $script:ChainDir -Filter "*.eml" | Sort-Object Name)
    foreach ($File in $EmlFiles) {
        $Base = Get-SampleBaseName $File
        $OutPath = Join-Path $ResultsDir ($Base + ".eml.tokens")
        & $script:Eml --no-logo --no-color tokenize -i $File.FullName -o $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-ResultRow $Base "eml" "tokens" "" $false "exit $LASTEXITCODE"
            $FailCount++
        }
        else {
            Write-ResultRow $Base "eml" "tokens" "" $true
            $OkCount++
        }
    }

    $Total = $OkCount + $FailCount
    Write-OpSummary -Op "tokenize" -OkCount $OkCount -FailCount $FailCount -Total $Total
    return @{ Failed = $(if ($FailCount -gt 0) { 1 } else { 0 }); Ok = $OkCount; Fail = $FailCount }
}

function Get-ParseOutputFormats {
    return @(
        @{ Of = "mermaid"; Ext = ".syntaxtree" },
        @{ Of = "md"; Ext = ".md" },
        @{ Of = "dot"; Ext = ".dot" },
        @{ Of = "svg"; Ext = ".svg" }
    )
}

function Write-ParseFormatRows {
    param(
        [string] $InputPath,
        [string] $Base,
        [string] $InputFormat,
        [string] $ResultsDir,
        [string] $Tag,
        [string] $CliOpts,
        [ref] $OkCount,
        [ref] $FailCount
    )

    foreach ($Fmt in (Get-ParseOutputFormats)) {
        $OutPath = Join-Path $ResultsDir ($Base + "." + $Tag + $Fmt.Ext)
        & $script:Eml --no-logo --no-color parse `
            -i $InputPath @SampleVarArgs -of $Fmt.Of -o $OutPath
        if ($LASTEXITCODE -ne 0) {
            Write-ResultRow $Base $InputFormat $Fmt.Of $CliOpts $false "exit $LASTEXITCODE"
            $FailCount.Value++
        }
        else {
            Write-ResultRow $Base $InputFormat $Fmt.Of $CliOpts $true
            $OkCount.Value++
        }
    }
}

function Invoke-ParseSamples {
    $OkCount = 0
    $FailCount = 0
    $ResultsDir = Join-Path $Root ".results" "parse"
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
    $CliOpts = "-v … -w none"

    Start-ResultTable `
        -Samples (Get-AllSampleNames) `
        -Inputs @("mxeml", "teml", "eml", "beml") `
        -Outputs @("mermaid", "md", "dot", "svg") `
        -OptionsList @($CliOpts, "")

    foreach ($Sample in $script:MxemlSamples) {
        $Base = Get-SampleBaseName $Sample
        Write-ParseFormatRows $Sample.FullName $Base "mxeml" $ResultsDir "mxeml" `
            $CliOpts ([ref]$OkCount) ([ref]$FailCount)
    }

    foreach ($Sample in $script:TemlSamples) {
        $Base = Get-SampleBaseName $Sample
        Write-ParseFormatRows $Sample.FullName $Base "teml" $ResultsDir "teml" `
            $CliOpts ([ref]$OkCount) ([ref]$FailCount)
    }

    $null = Ensure-ChainArtifacts

    $EmlFiles = @(Get-ChildItem -LiteralPath $script:ChainDir -Filter "*.eml" | Sort-Object Name)
    foreach ($File in $EmlFiles) {
        $Base = Get-SampleBaseName $File
        Write-ParseFormatRows $File.FullName $Base "eml" $ResultsDir "eml" `
            "" ([ref]$OkCount) ([ref]$FailCount)
    }

    $BemlFiles = @(Get-ChildItem -LiteralPath $script:ChainDir -Filter "*.beml" | Sort-Object Name)
    foreach ($File in $BemlFiles) {
        $Base = Get-SampleBaseName $File
        Write-ParseFormatRows $File.FullName $Base "beml" $ResultsDir "beml" `
            "" ([ref]$OkCount) ([ref]$FailCount)
    }

    $Total = $OkCount + $FailCount
    Write-OpSummary -Op "parse" -OkCount $OkCount -FailCount $FailCount -Total $Total
    return @{ Failed = $(if ($FailCount -gt 0) { 1 } else { 0 }); Ok = $OkCount; Fail = $FailCount }
}

function Write-CompileFormatRow {
    param(
        [string] $InputPath,
        [string] $Base,
        [string] $InputFormat,
        [string] $OutputFormat,
        [string] $OutPath,
        [string] $CliOpts,
        [ref] $OkCount,
        [ref] $FailCount
    )

    $Extra = @()
    if ($CliOpts.Length -gt 0) {
        $Extra = $SampleVarArgs
    }

    & $script:Eml --no-logo --no-color compile `
        -i $InputPath @Extra -of $OutputFormat -o $OutPath

    if ($LASTEXITCODE -ne 0) {
        Write-ResultRow $Base $InputFormat $OutputFormat $CliOpts $false "exit $LASTEXITCODE"
        $FailCount.Value++
    }
    else {
        Write-ResultRow $Base $InputFormat $OutputFormat $CliOpts $true
        $OkCount.Value++
    }
}

function Invoke-CompileSamples {
    $OkCount = 0
    $FailCount = 0
    $ResultsDir = Join-Path $Root ".results" "compile"
    New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null
    $CliOpts = "-v … -w none"

    Start-ResultTable `
        -Samples (Get-AllSampleNames) `
        -Inputs @("mxeml", "teml", "eml", "beml") `
        -Outputs @("beml", "eml") `
        -OptionsList @($CliOpts, "")

    foreach ($Sample in $script:MxemlSamples) {
        $Base = Get-SampleBaseName $Sample
        Write-CompileFormatRow $Sample.FullName $Base "mxeml" "beml" `
            (Join-Path $ResultsDir ($Base + ".beml")) $CliOpts ([ref]$OkCount) ([ref]$FailCount)
        Write-CompileFormatRow $Sample.FullName $Base "mxeml" "eml" `
            (Join-Path $ResultsDir ($Base + ".eml")) $CliOpts ([ref]$OkCount) ([ref]$FailCount)
    }

    foreach ($Sample in $script:TemlSamples) {
        $Base = Get-SampleBaseName $Sample
        Write-CompileFormatRow $Sample.FullName $Base "teml" "beml" `
            (Join-Path $ResultsDir ($Base + ".beml")) $CliOpts ([ref]$OkCount) ([ref]$FailCount)
        Write-CompileFormatRow $Sample.FullName $Base "teml" "eml" `
            (Join-Path $ResultsDir ($Base + ".eml")) $CliOpts ([ref]$OkCount) ([ref]$FailCount)
    }

    $null = Ensure-ChainArtifacts

    $EmlFiles = @(Get-ChildItem -LiteralPath $script:ChainDir -Filter "*.eml" | Sort-Object Name)
    foreach ($File in $EmlFiles) {
        $Base = Get-SampleBaseName $File
        Write-CompileFormatRow $File.FullName $Base "eml" "beml" `
            (Join-Path $ResultsDir ($Base + ".from_eml.beml")) "" ([ref]$OkCount) ([ref]$FailCount)
    }

    $BemlFiles = @(Get-ChildItem -LiteralPath $script:ChainDir -Filter "*.beml" | Sort-Object Name)
    foreach ($File in $BemlFiles) {
        $Base = Get-SampleBaseName $File
        Write-CompileFormatRow $File.FullName $Base "beml" "eml" `
            (Join-Path $ResultsDir ($Base + ".from_beml.eml")) "" ([ref]$OkCount) ([ref]$FailCount)
    }

    $Total = $OkCount + $FailCount
    Write-OpSummary -Op "compile" -OkCount $OkCount -FailCount $FailCount -Total $Total
    return @{ Failed = $(if ($FailCount -gt 0) { 1 } else { 0 }); Ok = $OkCount; Fail = $FailCount }
}

foreach ($Op in $Operations) {
    Write-SectionHeader $Op.ToUpperInvariant()

    if ($Op -eq "preproc") {
        $Result = Invoke-PreprocSamples
    }
    elseif ($Op -eq "tokenize") {
        $Result = Invoke-TokenizeSamples
    }
    elseif ($Op -eq "parse") {
        $Result = Invoke-ParseSamples
    }
    elseif ($Op -eq "compile") {
        $Result = Invoke-CompileSamples
    }
    else {
        Write-Error "unknown operation '$Op'."
        exit 1
    }

    $TotalOk += $Result.Ok
    $TotalFail += $Result.Fail
    if ($Result.Failed -ne 0) {
        $Failed = 1
    }
}

Write-Host ""
Write-Color ("=" * 60) Cyan
$SampleTotal = $MxemlSamples.Count + $TemlSamples.Count
if ($Failed -ne 0) {
    Write-Color "  run_samples: FAILED  ($TotalOk ok, $TotalFail failed)" Red
    Write-Color ("=" * 60) Cyan
    Write-Host ""
    exit 1
}

Write-Color "  run_samples: OK  ($SampleTotal samples; $($Operations.Count) operations; $TotalOk checks)" Green
Write-Color ("=" * 60) Cyan
Write-Host ""
exit 0
