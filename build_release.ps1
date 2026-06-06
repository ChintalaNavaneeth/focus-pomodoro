Write-Host "Building Focus App..." -ForegroundColor Cyan
flutter build apk --split-per-abi

Write-Host "`nRenaming APK files to 'Focus-*'..." -ForegroundColor Yellow
Get-ChildItem -Path "build\app\outputs\flutter-apk\app-*.apk" | Rename-Item -NewName { $_.Name -replace 'app-','Focus-' } -PassThru

Write-Host "`nSuccess! Your perfectly named APKs are ready in 'build\app\outputs\flutter-apk\'" -ForegroundColor Green
