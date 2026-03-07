# Performance Optimizations for Low-End Systems (2GB RAM)

This Flutter desktop app has been optimized for systems with limited resources.

## Optimizations Applied:

1. **Removed Heavy Animations**
   - Replaced `AnimatedContainer` with simple state changes
   - Removed transform scaling animations
   - Simplified hover effects

2. **Simplified Graphics**
   - Removed gradient backgrounds (using solid colors)
   - Reduced elevation values
   - Smaller border radius values
   - Reduced icon sizes

3. **Memory Optimizations**
   - Const constructors where possible
   - Reduced padding and spacing
   - Simplified widget tree

4. **Text Scaling**
   - Limited text scaling range for better performance

## Building for Windows:

```bash
# Get dependencies
flutter pub get

# Build release version (optimized)
flutter build windows --release

# The executable will be in:
# build\windows\x64\runner\Release\goodluck_medicine.exe
```

## System Requirements:

- Windows 7 or later
- 2GB RAM minimum
- Flutter SDK 3.0.0 or later

## Tips for Deployment:

1. Build in **release mode** for best performance
2. Close other applications when running
3. Use the release build, not debug build
4. Consider disabling Windows visual effects for better performance
