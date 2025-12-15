# Windows Dark Mode Reference Implementation

This directory contains a reference implementation demonstrating the Windows dark mode API usage.

## Status

The dark mode functionality has been integrated into the main ConEmu codebase. The core implementation can be found in:

- `src/ConEmu/DwmHelper.h` - Dark mode API declarations and initialization
- `src/ConEmu/DwmHelper.cpp` - Dark mode API implementation
- `src/ConEmu/AboutDlg.cpp` - Example usage in About dialog
- `src/ConEmu/ConEmu.cpp` - Main window dark mode support
- `src/ConEmu/ConEmuSize.cpp` - Dark mode state management

## How It Works

The dark mode support in ConEmu:

1. Detects Windows 10 build 17763+ (October 2018 Update) for dark mode support
2. Uses undocumented `uxtheme.dll` ordinal functions to enable dark mode
3. Responds to `WM_SETTINGCHANGE` with `ImmersiveColorSet` to detect theme changes
4. Updates the titlebar and window chrome to match the system theme
5. Supports both light and dark themes based on Windows system preferences

## API Functions Used

The implementation uses these undocumented Windows APIs:
- `ShouldAppsUseDarkMode` (ordinal 132) - Check if dark mode is enabled
- `AllowDarkModeForWindow` (ordinal 133) - Enable dark mode for a window
- `AllowDarkModeForApp` (ordinal 135) - Enable dark mode for the application (pre-1903)
- `SetPreferredAppMode` (ordinal 135) - Set dark mode preference (1903+)
- `RefreshImmersiveColorPolicyState` (ordinal 104) - Refresh color policy
- `IsDarkModeAllowedForWindow` (ordinal 137) - Check if dark mode is allowed

## References

This implementation is based on research and community efforts to enable dark mode in Win32 applications:
- [ysc3839/win32-darkmode](https://github.com/ysc3839/win32-darkmode)
- [Windows dark mode documentation (unofficial)](https://github.com/microsoft/Windows-universal-samples/issues/1052)

## Note

This sample directory can be safely removed from production builds. It serves as a reference for understanding the dark mode implementation that has been integrated into ConEmu.
