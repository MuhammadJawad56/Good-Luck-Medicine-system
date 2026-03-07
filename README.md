# Goodluck Medicine - Company Management System

A modern Flutter desktop application for managing inventory, salaries, cheques, and bills for Goodluck Medicine Company.

## Features

- 📦 **Inventory Management** - Manage stock and products
- 💰 **Salary Management** - Employee salary tracking and management
- 🧾 **Cheque Management** - Cheque tracking and management
- 📄 **Bill Management** - Bill management and tracking

## Screenshots

The application features a clean, modern UI with:
- Professional color-coded module cards
- Logo integration
- Responsive design optimized for low-end systems (2GB RAM)
- Material Design 3 components

## Technology Stack

- **Framework**: Flutter 3.35.7
- **Platform**: Windows Desktop
- **Language**: Dart 3.9.2
- **UI**: Material Design 3

## Getting Started

### Prerequisites

- Flutter SDK 3.0.0 or later
- Visual Studio 2019 Build Tools (for Windows desktop builds)
- Windows 10 or later

### Installation

1. Clone the repository:
```bash
git clone https://github.com/MuhammadJawad56/Good-Luck-Medicine-system.git
cd Good-Luck-Medicine-system
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
# For Windows desktop
flutter run -d windows

# For Chrome (web)
flutter run -d chrome
```

## Building for Production

```bash
flutter build windows --release
```

The executable will be at: `build\windows\x64\runner\Release\goodluck_medicine.exe`

## Project Structure

```
lib/
├── main.dart              # App entry point
├── home_page.dart         # Main dashboard with module cards
└── pages/
    ├── inventory_page.dart
    ├── salaries_page.dart
    ├── cheques_page.dart
    └── bills_page.dart
```

## Color Theme

- **Primary**: Professional Blue (#1565C0)
- **Secondary**: Medical Green (#2E7D32)
- **Tertiary**: Warm Orange (#E65100)
- **Accent**: Deep Pink (#AD1457)

## Performance Optimizations

This app is optimized for low-end systems (2GB RAM):
- Minimal animations
- Simplified graphics
- Efficient widget tree
- Reduced memory footprint

## Requirements

- **Minimum RAM**: 2GB
- **OS**: Windows 7 or later
- **Visual Studio**: 2019 Build Tools (for Windows builds)

## License

This project is private and proprietary.

## Author

Muhammad Jawad

## Repository

https://github.com/MuhammadJawad56/Good-Luck-Medicine-system.git
