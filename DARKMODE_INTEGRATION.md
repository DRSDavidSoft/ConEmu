# Dark Mode Integration Summary

## Changes Made

This document summarizes the changes made to integrate Windows 10/11 dark mode support into ConEmu.

### 1. Fixed Global Variable Declarations (DwmHelper.h/cpp)

**Problem:** Variables were declared as `extern` with initializers in the header file, which is incorrect C++ syntax.

**Fix:** 
- Removed initializers from `extern` declarations in `DwmHelper.h`
- Added proper definitions with initializers in `DwmHelper.cpp`

```cpp
// DwmHelper.h
namespace global {
    extern bool g_darkModeSupported;
    extern bool g_darkModeEnabled;
    extern DWORD g_buildNumber;
}

// DwmHelper.cpp
namespace global {
    bool g_darkModeSupported = false;
    bool g_darkModeEnabled = false;
    DWORD g_buildNumber = 0;
}
```

### 2. Enabled Dark Mode in About Dialog (AboutDlg.cpp)

**Changes:**
- Uncommented and fixed dark mode initialization code
- Added proper namespace qualification (`global::`)
- Fixed `SetWindowTheme` call to use `gpConEmu->SetWindowTheme()`
- Enabled `WM_CTLCOLORDLG` and `WM_CTLCOLORSTATIC` handlers for dark backgrounds
- Enabled `WM_SETTINGCHANGE` and `WM_THEMECHANGED` handlers for dynamic theme updates

### 3. Main Window Dark Mode Support (ConEmu.cpp)

**Changes:**
- Added dark mode theme change detection in `WM_SETTINGCHANGE` handler
- Updates `g_darkModeEnabled` when system theme changes
- Calls `RefreshTitleBarThemeColor()` to update titlebar
- Calls `_FlushMenuThemes()` to refresh menu appearance

### 4. Fixed Dark Mode State Management (ConEmuSize.cpp)

**Problem:** `DoDarkMode()` was forcing dark mode to always be enabled.

**Fix:** Changed to check system settings:
```cpp
global::g_darkModeEnabled = _ShouldAppsUseDarkMode() && !IsHighContrast();
```

### 5. Fixed Window Creation Dark Mode (ConEmuApp.cpp)

**Problem:** Was forcing dark mode to `true` during window creation.

**Fix:** Changed to respect the current `g_darkModeEnabled` state:
```cpp
_AllowDarkModeForWindow(hWnd, global::g_darkModeEnabled);
```

### 6. Documentation (win32-darkmode/README.md)

Created a README explaining:
- The reference implementation purpose
- How dark mode works in ConEmu
- Where the actual implementation is located
- API functions being used
- References to related projects

## How It Works

1. **Initialization:** When `CDwmHelper` is constructed, `InitDwm()` loads the dark mode API functions from `uxtheme.dll` if running on Windows 10 build 17763+

2. **Detection:** The code checks if dark mode should be enabled using:
   - `_ShouldAppsUseDarkMode()` - System preference
   - `!IsHighContrast()` - High contrast check

3. **Application:** When dark mode is enabled:
   - `_AllowDarkModeForWindow()` is called for main windows and dialogs
   - `RefreshTitleBarThemeColor()` updates the window titlebar
   - `_FlushMenuThemes()` refreshes menu appearance

4. **Dynamic Updates:** The application listens for `WM_SETTINGCHANGE` with `ImmersiveColorSet` parameter to detect theme changes and updates accordingly

## Testing

To test dark mode:
1. Build ConEmu on Windows 10 (version 1809+) or Windows 11
2. Go to Windows Settings → Personalization → Colors
3. Change "Choose your default app mode" between Light and Dark
4. ConEmu's titlebar should update to match the system theme

## Known Limitations

- Dark mode only affects the window titlebar and chrome, not the console content
- Requires Windows 10 October 2018 Update (build 17763) or later
- Some system dialogs may not respect dark mode due to Windows limitations
- Menu appearance depends on Windows version

## Future Enhancements

Potential improvements that could be made:
- Dark themed context menus
- Dark themed scrollbars
- Dark themed dialog backgrounds (partially implemented)
- Custom dark theme for ConEmu's own UI elements
