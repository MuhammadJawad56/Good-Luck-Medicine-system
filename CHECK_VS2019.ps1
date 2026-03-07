# Quick Script to Check VS 2019 Installation
# Run this in PowerShell: .\CHECK_VS2019.ps1

Write-Host "`n=== Checking Visual Studio 2019 Installation ===" -ForegroundColor Yellow
Write-Host ""

$vs2019Path = "C:\Program Files (x86)\Microsoft Visual Studio\2019"
$vs2019Exists = Test-Path $vs2019Path

if ($vs2019Exists) {
    Write-Host "✅ VS 2019 IS INSTALLED!" -ForegroundColor Green
    Write-Host "`nLocation: $vs2019Path" -ForegroundColor Cyan
    Write-Host "`nInstalled Editions:" -ForegroundColor Cyan
    Get-ChildItem $vs2019Path | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
    Write-Host "`n✅ You can now run: flutter run -d windows" -ForegroundColor Green
} else {
    Write-Host "❌ VS 2019 IS NOT INSTALLED!" -ForegroundColor Red
    Write-Host "`nYou need to install Visual Studio 2019 Build Tools." -ForegroundColor Yellow
    Write-Host "`nSteps:" -ForegroundColor Cyan
    Write-Host "1. Go to: https://visualstudio.microsoft.com/downloads/" -ForegroundColor White
    Write-Host "2. Scroll to 'Tools for Visual Studio 2019'" -ForegroundColor White
    Write-Host "3. Download 'Build Tools for Visual Studio 2019'" -ForegroundColor White
    Write-Host "4. Run installer and select 'Desktop development with C++'" -ForegroundColor White
    Write-Host "5. Restart your computer after installation" -ForegroundColor White
    Write-Host "`nOr use direct download:" -ForegroundColor Cyan
    Write-Host "https://aka.ms/vs/16/release/vs_buildtools.exe" -ForegroundColor Green
}

Write-Host "`n=== Check Complete ===" -ForegroundColor Yellow
