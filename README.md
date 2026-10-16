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
Shortcut Coach needs macOS 15 or later. Install it either way below.

**Download the disk image**
1. Download **[ShortcutCoach.dmg](https://github.com/darryl-paystar/ShortcutCoach/releases/latest/download/ShortcutCoach.dmg)**, the latest release, and open it.
2. Drag **Shortcut Coach** onto **Applications**, then eject the disk image.
3. Open Shortcut Coach from Applications. macOS blocks this first launch, because the app is signed with a self-signed certificate rather than an Apple Developer ID. Click **Done**.
4. Open **System Settings → Privacy & Security**, scroll down to **Security**, and click **Open Anyway** next to “Shortcut Coach was blocked”. Confirm with your password or Touch ID, then click **Open**.

You only do this once; updates open normally.

**Or use Terminal**
```bash
curl -fsSL https://raw.githubusercontent.com/darryl-paystar/ShortcutCoach/main/scripts/install.sh | bash
```
This puts the latest release in `~/Applications` and opens it, with no Open Anyway step: `curl` downloads aren't quarantined, and the script checks the app's signature before installing.

**After installing**, the welcome tour asks for **Accessibility** access, which the app needs to see clicks and menus. From then on it keeps itself up to date. Every hour it checks for a new release and downloads it in the background. When one is ready, a toast offers **Install and Relaunch**, and the menu-bar icon gets a dot. The same option is at the top of the menu-bar menu, on Overview and in Settings → Updates. If you leave it, the update installs the next time you quit.

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
Every push to `main` that changes the app (`Sources/`, `Resources/`, `Package.swift`, `scripts/build.sh`) runs [the release workflow](.github/workflows/release.yml). It builds a universal app, signs it with the release certificate, and publishes a GitHub release `v0.1.<commit count>` with `ShortcutCoach.dmg` for installing by hand, `ShortcutCoach.zip` (which updates and `install.sh` download), and a Sparkle `appcast.xml`. Installed copies read `releases/latest/download/appcast.xml` and offer the update once it's downloaded. To bump the major or minor version, edit `CFBundleShortVersionString` in `Resources/Info.plist`. The workflow can also be run by hand from the Actions tab.

Repository secrets:
- `SIGNING_CERT_P12` and `SIGNING_CERT_PASSWORD` hold the "Shortcut Coach Release Signing" identity, base64-encoded. Keep it: a build signed by anything else loses every user's Accessibility grant, and `install.sh` refuses it.
- `SPARKLE_PRIVATE_KEY` signs updates. Its public half is `SUPublicEDKey` in `Info.plist`. A copy is in the maintainer's keychain: `generate_keys --account ShortcutCoach -x key.txt` exports it.

## Privacy
Everything stays local apart from the hourly update check, which fetches the release feed from GitHub and sends nothing about you. Keystrokes are only checked for modifier combos and navigation keys, and typed text is never stored. Stats: `~/Library/Application Support/ShortcutCoach/stats.json`. Log: `~/Library/Logs/ShortcutCoach.log`. Click details are logged only when Debug logging is on.
