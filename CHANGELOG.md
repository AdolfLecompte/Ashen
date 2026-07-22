# Changelog

## 1.5.1

### Fixed
- **Portability** — every path now resolves from `$HOME` at runtime instead of
  the hardcoded `/home/adolf`, and the install-time `sed` that rewrote the
  working tree is gone. `git pull` no longer dirties the tree or conflicts on
  each release, and paths that pointed at the repo checkout (glyph data,
  `general.lua`, `input.lua`) now use the stowed `~/.config` location, so they
  hold wherever the repo was cloned.

## 1.5.0

### Added
- **Audio device picker** — choose the output (speakers / headphones / HDMI)
  and input (microphone) from the volume panel and **Settings → System**, like
  Noctalia. Switching moves already-running streams, so it takes effect at once.
- **Cycle workspaces** with `SUPER + CTRL + ←/→` (next / previous, same
  monitor).
- Installer now adds the user to the `video` group so the webcam works out of
  the box.

### Changed
- The Bluetooth panel device list caps at 5 rows and scrolls past that instead
  of overflowing.

### Fixed
- Discord notifications now show the Discord icon instead of a generic Material
  glyph (icons resolve by app name when no `appIcon` is sent).
