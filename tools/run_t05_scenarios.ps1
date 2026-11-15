# Run the interactive T05 feature scenarios from the dedicated project checkout.
param(
    [ValidateSet("free", "selected", "three-stage", "late-solid", "handover", "impact", "escape", "unreachable", "no-liftoff")]
    [string]$Scenario = "free"
)

$GodotExecutable = $env:GODOT_EXECUTABLE
if (-not $GodotExecutable) {
    $GodotExecutable = "C:\dev\Godot\Godot_v4.7.2-stable_win64_console.exe"
}
$ProjectFolder = Split-Path -Parent $PSScriptRoot
& $GodotExecutable --path $ProjectFolder "res://scenes/development/T05_demo.tscn" -- "--scenario=$Scenario"
exit $LASTEXITCODE
