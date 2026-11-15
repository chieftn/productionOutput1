#Requires -Version 7.4
param([switch]$RequireProjectVerification)
$ErrorActionPreference = 'Stop'
$workloadSchemaPath = Join-Path $PSScriptRoot 'workload.schema.json'

function Assert-UniqueJsonProperties([System.Text.Json.JsonElement]$Element) {
    if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($property in $Element.EnumerateObject()) {
            if (!$names.Add($property.Name)) {
                throw [FormatException]::new("Duplicate JSON property: $($property.Name)")
            }
            Assert-UniqueJsonProperties $property.Value
        }
    }
    elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
        foreach ($value in $Element.EnumerateArray()) { Assert-UniqueJsonProperties $value }
    }
}

function Get-WorkloadErrors([string]$Json, [string]$Root, [switch]$RequireProjectVerification) {
    $document = [System.Text.Json.JsonDocument]::Parse($Json)
    try { Assert-UniqueJsonProperties $document.RootElement }
    finally { $document.Dispose() }

    $schemaErrors = @()
    $valid = Test-Json -Json $Json -SchemaFile $workloadSchemaPath -ErrorAction SilentlyContinue -ErrorVariable schemaErrors
    if (!$valid) {
        if (!$schemaErrors) { throw 'JSON Schema validation failed without diagnostics.' }
        return @($schemaErrors | ForEach-Object { $_.ToString() })
    }
    $workload = ConvertFrom-Json -InputObject $Json -AsHashtable
    $errors = [Collections.Generic.List[string]]::new()
    $rootPath = [IO.Path]::GetFullPath($Root)
    $instructionPaths = @{}
    foreach ($role in $workload.agents.Keys) {
        $path = $rootPath
        $invalid = $false
        foreach ($part in $workload.agents[$role].instructions.Split('/')) {
            $path = Join-Path $path $part
            if (!(Test-Path -LiteralPath $path)) {
                $errors.Add("agents/$role/instructions: file does not exist")
                $invalid = $true
                break
            }
            $item = Get-Item -LiteralPath $path -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $errors.Add("agents/$role/instructions: filesystem links are not permitted")
                $invalid = $true
                break
            }
        }
        if ($invalid) { continue }
        if ($item.PSIsContainer) {
            $errors.Add("agents/$role/instructions: reference must be a file")
        }
        elseif (![IO.File]::ReadAllText($path, [Text.Encoding]::UTF8).Trim()) {
            $errors.Add("agents/$role/instructions: file is empty")
        }
        else {
            $instructionPaths[$role] = [IO.Path]::GetFullPath($path)
        }
    }
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if ($instructionPaths.Count -eq 2 -and
        [string]::Equals($instructionPaths.implementation, $instructionPaths.alignment, $comparison)) {
        $errors.Add('agents: Implementation and Alignment require separate instruction files')
    }
    if ($RequireProjectVerification -and !$workload.verification.commands.Count) {
        $errors.Add('verification/commands: project verification is not configured; execution must remain blocked')
    }
    return $errors.ToArray()
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $json = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'workload.json'), [Text.Encoding]::UTF8)
        $errors = @(Get-WorkloadErrors $json $PSScriptRoot -RequireProjectVerification:$RequireProjectVerification)
        if ($errors.Count) {
            foreach ($errorMessage in $errors) { [Console]::Error.WriteLine($errorMessage) }
            exit 1
        }
        Write-Output 'Workload definition is valid. This is not worker readiness or authorization.'
        if (!(ConvertFrom-Json -InputObject $json -AsHashtable).verification.commands.Count) {
            Write-Output 'Project verification is not configured; execution must remain blocked.'
        }
    }
    catch {
        [Console]::Error.WriteLine("Workload validation failed: $($_.Exception.Message)")
        exit 1
    }
}
