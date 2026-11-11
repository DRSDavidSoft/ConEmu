# Sim-md's ConEmu fork

This fork adds native Windows ARM64 support, Far Manager integration, Windows theming, and an optional ConPTY mode without ConEmuHk. GitHub Actions builds and tests Windows ARM64, x86, and x64 and publishes ZIPs after a successful run.

- [Download ARM64, x86, and x64 ZIPs](https://github.com/Sim-md/ConEmu/releases)
- [Fork CI status and logs](https://github.com/Sim-md/ConEmu/actions/workflows/fork-build.yml)
- [ARM64 build instructions](https://github.com/Sim-md/ConEmu/blob/conemu-arm64-nohooks/ARM64-BUILD.md)
- [x86 and x64 MSBuild commands](https://github.com/Sim-md/ConEmu/blob/conemu-arm64-nohooks/.github/workflows/fork-build.yml)
- [Original ConEmu repository](https://github.com/ConEmu/ConEmu)

The fork's builds use the [conemu-arm64-nohooks branch](https://github.com/Sim-md/ConEmu/tree/conemu-arm64-nohooks).

## About the original ConEmu

[ConEmu-Maximus5](https://conemu.github.io) is a Windows console emulator with tabs, which represents
multiple consoles as one customizable GUI window with various features.

Initially, the program was created as a companion to
[Far Manager](http://en.wikipedia.org/wiki/FAR_Manager),
my favorite shell replacement - file and archive management,
command history and completion, powerful editor.

ConEmu can also be used with other console applications and simple GUI tools
such as PuTTY. See the [original ConEmu issue tracker](https://github.com/ConEmu/ConEmu/issues).

<a href="https://www.fosshub.com/ConEmu.html">![Original ConEmu downloads on FossHub](https://github.com/Maximus5/ConEmu/wiki/downloads-new.png)</a>
<a href="https://conemu.github.io/donate.html">![Donate to the original ConEmu project](https://github.com/Maximus5/ConEmu/wiki/donate-new.png)</a>

Take a look at [screencast](http://dotnetsurfers.com/blog/2013/12/15/developer-tools-screencast-7-conemu/) about ConEmu.

This fork grew up from ConEmu by Zoin.


## License (BSD 3-clause)
    THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
    IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
    OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.

See [Release/ConEmu/License.txt](Release/ConEmu/License.txt) for the full license text.


## Original ConEmu documentation and links
Wiki: https://conemu.github.io/en/TableOfContents.html
What's new: https://conemu.github.io/en/Whats_New.html
Release stages: https://conemu.github.io/en/StableVsPreview.html
Donate to the original ConEmu project: <a ref="https://conemu.github.io/donate.html" rel="nofollow">https://conemu.github.io/donate.html</a>



## Description
ConEmu starts a console program in hidden console window and provides
an alternative customizable GUI window with various features:

  * smooth window resizing;
  * tabs and splits (panes);
  * easy run old DOS applications (games) in Windows 7 or 64bit OS (DosBox required);
  * quake-style, normal, maximized and full screen window graphic modes;
  * window font anti-aliasing: standard, clear type, disabled;
  * window fonts: family, height, width, bold, italic, etc.;
  * using normal/bold/italic fonts for different parts of console simultaneously;
  * cursor: standard console (horizontal) or GUI (vertical);
  * and more, and more...

### Far Manager related features
  * tabs for editors, viewers, panels and consoles;
  * thumbnails and tiles;
  * show full output (1K+ lines) of last command in editor/viewer;
  * customizable right click behaviour (long click opens context menu);
  * drag and drop (explorer style);
  * and more, and more...

All settings are read from the registry or ConEmu.xml file, after which the
[original ConEmu command-line documentation](https://conemu.github.io/en/CommandLine.html)
are applied. You may easily use several named configurations (for different PCs for example).


## Requirements
  * Windows XP or later for 32-bit.
  * Windows Vista or later for 64-bit.


## Installation
In general, ConEmu installation is easy.
Just unpack or install to any folder and run `ConEmu.exe`.

Read the [original ConEmu installation guide](https://conemu.github.io/en/Installation.html)
about release stages, distro packets, some warnings and much more...


## Building the original ConEmu from source
[Original build guide](https://github.com/ConEmu/ConEmu/blob/master/src/HowToBuild.md)

## Screenshots from the original ConEmu
![Splits and tabs in ConEmu](https://github.com/Maximus5/ConEmu/wiki/ConEmuSplits.png)

![ConEmu+Powershell inside Windows Explorer pane](https://github.com/Maximus5/ConEmu/wiki/ConEmuInside.png)

[More screenshots](https://conemu.github.io/en/Screenshots.html)
