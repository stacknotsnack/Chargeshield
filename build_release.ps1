# ChargeShield release build script for Windows
# Usage: .\build_release.ps1 -DvlaKey "YOUR_DVLA_API_KEY" -MapsKey "YOUR_MAPS_API_KEY"
# Get DVLA key at: https://developer-portal.driver-vehicle-licensing.api.gov.uk/

param(
    [Parameter(Mandatory=$true)]
    [string]$DvlaKey,

    [Parameter(Mandatory=$false)]
    [string]$MapsKey = ""
)

Set-Location $PSScriptRoot

Write-Host "Building ChargeShield release APK..." -ForegroundColor Cyan

flutter build apk --release --split-per-abi `
    --dart-define=DVLA_API_KEY=$DvlaKey `
    --dart-define=GOOGLE_MAPS_API_KEY=$MapsKey

if ($LASTEXITCODE -eq 0) {
    Write-Host "Copying APK to netlify..." -ForegroundColor Green
    Copy-Item "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk" `
              "netlify\public\chargeshield-free.apk" -Force
    Write-Host "Done. Run 'netlify deploy --prod' from the netlify folder." -ForegroundColor Green
} else {
    Write-Host "Build failed." -ForegroundColor Red
}
