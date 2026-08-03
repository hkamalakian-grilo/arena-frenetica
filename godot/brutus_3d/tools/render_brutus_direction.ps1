param(
  [Parameter(Mandatory = $true)]
  [ValidateRange(0, 7)]
  [int]$Direction
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$blender = 'C:\Users\Criteria\Documents\Codex\tools\blender-5.2.0-windows-x64\blender.exe'
$blend = Join-Path $projectRoot 'godot\brutus_3d\assets\brutus\brutus_source.blend'
$renderer = Join-Path $projectRoot 'godot\brutus_3d\tools\render_brutus_web_frames.py'

$env:BRUTUS_RENDER_DIRECTION_ONLY = [string]$Direction
Remove-Item Env:BRUTUS_RENDER_DIAGNOSTIC -ErrorAction SilentlyContinue
Remove-Item Env:BRUTUS_RENDER_DIRECTION -ErrorAction SilentlyContinue
Remove-Item Env:BRUTUS_RENDER_CLIP -ErrorAction SilentlyContinue
Remove-Item Env:BRUTUS_RENDER_FRAME_INDEX -ErrorAction SilentlyContinue

& $blender $blend --background --python $renderer
exit $LASTEXITCODE
