#Requires -Version 7.4
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Validate-Workload.ps1')
$original = [IO.File]::ReadAllText((Join-Path $root 'workload.json'), [Text.Encoding]::UTF8)
$checks = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw $Message }
    $script:checks++
}

function Read-Fixture { ConvertFrom-Json -InputObject $original -AsHashtable }

function Assert-Rejected($Workload, [string]$Message, [string]$Directory = $root) {
    $json = ConvertTo-Json -InputObject $Workload -Depth 30
    Assert-True (@(Get-WorkloadErrors $json $Directory).Count -gt 0) $Message
}

Assert-True (@(Get-WorkloadErrors $original $root).Count -eq 0) 'The checked-in definition must validate.'
Assert-True (@(Get-WorkloadErrors $original $root -RequireProjectVerification).Count -eq 0) 'The definition must configure project verification.'
$workload = Read-Fixture
$workload.verification.commands = @()
Assert-True (@(Get-WorkloadErrors ($workload | ConvertTo-Json -Depth 30) $root -RequireProjectVerification).Count -gt 0) 'Definition validity must not hide missing project verification.'
$workload = Read-Fixture
$command = @{ executable = 'project-tool'; arguments = @('test'); workingDirectory = '.'; timeoutSeconds = 120 }
$workload.verification.commands = @($command)
Assert-True (@(Get-WorkloadErrors ($workload | ConvertTo-Json -Depth 30) $root -RequireProjectVerification).Count -eq 0) 'Configured command shape should pass; this is not readiness.'

foreach ($case in @(
    @{ field = 'schemaVersion'; value = '2' },
    @{ field = 'workflow.type'; value = 'arbitrary-graph' },
    @{ field = 'workflow.completionCriterion'; value = 'pull_request_approved' },
    @{ field = 'workflow.maximumIterations'; value = 0 },
    @{ field = 'workflow.maximumIterations'; value = 21 },
    @{ field = 'workflow.timeoutMinutes'; value = 241 },
    @{ field = 'agents.alignment.workspaceAccess'; value = 'read-write' }
)) {
    $workload = Read-Fixture
    $parts = $case.field.Split('.')
    $target = $workload
    for ($index = 0; $index -lt $parts.Count - 1; $index++) { $target = $target[$parts[$index]] }
    $target[$parts[-1]] = $case.value
    Assert-Rejected $workload "Unsupported field/value was accepted: $($case.field)"
}
$workload = Read-Fixture
$workload.workflow.plugins = @('unapproved-extension')
Assert-Rejected $workload 'Undeclared workflow extensions must be rejected.'

$workload = Read-Fixture
$workload.workflow.Remove('completionCriterion')
Assert-Rejected $workload 'An explicit workflow completion criterion is required.'

foreach ($path in @('../README.md', '/etc/passwd', 'C:\outside.md', 'agents/missing.md', 'agents/implementation.md')) {
    $workload = Read-Fixture
    $workload.agents.alignment.instructions = $path
    Assert-Rejected $workload "Invalid or shared instruction reference was accepted: $path"
}
foreach ($case in @(
    @{ field = 'executable'; value = 'tool && unapproved-command' },
    @{ field = 'workingDirectory'; value = '../outside' },
    @{ field = 'arguments'; value = @("test`nunapproved-command") },
    @{ field = 'timeoutSeconds'; value = 0 }
)) {
    $workload = Read-Fixture
    $invalidCommand = $command.Clone()
    $invalidCommand[$case.field] = $case.value
    $workload.verification.commands = @($invalidCommand)
    Assert-Rejected $workload "Invalid command field was accepted: $($case.field)"
}

$duplicateRejected = $false
try { Get-WorkloadErrors '{"schemaVersion":"1","schemaVersion":"2"}' $root | Out-Null }
catch [FormatException] { $duplicateRejected = $true }
Assert-True $duplicateRejected 'Duplicate JSON properties must be rejected.'

$temporary = Join-Path ([IO.Path]::GetTempPath()) "factory-workload-tests-$([Guid]::NewGuid().ToString('N'))"
try {
    $fixtureRoot = Join-Path $temporary 'workload'
    $agents = Join-Path $fixtureRoot 'agents'
    New-Item -ItemType Directory -Path $agents | Out-Null
    [IO.File]::WriteAllText((Join-Path $agents 'implementation.md'), 'Implementation')
    [IO.File]::WriteAllText((Join-Path $agents 'alignment.md'), " `n")
    Assert-Rejected (Read-Fixture) 'Empty instruction files must fail.' $fixtureRoot
    $outside = Join-Path $temporary 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    [IO.File]::WriteAllText((Join-Path $outside 'alignment.md'), 'Outside workload')
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path (Join-Path $agents 'linked') -Target $outside | Out-Null
    $workload = Read-Fixture
    $workload.agents.alignment.instructions = 'agents/linked/alignment.md'
    Assert-Rejected $workload 'Instruction references through filesystem links must fail.' $fixtureRoot
}
finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Recurse -Force }
}
Write-Output "Passed $checks focused workload assertions."
