# Release Guide

This document outlines the standard procedure for releasing new versions of the **Dashee** macOS application. The process is heavily automated using GitHub Actions.

## 1. Update the Application
First, make your necessary code changes, test them locally, and commit them to the main repository:
```bash
# In the dashee/app repository
git add .
git commit -m "Your feature or bugfix description"
git push origin main
```

## 2. Trigger the Automated Build
We use Git Tags to trigger the GitHub Actions workflow (`.github/workflows/release.yml`). To create a new release (e.g., `v1.0.1`), run:
```bash
# Still in the dashee/app repository
git tag v1.0.1
git push origin v1.0.1
```
> **What happens next?** GitHub Actions will automatically catch this tag, spin up a macOS runner, install Python/PySide6, compile your `.app` using PyInstaller, zip it into `Dashee-macOS.zip`, and attach it to a new GitHub Release page. 

## 3. Update the Homebrew Cask
For users to be able to install the new version via `brew upgrade`, you must update the Homebrew formula.

1. Navigate to your tap repository:
   ```bash
   cd ../homebrew-dashee
   ```
2. Open `Casks/dashee.rb` and update the `version` variable to match your new tag (without the 'v'):
   ```ruby
   version "1.0.1" # Update this line!
   ```
3. Commit and push the updated Cask:
   ```bash
   git add Casks/dashee.rb
   git commit -m "Bump version to 1.0.1"
   git push origin main
   ```

## 4. That's It!
Within minutes, the Homebrew ecosystem will recognize the update. Users can then simply run:
```bash
brew update
brew upgrade --cask dashee
```
