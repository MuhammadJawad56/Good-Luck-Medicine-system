# How to Run the App

## In Android Studio:

### Run in Chrome (Web) - Recommended for Testing
1. Click the device selector dropdown (top toolbar, next to the run button)
2. Select **"Chrome (web)"**
3. Click the green **Run** button (or press `Shift+F10`)
4. The app will open in your Chrome browser

### Run on Windows Desktop
1. Select **"Windows (desktop)"** from device selector
2. Click Run
3. **Note**: Requires Visual Studio C++ components (see SETUP_WINDOWS.md)

## From Terminal:

### Run in Chrome:
```bash
flutter run -d chrome
```

### Run on Windows:
```bash
flutter run -d windows
```

### List Available Devices:
```bash
flutter devices
```

## For Production Build (Windows):

After Visual Studio is set up:
```bash
flutter build windows --release
```

Executable location:
`build\windows\x64\runner\Release\goodluck_medicine.exe`
