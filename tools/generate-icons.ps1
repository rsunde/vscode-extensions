# Generates extension icons from simple JSON drawings.
#
# Usage:
#   pwsh -NoProfile -File tools/generate-icons.ps1 -All
#   pwsh -NoProfile -File tools/generate-icons.ps1 -DrawingPath BranchMergerExtension/images/icon.drawing.json
#
# Conventions:
#   - Each extension can include: images/icon.drawing.json
#   - Output path: images/icon.png
#   - If images/icon.png exists and images/icon.original.png does not, it will be backed up.
#
# Notes:
#   - Uses System.Drawing, so this is intended for Windows.

[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'All')]
    [switch] $All,

    [Parameter(Mandatory = $true, ParameterSetName = 'Single')]
    [string] $DrawingPath,

    [Parameter()]
    [ValidateSet('Normal', 'BackgroundOnly', 'ShapesOnly')]
    [string] $Mode = 'Normal',

    [Parameter()]
    [string] $OutputName,

    [Parameter()]
    [string] $StylePath = 'tools/icon-style.json',

    [Parameter(ParameterSetName = 'Blank')]
    [switch] $Blank,

    [Parameter(ParameterSetName = 'Blank')]
    [string] $BlankOutPath = 'tools/style.blank.png',

    [Parameter(ParameterSetName = 'Blank')]
    [int] $BlankSize = 128,

    [Parameter(ParameterSetName = 'Blank')]
    [string] $BlankBackground = '#141820'
)

$ErrorActionPreference = 'Stop'

function Coalesce([object] $value, [object] $defaultValue) {
    if ($null -ne $value) { return $value }
    return $defaultValue
}

function ConvertTo-Color([object] $value, [hashtable] $palette) {
    if ($null -eq $value) { throw 'Color value is required.' }

    if ($value -is [string]) {
        $s = $value.Trim()
        if ($s.StartsWith('$')) {
            $key = $s.Substring(1)
            if (-not $palette.ContainsKey($key)) {
                throw "Unknown palette color '$s'"
            }
            return $palette[$key]
        }

        # #RRGGBB or #AARRGGBB
        if ($s -match '^#(?<hex>[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$') {
            $hex = $Matches.hex
            if ($hex.Length -eq 6) {
                $r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
                $g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
                $b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
                return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
            }

            $a = [Convert]::ToInt32($hex.Substring(0, 2), 16)
            $r = [Convert]::ToInt32($hex.Substring(2, 2), 16)
            $g = [Convert]::ToInt32($hex.Substring(4, 2), 16)
            $b = [Convert]::ToInt32($hex.Substring(6, 2), 16)
            return [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
        }

        throw "Unsupported color format '$s'"
    }

    throw "Unsupported color type: $($value.GetType().FullName)"
}

function ClampByte([int] $v) {
    if ($v -lt 0) { return 0 }
    if ($v -gt 255) { return 255 }
    return $v
}

function Adjust-Color([System.Drawing.Color] $color, [double] $factor) {
    $r = ClampByte ([int]([Math]::Round($color.R * $factor)))
    $g = ClampByte ([int]([Math]::Round($color.G * $factor)))
    $b = ClampByte ([int]([Math]::Round($color.B * $factor)))
    return [System.Drawing.Color]::FromArgb($color.A, $r, $g, $b)
}

function Get-CellRandom([int] $seed, [int] $x, [int] $y) {
    # Deterministic per-cell RNG. Keep in 0..int32 range.
    $h = [int64]($seed -bxor ($x * 73856093) -bxor ($y * 19349663))
    $h = ($h -band 0x7fffffff)
    if ($h -eq 0) { $h = 1 }
    return New-Object System.Random ([int]$h)
}

function Draw-GridBackground([System.Drawing.Graphics] $g, [int] $size, [object] $bg, [hashtable] $palette) {
    $cellSize = [int](Coalesce $bg.cellSize 16)
    if ($cellSize -lt 4) { $cellSize = 4 }

    $seed = [int](Coalesce $bg.seed 1337)
    $tileColorsRaw = Coalesce $bg.tileColors @('#101726', '#121B2B', '#152033', '#18263D')
    $tileColors = @()
    foreach ($c in $tileColorsRaw) {
        $tileColors += (ConvertTo-Color $c $palette)
    }
    if ($tileColors.Count -eq 0) {
        $tileColors = @([System.Drawing.Color]::FromArgb(255, 16, 23, 38))
    }

    $tileJitter = [double](Coalesce $bg.tileJitter 0.08)
    if ($tileJitter -lt 0) { $tileJitter = 0 }
    if ($tileJitter -gt 0.35) { $tileJitter = 0.35 }

    # Fill tiles.
    for ($y = 0; $y -lt $size; $y += $cellSize) {
        for ($x = 0; $x -lt $size; $x += $cellSize) {
            $rng = Get-CellRandom -seed $seed -x $x -y $y
            $idx = $rng.Next(0, $tileColors.Count)
            $base = $tileColors[$idx]

            # subtle brightness variance
            $f = 1.0 + (($rng.NextDouble() * 2.0 - 1.0) * $tileJitter)
            $cAdj = Adjust-Color -color $base -factor $f

            $brush = New-Object System.Drawing.SolidBrush($cAdj)
            try {
                $w = [Math]::Min($cellSize, $size - $x)
                $h = [Math]::Min($cellSize, $size - $y)
                $g.FillRectangle($brush, $x, $y, $w, $h)
            }
            finally {
                $brush.Dispose()
            }
        }
    }

    # Grid lines
    $lineColor = ConvertTo-Color (Coalesce $bg.lineColor '#22314A') $palette
    $lineWidth = [single](Coalesce $bg.lineWidth 1)
    $linePen = New-Pen $lineColor $lineWidth 'square'
    try {
        for ($p = 0; $p -le $size; $p += $cellSize) {
            $g.DrawLine($linePen, $p, 0, $p, $size)
            $g.DrawLine($linePen, 0, $p, $size, $p)
        }
    }
    finally {
        $linePen.Dispose()
    }

    # Note: intentionally no intersection dots; keep the background fully square.
}

function Get-Point([object] $value) {
    if ($value -is [System.Array] -and $value.Length -eq 2) {
        return [System.Drawing.PointF]::new([single]$value[0], [single]$value[1])
    }
    throw 'Point must be [x,y].'
}

function Get-Points([object] $value) {
    if ($value -isnot [System.Array]) { throw 'Points must be an array.' }
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    foreach ($p in $value) {
        $pts.Add((Get-Point $p))
    }
    return $pts.ToArray()
}

function New-Pen([System.Drawing.Color] $color, [single] $width, [string] $cap) {
    $pen = New-Object System.Drawing.Pen($color, $width)
    switch ((Coalesce $cap '').ToLowerInvariant()) {
        'round' {
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        }
        'square' {
            $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Square
            $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Square
        }
        default {
            # flat by default
        }
    }
    return $pen
}

function Add-PaletteFromJson([hashtable] $palette, [object] $jsonPalette) {
    if (-not $jsonPalette) { return }
    foreach ($prop in $jsonPalette.PSObject.Properties) {
        $name = $prop.Name
        $value = $prop.Value
        if ($value -is [string] -and $value.Trim().StartsWith('$')) {
            $refKey = $value.Trim().Substring(1)
            if (-not $palette.ContainsKey($refKey)) {
                throw "Palette value '$value' references missing key '$refKey'"
            }
            $palette[$name] = $palette[$refKey]
            continue
        }

        $palette[$name] = (ConvertTo-Color $value $palette)
    }
}

function Draw-Shapes([System.Drawing.Graphics] $g, [hashtable] $palette, [object[]] $shapes, [string] $drawingPath) {
    foreach ($shape in (Coalesce $shapes @())) {
        $type = (Coalesce $shape.type '').ToLowerInvariant()

        switch ($type) {
            'polyline' {
                $pts = Get-Points $shape.points
                $ptsF = [System.Drawing.PointF[]]$pts
                $pen = New-Pen (ConvertTo-Color $shape.color $palette) ([single](Coalesce $shape.width 6)) (Coalesce $shape.cap 'round')
                try {
                    if ($shape.closed -eq $true) {
                        $g.DrawPolygon($pen, $ptsF)
                    }
                    else {
                        $g.DrawLines($pen, $ptsF)
                    }
                }
                finally {
                    $pen.Dispose()
                }
            }

            'line' {
                $p1 = Get-Point $shape.from
                $p2 = Get-Point $shape.to
                $pen = New-Pen (ConvertTo-Color $shape.color $palette) ([single](Coalesce $shape.width 6)) (Coalesce $shape.cap 'round')
                try {
                    $g.DrawLine($pen, $p1, $p2)
                }
                finally {
                    $pen.Dispose()
                }
            }

            'arrow' {
                $from = Get-Point $shape.from
                $to = Get-Point $shape.to
                $width = [single](Coalesce $shape.width 6)
                $headSize = [single](Coalesce $shape.headSize 10)
                $color = ConvertTo-Color $shape.color $palette

                $pen = New-Pen $color $width (Coalesce $shape.cap 'round')
                try {
                    $g.DrawLine($pen, $from, $to)

                    $dx = $from.X - $to.X
                    $dy = $from.Y - $to.Y
                    $len = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
                    if ($len -gt 0.0001) {
                        $ux = $dx / $len
                        $uy = $dy / $len

                        # Rotate unit vector by +/- 30 degrees for arrow head
                        $theta = [Math]::PI / 6
                        $cos = [Math]::Cos($theta)
                        $sin = [Math]::Sin($theta)

                        $lx = ($ux * $cos) - ($uy * $sin)
                        $ly = ($ux * $sin) + ($uy * $cos)

                        $rx = ($ux * $cos) + ($uy * $sin)
                        $ry = (-$ux * $sin) + ($uy * $cos)

                        $pLeft = [System.Drawing.PointF]::new($to.X + [single]($lx * $headSize), $to.Y + [single]($ly * $headSize))
                        $pRight = [System.Drawing.PointF]::new($to.X + [single]($rx * $headSize), $to.Y + [single]($ry * $headSize))

                        $g.DrawLine($pen, $to, $pLeft)
                        $g.DrawLine($pen, $to, $pRight)
                    }
                }
                finally {
                    $pen.Dispose()
                }
            }

            'circle' {
                $center = Get-Point $shape.center
                $radius = [single](Coalesce $shape.radius 8)
                if ($shape.fillColor) {
                    $brush = New-Object System.Drawing.SolidBrush((ConvertTo-Color $shape.fillColor $palette))
                    try {
                        $g.FillEllipse($brush, $center.X - $radius, $center.Y - $radius, $radius * 2, $radius * 2)
                    }
                    finally {
                        $brush.Dispose()
                    }
                }

                if ($shape.strokeColor) {
                    $pen = New-Pen (ConvertTo-Color $shape.strokeColor $palette) ([single](Coalesce $shape.width 2)) (Coalesce $shape.cap 'round')
                    try {
                        $g.DrawEllipse($pen, $center.X - $radius, $center.Y - $radius, $radius * 2, $radius * 2)
                    }
                    finally {
                        $pen.Dispose()
                    }
                }
            }

            'shadowednode' {
                $center = Get-Point $shape.center
                $radius = [single](Coalesce $shape.radius 9)
                $shadowOffset = if ($shape.shadowOffset) { Get-Point $shape.shadowOffset } else { [System.Drawing.PointF]::new(2, 2) }
                $shadowColor = ConvertTo-Color (Coalesce $shape.shadowColor '#5A000000') $palette
                $fillColor = ConvertTo-Color (Coalesce $shape.fillColor '#EBEBEB') $palette

                $shadowBrush = New-Object System.Drawing.SolidBrush($shadowColor)
                $fillBrush = New-Object System.Drawing.SolidBrush($fillColor)
                try {
                    $g.FillEllipse($shadowBrush,
                        $center.X - $radius + $shadowOffset.X,
                        $center.Y - $radius + $shadowOffset.Y,
                        $radius * 2,
                        $radius * 2)
                    $g.FillEllipse($fillBrush,
                        $center.X - $radius,
                        $center.Y - $radius,
                        $radius * 2,
                        $radius * 2)
                }
                finally {
                    $shadowBrush.Dispose()
                    $fillBrush.Dispose()
                }
            }

            'roundedrect' {
                $x = [single]$shape.x
                $y = [single]$shape.y
                $w = [single]$shape.width
                $h = [single]$shape.height
                $r = [single](Coalesce $shape.radius 10)

                $path = New-Object System.Drawing.Drawing2D.GraphicsPath
                try {
                    $d = $r * 2
                    $path.AddArc($x, $y, $d, $d, 180, 90)
                    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
                    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
                    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
                    $path.CloseFigure()

                    if ($shape.fillColor) {
                        $brush = New-Object System.Drawing.SolidBrush((ConvertTo-Color $shape.fillColor $palette))
                        try { $g.FillPath($brush, $path) } finally { $brush.Dispose() }
                    }

                    if ($shape.strokeColor) {
                        $pen = New-Pen (ConvertTo-Color $shape.strokeColor $palette) ([single](Coalesce $shape.strokeWidth 3)) (Coalesce $shape.cap 'round')
                        try { $g.DrawPath($pen, $path) } finally { $pen.Dispose() }
                    }
                }
                finally {
                    $path.Dispose()
                }
            }

            'text' {
                $text = [string](Coalesce $shape.text '')
                $x = [single](Coalesce $shape.x 0)
                $y = [single](Coalesce $shape.y 0)
                $fontName = [string](Coalesce $shape.font 'Segoe UI')
                $fontSize = [single](Coalesce $shape.size 18)
                $fontStyle = [System.Drawing.FontStyle]::Regular
                if ((Coalesce $shape.bold $false) -eq $true) { $fontStyle = $fontStyle -bor [System.Drawing.FontStyle]::Bold }

                $color = ConvertTo-Color (Coalesce $shape.color '#EBEBEB') $palette
                $brush = New-Object System.Drawing.SolidBrush($color)
                $font = New-Object System.Drawing.Font($fontName, $fontSize, $fontStyle, [System.Drawing.GraphicsUnit]::Pixel)

                try {
                    $g.DrawString($text, $font, $brush, $x, $y)
                }
                finally {
                    $brush.Dispose()
                    $font.Dispose()
                }
            }

            default {
                throw "Unknown shape type '$type' in $drawingPath"
            }
        }
    }
}

function Get-DebugOutputName([string] $baseName, [string] $mode) {
    if (-not $baseName) { $baseName = 'icon.png' }
    $name = [System.IO.Path]::GetFileNameWithoutExtension($baseName)
    $ext = [System.IO.Path]::GetExtension($baseName)
    if (-not $ext) { $ext = '.png' }

    switch ($mode) {
        'BackgroundOnly' { return "$name.background$ext" }
        'ShapesOnly' { return "$name.shapes$ext" }
        default { return $baseName }
    }
}

function Save-BlankIcon([string] $repoRoot, [string] $outRel, [int] $size, [string] $backgroundColor) {
    Add-Type -AssemblyName System.Drawing

    $outPath = Join-Path $repoRoot $outRel
    $outDir = Split-Path -Parent $outPath
    if (!(Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir | Out-Null
    }

    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $g.Clear((ConvertTo-Color $backgroundColor @{}))
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bmp.Dispose()

    Write-Host "Wrote $outRel"
}

function Save-IconFromDrawing([string] $drawingPath, [string] $mode, [string] $outputNameOverride) {
    if (-not (Test-Path $drawingPath)) {
        throw "Drawing file not found: $drawingPath"
    }

    $drawingFull = (Resolve-Path $drawingPath).Path
    $drawingDir = Split-Path -Parent $drawingFull

    $json = Get-Content -Raw -Path $drawingFull | ConvertFrom-Json

    $style = $null
    $styleFull = $null
    if ($StylePath) {
        $styleFull = Join-Path $repoRoot $StylePath
        if (Test-Path $styleFull) {
            $style = Get-Content -Raw -Path $styleFull | ConvertFrom-Json
        }
    }

    $size = if ($json.size) { [int]$json.size } elseif ($style -and $style.size) { [int]$style.size } else { 128 }
    $baseOutputName = if ($json.output) { [string]$json.output } else { 'icon.png' }
    $effectiveOutputName = if ($outputNameOverride) {
        $outputNameOverride
    }
    else {
        Get-DebugOutputName -baseName $baseOutputName -mode $mode
    }

    $outPath = Join-Path $drawingDir $effectiveOutputName

    $backupPath = Join-Path $drawingDir 'icon.original.png'
    if ((Test-Path $outPath) -and -not (Test-Path $backupPath)) {
        Copy-Item -LiteralPath $outPath -Destination $backupPath
    }

    Add-Type -AssemblyName System.Drawing

    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $palette = @{}
    if ($style -and $style.palette) {
        Add-PaletteFromJson -palette $palette -jsonPalette $style.palette
    }
    if ($json.palette) {
        Add-PaletteFromJson -palette $palette -jsonPalette $json.palette
    }

    # Background
    if ($mode -eq 'ShapesOnly') {
        # Transparent background for debugging shape layer.
        $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    }
    else {
        $bg = if ($json.background) { $json.background } elseif ($style -and $style.background) { $style.background } else { $null }
        if ($bg -and $bg.type -eq 'grid') {
            Draw-GridBackground -g $g -size $size -bg $bg -palette $palette
        }
        elseif ($bg -and $bg.type -eq 'solid') {
            $g.Clear((ConvertTo-Color $bg.color $palette))
        }
        else {
            # default background
            $g.Clear([System.Drawing.Color]::FromArgb(255, 20, 24, 32))
        }
    }

    # Common base layer (style)
    if ($mode -ne 'ShapesOnly') {
        if ($style -and $style.baseShapes) {
            Draw-Shapes -g $g -palette $palette -shapes $style.baseShapes -drawingPath $drawingPath
        }
    }

    if ($mode -eq 'BackgroundOnly') {
        $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose()
        $bmp.Dispose()
        Write-Host "Wrote $($outPath.Substring($repoRoot.Length + 1))"
        return
    }

    Draw-Shapes -g $g -palette $palette -shapes (Coalesce $json.shapes @()) -drawingPath $drawingPath

    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose()
    $bmp.Dispose()

    Write-Host "Wrote $($outPath.Substring($repoRoot.Length + 1))"
}

$repoRoot = Split-Path -Parent $PSScriptRoot

if ($PSCmdlet.ParameterSetName -eq 'Blank') {
    Save-BlankIcon -repoRoot $repoRoot -outRel $BlankOutPath -size $BlankSize -backgroundColor $BlankBackground
    exit 0
}

if ($PSCmdlet.ParameterSetName -eq 'Single') {
    Save-IconFromDrawing -drawingPath (Join-Path $repoRoot $DrawingPath) -mode $Mode -outputNameOverride $OutputName
    exit 0
}

# Default: generate all drawings in the repo
$drawings = Get-ChildItem -Path $repoRoot -Recurse -File -Filter 'icon.drawing.json' |
Where-Object { $_.FullName -notmatch '\\node_modules\\' }

if (-not $drawings -or $drawings.Count -eq 0) {
    throw 'No icon.drawing.json files found.'
}

foreach ($d in $drawings) {
    Save-IconFromDrawing -drawingPath $d.FullName -mode $Mode -outputNameOverride $OutputName
}
