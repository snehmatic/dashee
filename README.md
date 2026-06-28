<p align="center">
  <img src="assets/logo.jpg" alt="Dashee Logo" width="120" style="border-radius: 30px;"/>
</p>

<h1 align="center">Dashee</h1>
<p align="center">
  <strong>Native macOS dashboard for LiteLLM usage pacing</strong>
</p>

<p align="center">
  <a href="https://github.com/snehmatic/dashee/releases">
    <img src="https://img.shields.io/github/v/release/snehmatic/dashee?style=flat-square&color=blue" alt="Release">
  </a>
  <a href="https://github.com/snehmatic/dashee/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/snehmatic/dashee/release.yml?style=flat-square" alt="Build Status">
  </a>
  <img src="https://img.shields.io/badge/macOS-13.0%2B-lightgrey?style=flat-square&logo=apple" alt="macOS 13.0+">
</p>

---

Dashee is a very personal, minimal, native desktop utility for monitoring [LiteLLM Gateway](https://github.com/BerriAI/litellm) API limits and budget pacing. Built entirely in SwiftUI, it runs as a lightweight background agent on macOS.

## Features

- **Background Agent (`LSUIElement`)**: Runs silently in the background without cluttering the Dock or App Switcher.
- **Menu Bar Integration**: Quick access drop-down showing daily spend limits and budget burn progress.
- **Native Charts**: View historical 7-day spend trends natively via Swift Charts.
- **Local Storage**: API credentials and config are saved securely to macOS `UserDefaults`.

## Installation

Install via Homebrew:

```bash
brew tap snehmatic/dashee
brew install --cask dashee
```

## Build from Source

This app is built via `swiftc` without requiring Xcode project files.

```bash
git clone https://github.com/snehmatic/dashee.git
cd dashee
make build
```
The compiled bundle will be available in the `dist/` directory.

## Documentation

For deployment workflows and release instructions, refer to the [Release Guide](RELEASE_GUIDE.md).

## License

[Apache License 2.0](LICENSE)
