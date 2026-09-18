param(
    [Parameter(Mandatory = $true)][string]$MapFile,
    [string]$SourceFolder = '',
    [string]$SourceFolderFile = '',
    [string]$ProjectRoot = '',
    [string]$OutDir = '',
    [string]$TextFile = '',
    [int]$LongEdge = 1800,
    [int]$Quality = 86,
    [int]$Limit = 0
)

# =============================================================
#  make-watermarked.ps1
#  Builds the DOWNLOAD version of every work:
#    1. takes the ORIGINAL photo (not the 1400px page image)
#    2. rotates by EXIF orientation
#    3. resizes to a long edge of 1800px (never upscales)
#    4. burns a corner watermark into the pixels
#    5. writes images\download\work-NN.jpg
#
#  The numbering follows the mapping table row order, exactly like
#  scripts\import-photos.ps1 -> use THE SAME mapping file, then
#  images\download\work-NN.jpg is always the download copy of
#  images\work-NN.jpg.
#
#  Watermark text: scripts\watermark-text.txt (UTF-8, 2 lines)
#      line 1 = main line (brand),  line 2 = sub line (may be empty)
#  Watermark look (size / position / opacity / outline) is tuned by
#  the constants inside Add-Watermark below.
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
if (-not $OutDir) {
    $OutDir = Join-Path $ProjectRoot 'images\download'
}
if (-not $TextFile) {
    $TextFile = Join-Path $PSScriptRoot 'watermark-text.txt'
}
if (-not (Test-Path -LiteralPath $SourceFolder)) { throw "source folder not found: $SourceFolder" }
if (-not (Test-Path -LiteralPath $TextFile)) { throw "watermark text file not found: $TextFile" }

$textLines = @(Get-Content -LiteralPath $TextFile -Encoding UTF8)
if ($textLines.Count -lt 1 -or -not $textLines[0].Trim()) {
    throw 'watermark-text.txt must have at least one non-empty line'
}
$wmMain = $textLines[0].Trim()
$wmSub = ''
if ($textLines.Count -gt 1) { $wmSub = $textLines[1].Trim() }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Output ("source folder : " + $SourceFolder)
Write-Output ("output folder : " + $OutDir)
Write-Output ("watermark     : " + $wmMain + "   /   " + $wmSub)
Write-Output ("long edge     : " + $LongEdge + "px   quality: " + $Quality)
Write-Output ''

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' } | Select-Object -First 1

function Get-Orientation($image) {
    try {
        $item = $image.GetPropertyItem(0x0112)
        return [BitConverter]::ToUInt16($item.Value, 0)
    } catch {
        return 1
    }
}

function Save-Jpeg($bmp, $quality, $outPath) {
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter (
        [System.Drawing.Imaging.Encoder]::Quality), ([int64]$quality)
    $bmp.Save($outPath, $jpegCodec, $ep)
    $ep.Dispose()
}

# Draws text with a dark outline around it, so a single white watermark
# stays readable on both bright sky and dark tree shadows.
function Draw-OutlinedText($g, $text, $font, $x, $y, $fillBrush, $strokeBrush, $penWidth) {
    $offsets = @(
        @(-1.0, 0.0), @(1.0, 0.0), @(0.0, -1.0), @(0.0, 1.0),
        @(-0.7, -0.7), @(0.7, -0.7), @(-0.7, 0.7), @(0.7, 0.7)
    )
    foreach ($o in $offsets) {
        $dx = [float]($x + $o[0] * $penWidth)
        $dy = [float]($y + $o[1] * $penWidth)
        $g.DrawString($text, $font, $strokeBrush, (New-Object System.Drawing.PointF($dx, $dy)))
    }
    $g.DrawString($text, $font, $fillBrush, (New-Object System.Drawing.PointF([float]$x, [float]$y)))
}

function Add-Watermark($bmp, $main, $sub) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $long = [Math]::Max($bmp.Width, $bmp.Height)

    # ---- tuning knobs (all relative to the long edge, so every size looks alike)
    $mainSize = [double][Math]::Round($long * 0.033)   # main line font size
    $subSize  = [double][Math]::Round($long * 0.018)   # sub line font size
    $margin   = [double][Math]::Round($long * 0.028)   # distance to the right / bottom edge
    $gap      = [double][Math]::Round($mainSize * 0.30)
    $penWidth = [double][Math]::Max(1.2, $long * 0.0022)
    # ----------------------------------------------------------------------------

    $mainFont = New-Object System.Drawing.Font('Microsoft YaHei', $mainSize,
        [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $subFont = New-Object System.Drawing.Font('Microsoft YaHei', $subSize,
        [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

    $mainMeasure = $g.MeasureString($main, $mainFont)
    $subMeasure = New-Object System.Drawing.SizeF(0, 0)
    if ($sub) { $subMeasure = $g.MeasureString($sub, $subFont) }

    # bottom-right corner, both lines flush right
    $right  = $bmp.Width - $margin
    $bottom = $bmp.Height - $margin
    $subY   = $bottom - $subMeasure.Height
    $mainY  = $subY - $gap - $mainMeasure.Height
    $mainX  = $right - $mainMeasure.Width
    $subX   = $right - $subMeasure.Width

    $fillBrush   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 255, 255, 255))
    $strokeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(105, 0, 0, 0))
    $subFill     = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(135, 255, 255, 255))
    $subStroke   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(90, 0, 0, 0))

    Draw-OutlinedText $g $main $mainFont $mainX $mainY $fillBrush $strokeBrush $penWidth
    if ($sub) {
        Draw-OutlinedText $g $sub $subFont $subX $subY $subFill $subStroke ([Math]::Max(1.0, $penWidth * 0.75))
    }

    $mainFont.Dispose(); $subFont.Dispose()
    $fillBrush.Dispose(); $strokeBrush.Dispose(); $subFill.Dispose(); $subStroke.Dispose()
    $g.Dispose()
}

# ---------- export every work ----------
$rows = @(Get-Content -LiteralPath $MapFile -Encoding UTF8) |
    Where-Object { $_ -and $_.Trim() -ne '' -and -not $_.TrimStart().StartsWith('#') }

$report = New-Object System.Collections.Generic.List[string]
$report.Add("OUT`tSOURCE`tTITLE`tDIMENSIONS`tBYTES")

$index = 0
$failed = 0

foreach ($row in $rows) {
    if ($Limit -gt 0 -and $index -ge $Limit) { break }

    $parts = @($row -split '\|' | ForEach-Object { $_.Trim() })
    if ($parts.Count -lt 4) { Write-Warning ("bad row: " + $row); $failed++; continue }

    $title = $parts[2]
    $name = $parts[3]
    $srcPath = Join-Path $SourceFolder $name
    if (-not (Test-Path -LiteralPath $srcPath)) {
        Write-Warning ("missing source file: " + $name)
        $failed++
        continue
    }

    $index++
    $nn = '{0:d2}' -f $index
    $outPath = Join-Path $OutDir ("work-$nn.jpg")

    $image = [System.Drawing.Image]::FromFile($srcPath)
    switch (Get-Orientation $image) {
        3 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
        6 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
        8 { $image.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }

    # never upscale: photos that are already smaller stay at their own size
    $scale = $LongEdge / [double]([Math]::Max($image.Width, $image.Height))
    if ($scale -gt 1) { $scale = 1.0 }
    $w = [int][Math]::Round($image.Width * $scale)
    $h = [int][Math]::Round($image.Height * $scale)

    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($image, 0, 0, $w, $h)
    $g.Dispose()
    $image.Dispose()

    Add-Watermark $bmp $wmMain $wmSub
    Save-Jpeg $bmp $Quality $outPath
    $bmp.Dispose()

    $bytes = (Get-Item -LiteralPath $outPath).Length
    $report.Add(("work-$nn.jpg`t" + $name + "`t" + $title + "`t" + $w + "x" + $h + "`t" + $bytes))
    Write-Output ("[{0}] work-{1}.jpg  {2}x{3}  {4} KB" -f $index, $nn, $w, $h, [Math]::Round($bytes / 1KB))
}

$reportPath = Join-Path $env:TEMP 'lumina-watermark-report.tsv'
$report | Out-File -FilePath $reportPath -Encoding utf8

$files = @(Get-ChildItem -LiteralPath $OutDir -File -Filter 'work-*.jpg')
$total = 0
if ($files.Count -gt 0) { $total = ($files | Measure-Object Length -Sum).Sum }
$avg = 0
if ($files.Count -gt 0) { $avg = $total / $files.Count }

Write-Output ''
Write-Output ('exported = {0}   failed = {1}' -f $files.Count, $failed)
Write-Output ('total    = ' + [Math]::Round($total / 1MB, 2) + ' MB   average = ' + [Math]::Round($avg / 1KB) + ' KB')
Write-Output ('report   = ' + $reportPath)
