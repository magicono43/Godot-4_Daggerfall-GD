param([switch]$Test, [switch]$Visual)
$ErrorActionPreference = 'Stop'
$godotPath = 'C:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe'
$godotArguments = @('--path', $PSScriptRoot)
if ($Test) {
    if (-not $Visual) { $godotArguments += '--headless' }
    foreach ($suite in @('smoke', 'movement', 'stairs', 'expansion', 'climbing', 'corners')) {
        & $godotPath @godotArguments --fixed-fps 60 --script "res://tests/$suite.gd"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    exit 0
}
& $godotPath @godotArguments
exit $LASTEXITCODE
