# Shortcut Coach

A menu-bar app that teaches macOS shortcuts the way Key Promoter X does in JetBrains IDEs: do something with the mouse that has a shortcut, get a toast telling you the shortcut.

## What it catches
- **Menu items** chosen with the mouse (menu bar and right-click menus) → their shortcut
- **Toolbar buttons** that match a menu command (Finder back/forward/view modes, browser reload, new tab…)
- **Window buttons**: close → ⌘W, minimize → ⌘M, green → ⌃⌘F / tiling
- **Dialog buttons**: default → ↩, Cancel → ⎋
- **Dock**: clicking a running app → ⌘⇥, launching one → ⌘Space
- **Browsers**: clicking tabs → ⌘1…9 / ⌃⇥, clicking the address bar → ⌘L
- **Finder**: sidebar → ⇧⌘H / ⌥⌘L…, F2 → ↩, Delete → ⌘⌫, Return-then-Esc → ⌘↓
- **Windows habits**: Ctrl+C/V/X/Z/Y/S/A/F/W/T/R, Alt+F4, Alt+Tab, Ctrl+←/→, Ctrl+Backspace, Home/End, Ctrl+Shift+Esc
- **Text editing**: holding arrows or ⌫ → ⌥←/→, ⌘←/→, ⌥⌫
- Menu items you keep choosing that **have no shortcut** → how to assign one in System Settings

It also counts how often you then **use** each shortcut and celebrates when one sticks.

**Hold ⌘** for about a second in any app to see an overlay of all its menu shortcuts. The main window has live per-app shortcut lists, cheat sheets, a Windows → Mac table and tips.

## Install
Needs macOS 15 or later. In Terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/darryl-paystar/ShortcutCoach/main/scripts/install.sh | bash
```
This puts the latest release in `~/Applications` and opens it. The welcome tour then asks for **Accessibility** access, which the app needs to see clicks and menus. After that it updates itself: it checks for a new release every hour and installs it in the background while its window is closed. You can turn that off in Settings → Updates.

The app is signed with a self-signed certificate rather than an Apple Developer ID. If you download `ShortcutCoach.zip` from [Releases](https://github.com/darryl-paystar/ShortcutCoach/releases) by hand instead, macOS blocks the first launch. Choose **System Settings → Privacy & Security → Open Anyway**. The script avoids this because `curl` downloads aren't quarantined, and it checks the app's signature before installing.

## Build from source
```bash
scripts/build.sh --install
```
This builds `build/Shortcut Coach.app`, copies it to `~/Applications` and launches it. Then grant **System Settings → Privacy & Security → Accessibility → Shortcut Coach**.

`build.sh` signs with the first of these it finds in your keychain:
1. **Shortcut Coach Release Signing**, the identity releases use. Local builds and releases then share one Accessibility grant.
2. **Shortcut Coach Local Signing**.
3. Otherwise ad-hoc. Every rebuild then changes the signature, so Shortcut Coach has to be removed (−) and re-added in the Accessibility list each time.

`SIGN_IDENTITY` overrides the choice. Neither certificate needs to be trusted, because the Accessibility grant pins the certificate's hash. That grant belongs to one certificate, though. After switching to a build signed with a different one, clear it and grant again:
```bash
tccutil reset Accessibility local.shortcutcoach
```

Self-test (live Finder menus, key parsing, preview PNGs):
```bash
.build/arm64-apple-macosx/release/ShortcutCoach --selftest /tmp/previews
```

## Releases
Every push to `main` that changes the app (`Sources/`, `Resources/`, `Package.swift`, `scripts/build.sh`) runs [the release workflow](.github/workflows/release.yml). It builds a universal app, signs it with the release certificate, and publishes a GitHub release `v0.1.<commit count>` with `ShortcutCoach.zip` and a Sparkle `appcast.xml`. Installed copies read `releases/latest/download/appcast.xml`. To bump the major or minor version, edit `CFBundleShortVersionString` in `Resources/Info.plist`. The workflow can also be run by hand from the Actions tab.

Repository secrets:
- `SIGNING_CERT_P12` and `SIGNING_CERT_PASSWORD` hold the "Shortcut Coach Release Signing" identity, base64-encoded. Keep it: a build signed by anything else loses every user's Accessibility grant, and `install.sh` refuses it.
- `SPARKLE_PRIVATE_KEY` signs updates. Its public half is `SUPublicEDKey` in `Info.plist`. A copy is in the maintainer's keychain: `generate_keys --account ShortcutCoach -x key.txt` exports it.

## Privacy
Everything stays local apart from the hourly update check, which fetches the release feed from GitHub and sends nothing about you. Keystrokes are only checked for modifier combos and navigation keys, and typed text is never stored. Stats: `~/Library/Application Support/ShortcutCoach/stats.json`. Log: `~/Library/Logs/ShortcutCoach.log`. Click details are logged only when Debug logging is on.
