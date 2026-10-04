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
Copy-Item $detailDocumentPath (Join-Path $stage 'README.md')
$files = foreach ($relative in @('module.json','Velune.Module.Sample.dll','assets/icon.png','README.md')) {
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
Add-Type -AssemblyName System.IO.Compression.FileSystem
$output = Join-Path $artifacts ("VELUNE.Module.Sample-{0}.velune" -f $manifest.version)
Remove-Item $output -Force -ErrorAction SilentlyContinue
[IO.Compression.ZipFile]::CreateFromDirectory(
    $stage,
    $output,
    [IO.Compression.CompressionLevel]::Optimal,
    $false)

Remove-Item $stage -Recurse -Force
Write-Output $output
