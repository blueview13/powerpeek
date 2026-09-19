# PowerPeek

PowerPeek is an accessible macOS menu bar battery display. It shows the current battery percentage alongside a visual battery icon, with a larger detail popover for easier reading.

## Current implementation

- Native Swift/AppKit menu bar application
- SwiftUI battery detail popover
- Battery percentage and color-coded SF Symbols battery indicator
- Green at 56-100%, amber at 21-55%, and red at 0-20%
- 25% larger menu bar and popover display
- Charging, full, discharging, and unavailable states
- Local IOKit power-source readings
- Sleep/wake refresh handling
- VoiceOver labels and accessibility values
- Light Mode and Dark Mode support
- Light, Normal, and Bold percentage weight preference
- Swift Package Manager project targeting macOS 13+

## Requirements

- macOS 13 or later
- Swift 5.9 or later
- Xcode 15 or later for the full Xcode workflow

The current machine has Apple Command Line Tools but not the full Xcode application, so `xcodebuild` and code signing cannot be run until Xcode and an Apple Developer certificate are installed.

## Build and run

```sh
swift build
swift run PowerPeek
```

For a distributable application bundle:

```sh
./Scripts/build-app.sh
```

The resulting app is written to `build/PowerPeek.app`, and the DMG is written to `build/PowerPeek.dmg`.

## Release workflow

1. Install Xcode from the Mac App Store.
2. Open this package in Xcode.
3. Configure a unique bundle identifier and signing team.
4. Add a Developer ID Application certificate.
5. Archive and sign the Release build.
6. Notarise the application with Apple's `notarytool`.
7. Create and sign a DMG using `Scripts/build-dmg.sh`.
8. Notarise and staple the DMG before distribution.

## Notes

The initial implementation refreshes periodically and when the Mac wakes. The menu bar item displays both the icon and percentage by default. The app bundle includes a PowerPeek icon suitable for the DMG and Applications folder.
