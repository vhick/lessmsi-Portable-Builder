param([Parameter(Mandatory=$true)][string]$IconPath,[Parameter(Mandatory=$true)][string]$OutputDir)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$icon = New-Object System.Drawing.Icon($IconPath)
try {
    foreach ($size in @(16,32,75,128,256)) {
        $bitmap = New-Object System.Drawing.Bitmap($size,$size)
        try {
            $g=[System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $g.Clear([System.Drawing.Color]::Transparent)
                $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.DrawIcon($icon, (New-Object System.Drawing.Rectangle(0,0,$size,$size)))
            } finally { $g.Dispose() }
            $bitmap.Save((Join-Path $OutputDir "appicon_$size.png"),[System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $bitmap.Dispose() }
    }
} finally { $icon.Dispose() }
