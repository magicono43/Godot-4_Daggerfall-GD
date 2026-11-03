param([switch]$Test, [switch]$Visual)
$ErrorActionPreference = 'Stop'
$godotPath = 'C:\Godot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe'
$godotArguments = @('--path', $PSScriptRoot)
if ($Test) {
    if (-not $Visual) { $godotArguments += '--headless' }
    foreach ($suite in @('smoke', 'movement', 'stairs', 'expansion', 'climbing', 'corners', 'crouching', 'combat', 'retaliation', 'skeleton', 'enemy_navigation', 'dagger', 'audio', 'inventory', 'world_loot', 'mace', 'persistence', 'load_focus', 'combat_resolution', 'bear', 'character_sheet', 'fatigue_rest', 'fall_damage', 'armor', 'magic', 'offensive_magic', 'shield')) {
        & $godotPath @godotArguments --fixed-fps 60 --script "res://tests/$suite.gd"
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    # Separate Godot process: prove the slot survives process-local UID state.
    & $godotPath @godotArguments --fixed-fps 60 --script res://tests/persistence.gd -- --persistence-read
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    # Full armor references also survive a clean process-local UID counter.
    & $godotPath @godotArguments --fixed-fps 60 --script res://tests/armor.gd -- --armor-read
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godotPath @godotArguments --fixed-fps 60 --script res://tests/magic.gd -- --magic-read
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $godotPath @godotArguments --fixed-fps 60 --script res://tests/shield.gd -- --shield-read
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    exit 0
}
& $godotPath @godotArguments
exit $LASTEXITCODE



