# Changelog

## 2.1.1

### Changed
- **Accent folders are no longer a setting** — they are how Ashen looks, so the
  switch in Appearance is gone and `ashen-folders.sh` applies by default
  (`--off` still walks it back).
- **The system board wears the scheme's own colours** — the tones were the
  accent spun round the hue wheel, which produced colours the wallpaper never
  made. They come from the palette now, one to a card, and Thermals no longer
  turns red past 80°: a warm CPU is the panel doing its job.

### Fixed
- **The power menu arrives without a card around it.** A `DropCard` always
  landed on the panel surface, so the four tiles turned up inside a box when
  opened from the pill in transform style — and a plate that is only there
  while it travels is still a box you watch arrive. A plateless panel paints
  none at any point.
- **Fixed colour schemes repaint the folders.** They read the accent from
  `~/.cache/ashen_accent.txt`, which only the dynamic road ever wrote, so the
  folders kept whichever wallpaper wrote it last. A fixed scheme publishes its
  own accent now — which fixes the window border the same way.
- **The bar editor's drop preview stays inside its plate**, anchored to the gap
  instead of straddling it, and the chips step aside to open real room for it.

## 2.1.0

### Added
- **Caps Lock and Num Lock are back on the bar**, as two chips to the left of
  the keyboard layout — in the slot the brightness chip left free. They are not
  lit and unlit: a lock that is off is not a state worth a slot. They arrive in
  two beats — the slot opens, then the chip appears — and leave in the other
  order, so the strip is never seen shoving its neighbours aside.

### Changed
- **The lock state belongs to the keyboard now** — it was polled inside the
  notification service, with a second `hyprctl` of its own. `services/Keyboard.qml`
  reads it off the same call the layout already comes from, and the bar and the
  toasts share that one answer.

## 2.0.2

### Changed
- **The battery dial is a ring again** — the liquid inside it said what the rim
  already said, and left the reading sitting in a puddle.
- **Sliders lost their knob** — sound and every slider in Settings are just the
  bar now: the filled part already says where the value is. The grab area is
  unchanged, it never came from the dot.
- **The brightness panel is gone**, and so is its capsule in the bar — a whole
  card, and a chip of its own, for one number the keys already change. The
  slider moved to the foot of the sound panel, which is the panel you open to
  change a level anyway; Settings → Display still has its own.
- **The OSD fills with a vertical gradient**, down the bar rather than across
  it, and keeps up with a key held down: a reading asked for while the previous
  one was still in flight used to be dropped, and the fill animated over 260 ms
  when the next press was 80 ms away.

### Fixed
- **Updating from an older version actually updates.** `stow` ran all nine
  packages as one transaction, so a single link it did not consider its own —
  one made by hand, or with an absolute path — aborted the lot and the update
  changed nothing but a warning. Links that already point into the repo are
  dropped first and each package is stowed on its own.
- **The GTK palette is regenerated on every setup**, not only when it is
  missing: an update brings new templates, and a machine that already had a
  `gtk.css` kept the one the old templates wrote.
- **`papirus-folders` is no longer called by the installer** — it re-runs itself
  under sudo, which a hardened sudoers refuses, and it only knows the colours
  Papirus ships. The accent folder theme is built instead.

## 2.0.1

### Added
- **Accent folders** — `scripts/ashen-folders.sh` builds an icon theme that
  inherits Papirus and repaints only the folders with the accent of the moment,
  rebuilt whenever the wallpaper moves it. Switched on in Appearance → Folders.
  The four tones are chosen by the accent's luminance, so a light-mode accent
  (which is a dark colour) gets a light emblem instead of Papirus' dark one.

### Fixed
- **GTK apps dissolving into the wallpaper** — Hyprland already draws every
  window at `active_opacity 0.70` with blur behind it, and the generated CSS
  added a second `alpha()` on top. Over a light wallpaper that left the file
  names in Nemo and the portal's file chooser sitting on the picture with
  nothing behind them. The backgrounds are solid now, and the file managers and
  the portal dialog keep a near-opaque window rule of their own.
- **Light mode never reached the apps** — the GTK theme name and the
  colour-scheme preference were written once at install time and pinned to
  dark, so switching Ashen to light left our colours light and `adw-gtk3-dark`
  serving its own dark tones for everything else. `scripts/ashen-gtk-mode.sh`
  now owns both (and Nemo's Cinnamon namespace, which reads its own), and runs
  on every switch.
- **The fixed schemes wrote a different CSS** — the non-dynamic path painted
  windows nearly transparent, wrote only GTK3, and never restarted the portal.
  It now matches the matugen templates, writes GTK4 as well, and hands over to
  the mode script.
- **libadwaita fell back to dark** — every colour name GTK4 could not find used
  its dark default; the missing dozen (`dialog_*`, `shade_color`,
  `sidebar_backdrop_*`, `thumbnail_*`, …) are defined.
- **`xdg-desktop-portal-gtk` was never declared** in the installer or the
  package, though it serves the settings portal to GTK apps and Ashen already
  restarted it.
- **`wlsunset` missing from the package** — the night light had a switch that
  did nothing on a package install.

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
