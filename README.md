# Sim-md's ConEmu fork

ConEmu is a terminal emulator for Windows. It brings multiple console sessions together in one customizable window, with tabs and split panes. You can run Command Prompt, PowerShell, Bash, Far Manager, and other console applications side by side. ConEmu also supports configurable hotkeys, color schemes, and a drop-down terminal that you can show or hide with a shortcut.

This fork adds native Windows ARM64 support, Far Manager integration, Windows theming, and an optional ConPTY mode without ConEmuHk.

## Download

[Download ZIPs for ARM64, x86, and x64](https://github.com/Sim-md/ConEmu/releases). Choose the ZIP for your architecture under **Assets**. GitHub Actions publishes new ZIPs after successful builds and tests on the [main branch](https://github.com/Sim-md/ConEmu/tree/main).

## Build and test

- [GitHub Actions runs](https://github.com/Sim-md/ConEmu/actions/workflows/fork-build.yml)
- [ARM64 build instructions](https://github.com/Sim-md/ConEmu/blob/main/ARM64-BUILD.md)
- [x86 and x64 build commands](https://github.com/Sim-md/ConEmu/blob/main/.github/workflows/fork-build.yml)

## Windows dark mode

On supported Windows 10 and 11 versions, ConEmu can follow Windows app mode or
use a Dark or Light override in **Settings > Appearance**. High contrast uses
the Windows colors. See [ConEmuDark by 59de44955ebd](https://github.com/ConEmu/ConEmu/pull/2604)
for the original main window, Settings and About screenshots, and
[Sim-md's Windows theming](https://github.com/ConEmu/ConEmu/pull/2643).

## License

[BSD 3-Clause](LICENSE).
