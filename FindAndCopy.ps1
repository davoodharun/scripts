param (
    [string]$SourceDir,      # Directory to search
    [string]$FileExt,        # File extension to search for
    [string]$DestDir,        # Destination directory
    [string]$ExcludePaths    # Comma-separated list of paths to exclude (optional)
)

# USAGE: .\FindAndCopy.ps1 -SourceDir "C:\Path\To\Search" -FileExt ".txt" -DestDir "C:\Path\To\Destination" -ExcludePaths "C:\Path\To\Exclude,C:\Another\Exclude"

# Validate input
if (-not $SourceDir -or -not $FileExt -or -not $DestDir) {
    Write-Host "Usage: .\FindAndCopy.ps1 -SourceDir <path> -FileExt <extension> -DestDir <destination> [-ExcludePaths <path1,path2>]"
    exit 1
}

# Convert paths to full paths
$SourceDir = (Resolve-Path $SourceDir).Path
$DestDir = (Resolve-Path $DestDir -ErrorAction SilentlyContinue)
if (-not $DestDir) {
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    $DestDir = (Resolve-Path $DestDir).Path
}

# Convert ExcludePaths to an array
$ExcludeArray = @()
if ($ExcludePaths) {
    $ExcludeArray = $ExcludePaths -split ',' | ForEach-Object { (Resolve-Path $_ -ErrorAction SilentlyContinue).Path }
}

# Function to generate a unique filename
function Get-UniqueFilename {
    param (
        [string]$FilePath
    )
    $count = 1
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $Extension = [System.IO.Path]::GetExtension($FilePath)
    $NewFilePath = Join-Path $DestDir $([System.IO.Path]::GetFileName($FilePath))

    while (Test-Path $NewFilePath) {
        $NewFilePath = Join-Path $DestDir "$BaseName`_copy$count$Extension"
        $count++
    }

    return $NewFilePath
}

# Get all matching files, excluding specified paths
$Files = Get-ChildItem -Path $SourceDir -Recurse -File -Filter "*$FileExt*" |
         Where-Object { $ExcludeArray -notcontains $_.DirectoryName }

foreach ($File in $Files) {
    $NewFilePath = Get-UniqueFilename -FilePath $File.FullName

    # Copy the file
    Copy-Item -Path $File.FullName -Destination $NewFilePath -Force

    # Add comment with original path (only for text-based files)
    $TextExtensions = @(".txt", ".log", ".sh", ".py", ".js", ".html", ".md", ".csv", ".json", ".yaml", ".yml", ".xml", ".conf", ".ini")
    if ($TextExtensions -contains $File.Extension.ToLower()) {
        $OriginalPathComment = "# Copied from: $($File.FullName)`n"
        $FileContent = Get-Content -Path $NewFilePath -Raw
        Set-Content -Path $NewFilePath -Value ($OriginalPathComment + $FileContent)
    }

    Write-Host "Copied: $($File.FullName) -> $NewFilePath"
}

Write-Host "All *$FileExt* files copied to $DestDir, excluding: $ExcludePaths"
