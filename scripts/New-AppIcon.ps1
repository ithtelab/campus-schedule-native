$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetPath = Join-Path $PSScriptRoot '../CampusSchedule/Resources/CampusArtwork.xcassets/AppIcon.appiconset'
New-Item -ItemType Directory -Path $assetPath -Force | Out-Null
$bitmap = [System.Drawing.Bitmap]::new(1024, 1024, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(17,17,17), 26)
$pen.StartCap = $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::White)
$outline = [System.Drawing.Drawing2D.GraphicsPath]::new()
$outline.AddArc(198,238,96,96,180,90)
$outline.AddArc(730,238,96,96,270,90)
$outline.AddArc(730,730,96,96,0,90)
$outline.AddArc(198,730,96,96,90,90)
$outline.CloseFigure()
$graphics.DrawPath($pen,$outline)
$graphics.DrawLine($pen,198,398,826,398)
$graphics.DrawLine($pen,366,190,366,298)
$graphics.DrawLine($pen,658,190,658,298)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(17,17,17))
foreach ($cell in @(@(305,487),@(477,487),@(649,487),@(305,650),@(477,650))) {
    $graphics.FillEllipse($brush,[single]$cell[0],[single]$cell[1],70,70)
}
$bitmap.Save((Join-Path $assetPath 'AppIcon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$outline.Dispose(); $brush.Dispose(); $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
Write-Output 'Generated opaque 1024px temporary calendar icon.'
