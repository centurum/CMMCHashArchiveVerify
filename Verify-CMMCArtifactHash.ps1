<#
.SYNOPSIS
Verifies file integrity within a ZIP archive by comparing contents to the hash log output of the CMMC hashing script.

.DESCRIPTION
This script is intended to be used to verify the contents of an archived copy of CMMC Assessment evidence artifacts,
stored within a ZIP file. The script extracts the provided ZIP archive to a temp directory, computes the SHA256 hash 
of each file, and compares them to the pre-generated artifact log output of the CMMC Hashing Guide script. The script
provides visual verification of each file and provides a summary of any files which have failed verification. Optionally 
preserves the extraction directory.

If the script is run without the BaseDirectory parameter it will attempt to figure it out. , e.g. 'C:\Temp\CMMC\[Evidence 
Files Here]' would have a base directory of 'C:\Temp\CMMC'. This base directory is part of the output of the hashing script.

.AUTHOR
Jon Frank (Centurum, Inc)
https://github.com/centurum/CMMCHashArchiveVerify

.VERSION
1.0.0

.LASTUPDATED
2025-04-21

.PARAMETER ArtifactLogPath
Path to the CMMCAssessmentArtifacts.log file containing SHA256 hashes.

.PARAMETER ArtifactZipPath
Path to the ZIP file containing artifact files to verify.

.PARAMETER PreserveTemp
Optional switch to preserve the temp extraction folder.

.PARAMETER BaseDirectory
Optional string to identify the base directory found in the artifacts log file. 
.NOTES
Copyright (c) 2025 Centurum, Inc
MIT License
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ArtifactLogPath,

    [Parameter(Mandatory = $true)]
    [string]$ArtifactZipPath,

    [Parameter(Mandatory = $false)]
    [switch]$PreserveTemp,

    [Parameter(Mandatory = $false)]
    [string]$BaseDirectory
)

function Get-CommonBasePath {
    param (
        [string[]]$paths
    )

    if (-not $paths -or $paths.Count -eq 0) {
        return ""
    }

    # Split the first path into segments
    $commonSegments = $paths[0] -split '[\\/]+'

    foreach ($path in $paths[1..($paths.Count - 1)]) {
        $segments = $path -split '[\\/]+'

        for ($i = 0; $i -lt $commonSegments.Count; $i++) {
            if ($i -ge $segments.Count -or $commonSegments[$i] -ne $segments[$i]) {
                # Truncate commonSegments to the point of mismatch
                $commonSegments = $commonSegments[0..($i - 1)]
                break
            }
        }
    }

    return ($commonSegments -join '\')
}


Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

# Resolve paths
$ArtifactLogPath = Resolve-Path $ArtifactLogPath | Select-Object -ExpandProperty Path
$ArtifactZipPath = Resolve-Path $ArtifactZipPath | Select-Object -ExpandProperty Path

#### If we don't have a base directory, try to figure it out by finding the common paths in the log file. 
if(-not $BaseDirectory){
    $fullPaths = @()
    
    #### Grab only the SHA256 lines and get the file path
    Get-Content $ArtifactLogPath | ForEach-Object {
        if ($_ -match '^SHA256\s+([A-Fa-f0-9]{64})\s+(.+)$') {
            $fullPaths += $matches[2].Trim()
        }
    }
    $BaseDirectory = Get-CommonBasePath -Paths $fullPaths

}

#### Create temp dir to extract ZIP. 
$tempDir = Join-Path $env:TEMP ("CMMCVerify_" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($ArtifactZipPath, $tempDir)

#### If we only see one item at the root, and it's a folder, assume this is an archive generated with the base folder preserved.
$rootItems = Get-ChildItem -Path $tempDir -Force

if ($rootItems.Count -eq 1 -and $rootItems[0].PSIsContainer) {
    $tempDir = $rootItems[0].FullName
}

#### Parse expected hashes using relative paths from base folder
$expectedHashes = @{}
foreach ($line in Get-Content $ArtifactLogPath) {
    if ($line -match '^SHA256\s+([A-Fa-f0-9]{64})\s+(.+)$') {
        $hash = $matches[1].Trim()
        $fullPath = $matches[2].Trim()
        $relativePath = $fullPath.Replace($BaseDirectory, '').TrimStart('\', '/').Replace('\', '/')
        $expectedHashes[$relativePath] = $hash
    }
}

#### Hash extracted files, locate the corresponding hash log entry, and compare the SHA256 values.
$results = @()
$zipRelativePaths=@()
$zipFiles = Get-ChildItem -LiteralPath $tempDir -Recurse -File

foreach ($file in $zipFiles) {
    $relativePath = $file.FullName.Substring($tempDir.Length).TrimStart('\', '/')
    $relativePath = $relativePath -replace '\\', '/'
    $zipRelativePaths += $relativePath

    $actualHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $expectedHash = $expectedHashes[$relativePath]

    $match = ($expectedHash -eq $actualHash)

    $results += [PSCustomObject]@{
        File         = $relativePath
        ExpectedHash = if ($expectedHash) { $expectedHash.Substring(0,8) + "..." } else { "" }
        ActualHash   = $actualHash.Substring(0,8) + "..."
        Match        = if ($match) { "✅" } else { "❌" }
    }
}

#### Output the results.
Write-Host "`n📋 Verification Results:"
$results | Format-Table -AutoSize

$failed = $results | Where-Object { $_.Match -ne "✅" }

if ($failed.Count -eq 0) {
    Write-Host "`n✅ All files verified successfully!" -ForegroundColor Green
} else {
    Write-Host "   Some files failed verification!" -BackgroundColor Red -ForegroundColor White
    $failed | Format-Table -AutoSize
}

#### Notify of situations where a file existed in the hash log but was not in the archive.
$logOnlyPaths = $expectedHashes.Keys | Where-Object { $_ -notin $zipRelativePaths }
$logOnlyResults = @()
if ($logOnlyPaths.Count -gt 0) {
    Write-Host "The following files were listed in the log but NOT found in the archive:" -ForegroundColor Red
    foreach ($path in $logOnlyPaths | Sort-Object) {
        $hash = $expectedHashes[$path]
	$logOnlyresults += [PSCustomObject]@{
        File         = $path
        ExpectedHash = $hash.Substring(0,8) + "..."
    	}
    }
    	$logOnlyResults | Format-Table -AutoSize
    Write-Host "This may be due to special characters such as em-dashes being incorrectly output as '?' by the Get-FileHash function. Compare to failed verification files above to manually verify." -ForegroundColor Cyan
} else {
    Write-Host "`n✅ All log entries were matched by files in the ZIP." -ForegroundColor Green
}


if (-not $PreserveTemp) {
    Write-Host "`n🧹 Cleaning up temp directory..."
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "`n📁 Temp directory preserved at: $tempDir"
}

