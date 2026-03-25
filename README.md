# Jitouch

Jitouch is an open source macOS gesture utility for trackpads and Magic Mouse.

This repository is in the middle of a large modernization effort:

- legacy Objective-C and prefPane code is being migrated into a standalone Swift app
- the new app is menu bar based, editable, and designed for modern high-DPI macOS setups
- build output is fixed inside the repository so local testing and Accessibility re-authorization are easier

The current Swift app lives in `JitouchApp/`. The legacy source is still kept in `jitouch/` while feature parity work continues.

## Current Status

The standalone app already includes:

- menu bar app shell
- editable settings UI
- per-app gesture overrides
- runtime services for touch devices and event taps
- command execution, character recognition diagnostics, and onboarding flows

What still needs real hardware validation is mostly threshold tuning, feel, and remaining parity gaps from the old app.

## Requirements

- macOS 15.0 or later for development builds
- Xcode 26 or newer recommended
- `xcodegen` installed

Install XcodeGen with Homebrew if needed:

```bash
brew install xcodegen
```

## Build And Run

Generate the Xcode project:

```bash
cd /Users/lusheng/Documents/开发/Jitouch
xcodegen generate
```

### Run With Xcode

```bash
open /Users/lusheng/Documents/开发/Jitouch/Jitouch.xcodeproj
```

Then choose the `Jitouch` scheme and run on `My Mac`.

### Run From Terminal

```bash
cd /Users/lusheng/Documents/开发/Jitouch
xcodegen generate
xcodebuild -project Jitouch.xcodeproj -scheme Jitouch -configuration Debug CODE_SIGNING_ALLOWED=NO build
open /Users/lusheng/Documents/开发/Jitouch/build/Debug/Jitouch.app
```

The app bundle is intentionally emitted to:

`/Users/lusheng/Documents/开发/Jitouch/build/Debug/Jitouch.app`

## Accessibility Permission

Jitouch needs Accessibility permission for event taps, shortcut simulation, and window actions.

If macOS asks you to authorize it again, remove the old entry and re-add the current app bundle from:

`/Users/lusheng/Documents/开发/Jitouch/build/Debug/Jitouch.app`

Unsigned debug builds created with `CODE_SIGNING_ALLOWED=NO` may require re-authorization more often.

## Repository Layout

- `JitouchApp/` - new standalone Swift app
- `jitouch/` - legacy Objective-C code and historical project files
- `REFACTOR_TASKS.md` - modernization backlog and migration notes
- `project.yml` - XcodeGen source of truth

## License

This project is distributed under the GNU General Public License v3.0. See [LICENSE](LICENSE).
