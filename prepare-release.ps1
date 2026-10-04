$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$packScript = Join-Path $root 'pack.ps1'
$manifestPath = Join-Path $root 'Velune.Module.Sample\module.json'
$readmePath = Join-Path $root 'README.md'
$previewPath = Join-Path $root 'assets\detail-preview.png'
$artifacts = Join-Path $root 'artifacts'

if (-not (Test-Path $packScript)) {
    throw 'pack.ps1 is missing.'
}

if (-not (Test-Path $manifestPath)) {
    throw 'Sample module manifest is missing.'
}

if (-not (Test-Path $readmePath)) {
    throw 'Sample README is missing.'
}

if (-not (Test-Path $previewPath)) {
    throw 'Sample detail preview image is missing.'
}

$packagePath = & $packScript | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ([string]::IsNullOrWhiteSpace($packagePath) -or
    -not (Test-Path $packagePath)) {
    throw 'Sample package output was not produced.'
}

$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$version = [string]$manifest.version

if ([string]::IsNullOrWhiteSpace($version)) {
    throw 'Sample module version is missing.'
}

$bundleName = "VELUNE.Module.Sample-$version-store-release"
$bundleRoot = Join-Path $artifacts $bundleName
$packageFileName = Split-Path -Leaf $packagePath
$detailFileName = "VELUNE.Module.Sample-$version-detail.md"
$previewFileName = "VELUNE.Module.Sample-$version-detail-preview.png"
$releaseManifestFileName = "VELUNE.Module.Sample-$version-release.json"

Remove-Item $bundleRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $bundleRoot | Out-Null

$bundlePackagePath = Join-Path $bundleRoot $packageFileName
$bundleDetailPath = Join-Path $bundleRoot $detailFileName
$bundlePreviewPath = Join-Path $bundleRoot $previewFileName
$bundleManifestPath = Join-Path $bundleRoot $releaseManifestFileName

Copy-Item $packagePath $bundlePackagePath
Copy-Item $previewPath $bundlePreviewPath

$readme = Get-Content $readmePath -Raw
$packageImageReference = 'assets/detail-preview.png'

if (-not $readme.Contains($packageImageReference)) {
    throw "README does not reference '$packageImageReference'."
}

$remoteDetail = $readme.Replace(
    $packageImageReference,
    $previewFileName)

$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText(
    $bundleDetailPath,
    $remoteDetail,
    $utf8)

function Get-ReleaseFileMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item $Path

    return [ordered]@{
        fileName = $item.Name
        length = $item.Length
        sha256 = (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$packageMetadata = Get-ReleaseFileMetadata $bundlePackagePath
$detailMetadata = Get-ReleaseFileMetadata $bundleDetailPath
$previewMetadata = Get-ReleaseFileMetadata $bundlePreviewPath

$releaseManifest = [ordered]@{
    schemaVersion = 1
    moduleId = [string]$manifest.id
    version = $version
    package = $packageMetadata
    detail = $detailMetadata
    assets = @(
        [ordered]@{
            source = $previewFileName
            fileName = $previewMetadata.fileName
            length = $previewMetadata.length
            sha256 = $previewMetadata.sha256
        }
    )
}

$releaseJson = $releaseManifest | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText(
    $bundleManifestPath,
    $releaseJson,
    $utf8)

Write-Output "BUNDLE_ROOT=$bundleRoot"
Write-Output "PACKAGE=$packageFileName"
Write-Output "PACKAGE_SHA256=$($packageMetadata.sha256)"
Write-Output "DETAIL=$detailFileName"
Write-Output "DETAIL_SHA256=$($detailMetadata.sha256)"
Write-Output "PREVIEW=$previewFileName"
Write-Output "MANIFEST=$releaseManifestFileName"
