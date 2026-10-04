$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$packScript = Join-Path $root 'pack.ps1'
$manifestPath = Join-Path $root 'Velune.Module.Sample\module.json'
$readmePath = Join-Path $root 'README.md'
$previewPath = Join-Path $root 'assets\detail-preview.png'
$artifacts = Join-Path $root 'artifacts'
$pagesRoot = Join-Path $root 'docs'

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

$readme = (Get-Content $readmePath -Raw).Replace("`r`n", "`n").Replace("`r", "`n")
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

$pagesVersionRoot = Join-Path (Join-Path $pagesRoot 'store') $version
Remove-Item $pagesVersionRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $pagesVersionRoot | Out-Null

Copy-Item $bundlePackagePath (Join-Path $pagesVersionRoot $packageFileName)
Copy-Item $bundleDetailPath (Join-Path $pagesVersionRoot $detailFileName)
Copy-Item $bundlePreviewPath (Join-Path $pagesVersionRoot $previewFileName)
Copy-Item $bundleManifestPath (Join-Path $pagesVersionRoot $releaseManifestFileName)

[IO.File]::WriteAllText(
    (Join-Path $pagesRoot '.nojekyll'),
    '',
    $utf8)

$indexHtml = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>VELUNE Module Sample</title>
  <style>
    :root { color-scheme: dark; font-family: "Segoe UI Variable Text","Segoe UI",sans-serif; background:#0e1a23; color:#dce8f2; }
    body { margin:0; min-height:100vh; display:grid; place-items:center; }
    main { width:min(680px,calc(100vw - 48px)); padding:48px 0 64px; }
    h1 { margin:0; font-size:32px; font-weight:400; letter-spacing:-.02em; }
    p { color:#91a4b2; line-height:1.65; }
    .meta { margin-top:28px; padding-top:20px; border-top:1px solid #243b4d; font-size:13px; }
    a { color:#79b7e3; text-decoration:none; }
    a:hover { color:#b7dcf7; }
    .files { display:grid; gap:10px; margin-top:18px; }
  </style>
</head>
<body>
  <main>
    <h1>VELUNE Module Sample</h1>
    <p>Reference module distribution for validating the public VELUNE module contract.</p>
    <div class="meta">Current version: $version</div>
    <div class="files">
      <a href="store/$version/$packageFileName">Download .velune package</a>
      <a href="store/$version/$detailFileName">View Store detail Markdown</a>
      <a href="store/$version/$releaseManifestFileName">View release manifest</a>
    </div>
  </main>
</body>
</html>
"@

[IO.File]::WriteAllText(
    (Join-Path $pagesRoot 'index.html'),
    $indexHtml,
    $utf8)

Write-Output "BUNDLE_ROOT=$bundleRoot"
Write-Output "PAGES_ROOT=$pagesRoot"
Write-Output "PAGES_VERSION_ROOT=$pagesVersionRoot"
Write-Output "PACKAGE=$packageFileName"
Write-Output "PACKAGE_SHA256=$($packageMetadata.sha256)"
Write-Output "DETAIL=$detailFileName"
Write-Output "DETAIL_SHA256=$($detailMetadata.sha256)"
Write-Output "PREVIEW=$previewFileName"
Write-Output "MANIFEST=$releaseManifestFileName"
