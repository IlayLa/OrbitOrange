# Runs every automatic check on the project. Run it before every commit.
#
# Usage (PowerShell), from anywhere:
#     tools\check_project.ps1
# Set the environment variable GODOT_EXECUTABLE if Godot is not at the default
# path below.
#
# The checks:
#   1. Import: Godot loads every script, scene and image. Any error fails.
#   2. Tests:  every tests\test_*.gd runs through tests\TestRunner.tscn.
#   3. Scenes: every scene in scenes\ runs for 60 frames without an error.

$GodotExecutable = $env:GODOT_EXECUTABLE
if (-not $GodotExecutable) {
    $GodotExecutable = "C:\dev\Godot\Godot_v4.7.2-stable_win64_console.exe"
}
$ProjectFolder = Split-Path -Parent $PSScriptRoot
$FailedStepCount = 0

# Runs Godot with the given arguments and fails the step when Godot exits
# with an error code or prints an error line.
function Invoke-CheckStep {
    param([string]$StepName, [string[]]$GodotArguments)

    $OutputFile = New-TemporaryFile
    $ErrorFile = New-TemporaryFile
    $AllArguments = @("--headless", "--path", "`"$ProjectFolder`"") + $GodotArguments
    $GodotProcess = Start-Process -FilePath $GodotExecutable -ArgumentList $AllArguments `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $OutputFile -RedirectStandardError $ErrorFile
    $StepOutput = @(Get-Content $OutputFile) + @(Get-Content $ErrorFile)
    Remove-Item $OutputFile, $ErrorFile

    $HasErrorLine = [bool]($StepOutput | Where-Object { $_ -match "ERROR" })
    if ($GodotProcess.ExitCode -ne 0 -or $HasErrorLine) {
        Write-Output "FAILED  $StepName"
        $StepOutput | Where-Object { $_ -ne "" } | ForEach-Object { Write-Output "        $_" }
        $script:FailedStepCount += 1
    } else {
        Write-Output "passed  $StepName"
    }
}

Invoke-CheckStep "import" @("--import")
Invoke-CheckStep "tests" @("res://tests/TestRunner.tscn")

$SceneFiles = Get-ChildItem -Path (Join-Path $ProjectFolder "scenes") -Filter "*.tscn" -Recurse | Sort-Object FullName
foreach ($SceneFile in $SceneFiles) {
    $RelativePath = $SceneFile.FullName.Substring($ProjectFolder.Length + 1).Replace("\", "/")
    $SceneResourcePath = "res://$RelativePath"
    Invoke-CheckStep "scene $SceneResourcePath" @("--quit-after", "60", $SceneResourcePath)
}

if ($FailedStepCount -eq 0) {
    Write-Output "All checks passed."
} else {
    Write-Output "$FailedStepCount check(s) failed."
    exit 1
}
