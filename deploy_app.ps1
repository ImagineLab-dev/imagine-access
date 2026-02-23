$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$env:ANDROID_HOME = "C:\Users\Hp\AppData\Local\Android\Sdk"

Write-Host ">>> Starting Android Emulator (Medium_Phone_API_36.1)..." -ForegroundColor Cyan
Start-Process -FilePath "$env:ANDROID_HOME\emulator\emulator.exe" -ArgumentList "-avd Medium_Phone_API_36.1" -WindowStyle Minimized

Write-Host ">>> Waiting 20 seconds for boot..." -ForegroundColor Cyan
Start-Sleep -Seconds 20

Write-Host ">>> Checking connected devices..." -ForegroundColor Cyan
flutter devices

Write-Host ">>> Cleaning Project..." -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host ">>> Launching Imagine Access on Emulator..." -ForegroundColor Cyan
flutter run -d emulator-5554
