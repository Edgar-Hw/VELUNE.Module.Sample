$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dotnet = if ([string]::IsNullOrWhiteSpace($env:VELUNE_DOTNET)) {
    'dotnet'
} else {
    $env:VELUNE_DOTNET
}
$project = Join-Path $root 'Velune.Module.Sample\Velune.Module.Sample.csproj'
$manifestPath = Join-Path $root 'Velune.Module.Sample\module.json'
$iconPath = Join-Path $root 'Velune.Module.Sample\assets\icon.png'
$detailDocumentPath = Join-Path $root 'README.md'
$detailPreviewPath = Join-Path $root 'assets\detail-preview.png'
$artifacts = Join-Path $root 'artifacts'
$stage = Join-Path $artifacts '.stage'

& $dotnet build $project -c Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$dll = Join-Path $root 'Velune.Module.Sample\bin\Release\net10.0-windows\Velune.Module.Sample.dll'
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force (Join-Path $stage 'assets') | Out-Null
Copy-Item $manifestPath (Join-Path $stage 'module.json')
Copy-Item $dll (Join-Path $stage 'Velune.Module.Sample.dll')
Copy-Item $iconPath (Join-Path $stage 'assets\icon.png')
Copy-Item $detailPreviewPath (Join-Path $stage 'assets\detail-preview.png')
Copy-Item $detailDocumentPath (Join-Path $stage 'README.md')
$files = foreach ($relative in @('module.json','Velune.Module.Sample.dll','assets/icon.png','assets/detail-preview.png','README.md')) {
    $full = Join-Path $stage ($relative -replace '/', '\')
    $item = Get-Item $full
    [ordered]@{
        path = $relative
        length = $item.Length
        sha256 = (Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$package = [ordered]@{
    schemaVersion = 1
    moduleId = $manifest.id
    version = $manifest.version
    integrity = [ordered]@{
        algorithm = 'sha256'
        files = @($files)
    }
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
$packageJson = $package | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $stage 'package.json'), $packageJson, $utf8)
Add-Type -AssemblyName System.IO.Compression
$output = Join-Path $artifacts ("VELUNE.Module.Sample-{0}.velune" -f $manifest.version)
Remove-Item $output -Force -ErrorAction SilentlyContinue

$entryOrder = @(
    'module.json',
    'Velune.Module.Sample.dll',
    'assets/icon.png',
    'assets/detail-preview.png',
    'README.md',
    'package.json'
)
$fixedTimestamp = [DateTimeOffset]::new(
    1980,
    1,
    1,
    0,
    0,
    0,
    [TimeSpan]::Zero)

$archiveStream = [IO.File]::Open(
    $output,
    [IO.FileMode]::CreateNew,
    [IO.FileAccess]::Write,
    [IO.FileShare]::None)

try {
    $archive = [IO.Compression.ZipArchive]::new(
        $archiveStream,
        [IO.Compression.ZipArchiveMode]::Create,
        $false)

    try {
        foreach ($relative in $entryOrder) {
            $sourcePath = Join-Path $stage ($relative -replace '/', '\')
            $entry = $archive.CreateEntry(
                $relative,
                [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTimestamp

            $entryStream = $entry.Open()
            $sourceStream = [IO.File]::OpenRead($sourcePath)

            try {
                $sourceStream.CopyTo($entryStream)
            }
            finally {
                $sourceStream.Dispose()
                $entryStream.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    $archiveStream.Dispose()
}

Remove-Item $stage -Recurse -Force
Write-Output $output
