# Changelog

## 2.0.0

The shell was taken apart and put back together. Everything that used to be a
row of controls is now a panel that arrives, and everything that used to be a
number is now something you can read at a glance. Sixty-odd commits; the parts
that change how Ashen is used:

### Added
- **Multiple monitors** — a 3×3 board arranges the screens, workspaces belong to
  a monitor, and the bar, the panels and the lock screen all appear on every
  screen instead of only the primary one.
- **Panels instead of rows** — every readout opens as a panel that either grows
  out of its own capsule or unfolds where it lives (`Appearance → Panel style`
  picks which). Sound, brightness, battery, network, bluetooth, clock, power and
  the process board were all rebuilt on it.
- **Light mode** — seven light schemes, and text colour chosen by the luminance
  of whatever it sits on rather than by the name of the token.
- **Settings, in tabs** — nine sections with a rail, including a bar layout
  editor, per-app volume, night light (`wlsunset`) and a display arranger.
- **Liquid gauges** — sound, brightness, battery and the system board read as
  vessels filling up, with the swell following the reading.
- **Notifications with a history** — grouped by app, unread marks, working
  D-Bus actions, and a sound of its own.
- **Lock screen in two faces** — at rest it shows the clock, the weather, the
  battery and what is playing; touched, it asks for a password.
- **A package** — Ashen installs as a package (shell to `/etc/xdg/quickshell`)
  instead of only as a checkout.

### Changed
- **One accent, decided once** — `scripts/ashen-accent.sh` picks it by WCAG
  contrast and every consumer (shell, kitty, p10k, btop, Qt, cava, GTK) reads
  that one answer, so nothing disagrees after a wallpaper change.
- **One animation table** — every duration and curve comes from `Sizes`; the
  overshoot is capped and hover is always "grow and brighten", never a fill.
- **The clipboard** — text entries are a grid like the captures, and the
  categories moved to the top of the panel.
- **The utility pill** — a fixed set of tools on every free screen edge.
- The emoji picker, the glyph picker, the quick notes and the caps/num pill were
  retired; the design rules that replaced them are written down in
  `docs/DESIGN.md`.

### Fixed
- **Drop-down lists that could not be clicked** — a floating list drawn outside
  its ancestors is painted but never receives mouse events. The device picker
  now hands its list to the window instead.
- **Toast sweep** — dismissing them all no longer plays half an animation on
  cards that were never on screen, and a card rebuilt mid-exit resumes instead
  of jumping to its last frame.
- **Deleting notifications** — rows commit in their own batch, so a second
  delete no longer postpones the first, and a group's title leaves with its last
  row instead of hanging over nothing.
- **Installer** — `wlsunset` was missing, so the night light silently did
  nothing on a fresh install.

## 1.5.2

### Fixed
- **Installer resilience** — package install no longer aborts wholesale when a
  single package conflicts. `pacman -S` runs everything in one atomic
  transaction, so one bad target (a renamed package, an AUR `-git` variant, or
  a base package like PipeWire that CachyOS ships as a newer `-1.1` rebuild the
  plain repo would "downgrade") used to block every other package. Now the
  batch is tried first and, on failure, each package is installed individually
  so the good ones still land and only the genuine conflicts are skipped and
  reported.

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
