param(
    [Parameter(Mandatory = $true)][string]$MapFile,
    [string]$SourceFolder = '',
    [string]$SourceFolderFile = '',
    [string]$ProjectRoot = '',
    [int]$FullEdge = 1400,
    [int]$ThumbEdge = 900,
    [int]$Quality = 82,
    [string]$HeroSource = '',
    [string]$AboutSource = ''
)

# =============================================================
#  import-photos.ps1
#  Batch-imports your own photos into the site:
#    1. rotates by EXIF orientation
#    2. resizes to a long edge (full 1400 / thumb 900) and re-encodes JPEG
#    3. writes images\work-NN.jpg + images\thumbs\work-NN.jpg
#    4. reads EXIF for year + shooting params (camera / aperture / shutter / ISO)
#    5. regenerates js\gallery-data.js from the mapping file
#
#  Mapping file rows (UTF-8, "|" separated):
#      categoryKey | categoryLabel | title | sourceFileName
#
#  NOTE: this script is intentionally ASCII-only, because Windows
#  PowerShell 5.1 mis-parses UTF-8 files that have no BOM.
# =============================================================

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Paths may contain non-ASCII characters, so they can be passed via a UTF-8
# text file (one path) or derived from this script's own location instead of
# being typed on the command line.
if (-not $SourceFolder -and $SourceFolderFile) {
    $SourceFolder = (Get-Content -LiteralPath $SourceFolderFile -Raw -Encoding UTF8).Trim()
}
if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
}
if (-not (Test-Path -LiteralPath $SourceFolder)) { throw "source folder not found: $SourceFolder" }

Write-Output ("source folder : " + $SourceFolder)
Write-Output ("project root  : " + $ProjectRoot)

$imgDir   = Join-Path $ProjectRoot 'images'
$thumbDir = Join-Path $imgDir 'thumbs'
New-Item -ItemType Directory -Force -Path $thumbDir | Out-Null

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' }

function Save-Jpeg($image, $longEdge, $outPath, $quality) {
    $scale = [Math]::Min($longEdge / $image.Width, $longEdge / $image.Height)
    $w = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
    $h = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($image, 0, 0, $w, $h)
    $g.Dispose()

    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter (
        [System.Drawing.Imaging.Encoder]::Quality), ([int64]$quality)
    $bmp.Save($outPath, $jpegCodec, $ep)
    $bmp.Dispose()

    return ($w.ToString() + 'x' + $h.ToString())
}

function Read-Exif($image) {
    $m = @{}
    foreach ($pi in $image.PropertyItems) {
        $b = $pi.Value
        if ($pi.Id -eq 0x0112) { $m.orientation = [BitConverter]::ToUInt16($b, 0) }
        elseif ($pi.Id -eq 0x010F) { $m.make  = ([Text.Encoding]::ASCII.GetString($b)).Trim([char]0) }
        elseif ($pi.Id -eq 0x0110) { $m.model = ([Text.Encoding]::ASCII.GetString($b)).Trim([char]0) }
        elseif ($pi.Id -eq 0x9003) { $m.date  = ([Text.Encoding]::ASCII.GetString($b)).Trim([char]0) }
        elseif ($pi.Id -eq 0x8827) { $m.iso   = [BitConverter]::ToUInt16($b, 0) }
        elseif ($pi.Id -eq 0x829D -and $b.Length -ge 8) {
            $n = [BitConverter]::ToUInt32($b, 0); $d = [BitConverter]::ToUInt32($b, 4)
            if ($d -gt 0) { $m.fnum = [math]::Round($n / $d, 1) }
        }
        elseif ($pi.Id -eq 0x829A -and $b.Length -ge 8) {
            $n = [BitConverter]::ToUInt32($b, 0); $d = [BitConverter]::ToUInt32($b, 4)
            if ($n -gt 0) { $m.exp = '1/' + [math]::Round($d / $n) }
        }
    }
    return $m
}

function New-ResizedJpeg($srcPath, $longEdge, $outPath, $quality) {
    $image = [System.Drawing.Image]::FromFile($srcPath)
    $exif  = Read-Exif $image

    switch ($exif.orientation) {
        3 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        6 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        8 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }

    $dims = Save-Jpeg $image $longEdge $outPath $quality
    $image.Dispose()
    return $dims
}

# ---------- read the mapping file ----------
$rows = @(Get-Content -LiteralPath $MapFile -Encoding UTF8) |
    Where-Object { $_ -and $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') }

$entries    = New-Object System.Collections.Generic.List[string]
$categories = New-Object System.Collections.Generic.List[string]
$report     = New-Object System.Collections.Generic.List[string]
$report.Add("OUT`tSOURCE`tCATEGORY`tTITLE`tYEAR`tCAMERA`tDIMENSIONS")

$index  = 0
$failed = 0

foreach ($row in $rows) {
    $parts = @($row -split '\|' | ForEach-Object { $_.Trim() })
    if ($parts.Count -lt 4) { Write-Warning ("bad row: " + $row); $failed++; continue }

    $key   = $parts[0]
    $label = $parts[1]
    $title = $parts[2]
    $name  = $parts[3]

    $srcPath = Join-Path $SourceFolder $name
    if (-not (Test-Path -LiteralPath $srcPath)) {
        Write-Warning ("missing source file: " + $name)
        $failed++
        continue
    }

    $index++
    $nn = '{0:d2}' -f $index

    $image = [System.Drawing.Image]::FromFile($srcPath)
    $exif  = Read-Exif $image
    switch ($exif.orientation) {
        3 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        6 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        8 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }

    $fullOut  = Join-Path $imgDir   ("work-$nn.jpg")
    $thumbOut = Join-Path $thumbDir ("work-$nn.jpg")
    $dims     = Save-Jpeg $image $FullEdge  $fullOut  $Quality
    $null     = Save-Jpeg $image $ThumbEdge $thumbOut ([Math]::Max(60, $Quality - 8))
    $image.Dispose()

    $year = ''
    if ($exif.date -and $exif.date.Length -ge 4) { $year = $exif.date.Substring(0, 4) }

    $cam = @()
    if ($exif.model) { $cam += $exif.model }
    if ($exif.fnum)  { $cam += ('f/' + $exif.fnum) }
    if ($exif.exp)   { $cam += ($exif.exp + 's') }
    if ($exif.iso)   { $cam += ('ISO ' + $exif.iso) }
    $camera = ($cam -join (' ' + [char]0x00B7 + ' '))

    $entries.Add('  {')
    $entries.Add("    src: 'images/work-$nn.jpg',")
    $entries.Add("    thumb: 'images/thumbs/work-$nn.jpg',")
    $entries.Add("    download: 'images/download/work-$nn.jpg',")
    $entries.Add("    title: '$title',")
    $entries.Add("    category: '$key',")
    $entries.Add("    year: '$year',")
    $entries.Add("    camera: '$camera'")
    $entries.Add('  },')

    if (-not $categories.Contains($key + "`t" + $label)) {
        $categories.Add($key + "`t" + $label)
    }

    $report.Add(("work-$nn.jpg`t{0}`t{1}`t{2}`t{3}`t{4}`t{5}" -f $name, $key, $title, $year, $camera, $dims))
    Write-Output ("[{0}] work-{1}.jpg <- {2}" -f $index, $nn, $name)
}

# the final entry must not keep a trailing comma
if ($entries.Count -gt 0 -and $entries[$entries.Count - 1] -eq '  },') {
    $entries[$entries.Count - 1] = '  }'
}

# ---------- hero + about ----------
if ($HeroSource) {
    $heroPath = Join-Path $SourceFolder $HeroSource
    if (Test-Path -LiteralPath $heroPath) {
        $dims = New-ResizedJpeg $heroPath 1920 (Join-Path $imgDir 'hero.jpg') $Quality
        $report.Add(("hero.jpg`t{0}`t-`tfirst-screen image`t-`t-`t{1}" -f $HeroSource, $dims))
        Write-Output ("hero.jpg <- " + $HeroSource)
    }
}

if ($AboutSource) {
    $aboutPath = Join-Path $SourceFolder $AboutSource
    if (Test-Path -LiteralPath $aboutPath) {
        $dims = New-ResizedJpeg $aboutPath 1100 (Join-Path $imgDir 'about.jpg') $Quality
        $report.Add(("about.jpg`t{0}`t-`tabout section image`t-`t-`t{1}" -f $AboutSource, $dims))
        Write-Output ("about.jpg <- " + $AboutSource)
    }
}

# ---------- regenerate js/gallery-data.js (UTF-8, no BOM) ----------
$js = New-Object System.Collections.Generic.List[string]
$js.Add('/* =========================================================')
$js.Add('   LUMINA photo data - generated by scripts/import-photos.ps1')
$js.Add('   ---------------------------------------------------------')
$js.Add('   FIELDS: src / thumb (grid) / download (watermarked copy) / title / category / year / camera')
$js.Add('   OPTIONAL: place (location) - add it and it shows in the overlay')
$js.Add('   CATEGORY KEYS must match the keys of window.PHOTO_CATEGORIES.')
$js.Add('   ========================================================= */')
$js.Add('')
$js.Add('window.PHOTO_CATEGORIES = {')
for ($i = 0; $i -lt $categories.Count; $i++) {
    $kv    = $categories[$i] -split "`t"
    $comma = ','
    if ($i -eq ($categories.Count - 1)) { $comma = '' }
    $js.Add('  ' + $kv[0] + ": '" + $kv[1] + "'" + $comma)
}
$js.Add('};')
$js.Add('')
$js.Add('window.PHOTOS = [')
foreach ($line in $entries) { $js.Add($line) }
$js.Add('];')

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $ProjectRoot 'js\gallery-data.js'), ($js -join "`r`n"), $utf8NoBom)

$reportPath = Join-Path $env:TEMP 'lumina-import-report.tsv'
$report | Out-File -FilePath $reportPath -Encoding utf8

Write-Output ""
Write-Output ("imported = {0}   failed = {1}" -f $index, $failed)
Write-Output ("report   = " + $reportPath)
