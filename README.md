# Dashee - LiteLLM Pacing & Usage Metrics Dashboard

Dashee is a premium, native macOS desktop application for monitoring LiteLLM Gateway usage and budget pacing. Built with PySide6, it features an elegant, Apple HIG-inspired user interface with fluid loading states and dynamic color thresholds for budget pacing.

## Features
- **Native macOS Experience:** Clean typography, generous padding, and sleek container cards.
- **Dynamic Pacing Indicator:** Visual budget burn progress shifting from Green to Yellow to Red.
- **Velocity Tracking:** Tracks historical average spend and prevents daily overruns.
- **Local & Secure:** Runs completely decoupled from a browser context. Credentials are saved locally on your Mac.

## Quick Start & Installation

You can install Dashee directly via Homebrew!

```bash
# Add the custom tap
brew tap snehashish/dashee

# Install the app
brew install --cask dashee
```
*(Note: Replace `snehashish` with your GitHub username once the repos are pushed!)*

Once installed, simply open **Dashee** from your Applications folder or Spotlight.

## Manual Build Instructions

If you wish to build the app from source:

1. Clone this repository:
   ```bash
   git clone https://github.com/snehashish/dashee.git
   cd dashee
   ```
2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Build the macOS `.app` bundle:
   ```bash
   make build
   ```
   The `Dashee.app` file will be generated in the `dist/` directory.

## Configuration
When you first run Dashee, click the **Settings** button to provide:
- Your LiteLLM Base URL
- Your API Key
- Your User ID

These credentials are securely stored in `~/Library/Application Support/Dashee/config.json`.
