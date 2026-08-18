# Ashen

A monochrome Hyprland + Quickshell rice.

Hyprland · Quickshell · Kitty · Zsh + Powerlevel10k · PipeWire · matugen

---

## What's in it

A Quickshell shell (`quickshell/`) providing the bar, the panels and the lock
screen, driven by a Hyprland config written in **Lua** (`hypr/`).

- **Bar** — launcher, notifications, workspaces (incl. special workspaces), media,
  clock, tray, USB, screen recording, keyboard layout, network, bluetooth, volume,
  brightness, battery, power.
- **Panels** — every pill opens a panel that slides out and slides back in reverse.
- **Lock screen** — own `WlSessionLock` surface: padlock intro animation, PAM auth,
  blurred wallpaper, media card with a live Cava visualiser, battery + power profiles.
- **Launcher, clipboard, emoji picker, glyph picker, settings, wallpaper picker.**
- **Dynamic theming** — the wallpaper picker runs `matugen` over the chosen image and
  the whole shell re-colours from `~/.cache/ashen_scheme.json`.

## Requires

Everything below is what the shell actually shells out to. Missing one degrades a
specific feature rather than breaking the shell, except where noted.

### Official repos

```
hyprland kitty zsh stow git base-devel
qt6-base qt6-declarative qt6-5compat
quickshell
pipewire pipewire-pulse pipewire-alsa wireplumber libpulse
networkmanager bluez bluez-utils udisks2 upower power-profiles-daemon
brightnessctl lm_sensors pciutils
wl-clipboard cliphist grim slurp wf-recorder
hypridle mpvpaper ffmpeg wlsunset
nemo zenity fastfetch cava xdg-utils libnotify
papirus-icon-theme adw-gtk-theme
ttf-jetbrains-mono-nerd ttf-material-symbols-variable
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk polkit-gnome
```

`qt6-5compat` is **required**, not optional: the shell imports
`Qt5Compat.GraphicalEffects` for the blur and the rounded image masks.

### AUR (via `paru`, `yay`, …)

```
awww matugen grimblast-git
papirus-folders bibata-cursor-theme
```

- **quickshell** must be built with **PAM** and the **Hyprland** modules — the lock
  screen authenticates through `PamContext` (config `login`) and the bar reads
  workspaces over Hyprland IPC. `quickshell-allflags-git` also works.
- **ttf-material-symbols-variable** is required: every icon in the shell is a
  Material Symbols Rounded codepoint. Without it the bar renders empty boxes.
- **awww** paints static images and gifs, **mpvpaper** paints video wallpapers.

Plus [Oh My Zsh](https://ohmyz.sh) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k),
which are not packaged — follow their own install instructions.

### What each command is used for

| Command | Feature that needs it |
|---|---|
| `hyprctl` | workspaces, window rules, keyboard layout switching |
| `wpctl` / `pactl` | volume, mute, output device, headphone detection |
| `brightnessctl` | brightness pill and OSD |
| `nmcli` | wifi/ethernet pill and network panel |
| `bluetoothctl` | bluetooth pill and panel |
| `powerprofilesctl` | power profile switcher (bar, settings, lock screen) |
| `upower` | battery time-remaining estimate |
| `udisksctl` / `lsblk` | USB pill: mount, unmount, eject |
| `cliphist` + `wl-copy` / `wl-paste` | clipboard history panel |
| `grimblast` | screenshots |
| `wf-recorder` + `ffmpeg` | screen recording pill |
| `cava` | audio visualiser (bar background, media panel, lock screen) |
| `awww` / `mpvpaper` / `matugen` | wallpapers and dynamic colour scheme |
| `hypridle` | idle → lock |
| `wlsunset` | night light (blue-light filter), manual and scheduled |
| `lm_sensors` | temperatures in the process panel |
| `nvidia-utils` (`nvidia-smi`) | dGPU stats — **only** read when the GPU is already awake |

## Install

```bash
git clone https://github.com/AdolfLecompte/Ashen.git ~/ashen
cd ~/ashen
bash scripts/setup-system.sh
```

`setup-system.sh` installs the packages, symlinks the configs with `stow`, creates
the XDG folders, applies the GTK/icon/cursor settings and offers to enable the
system services. It is safe to re-run — see [Update](#update). Flags:

| Flag | Effect |
|---|---|
| `--no-packages` | skip installing anything |
| `--no-stow` | skip symlinking the configs |
| `--no-services` | skip `systemctl enable` |
| `--no-pull` | skip the self-update (don't `git pull` the repo) |
| `-y`, `--yes` | never prompt |

To do it by hand instead:

```bash
stow -t ~ cava dconf fastfetch gtk hypr kitty matugen quickshell zsh
```

Then set Zsh as your shell (`chsh -s $(which zsh)`), enable `NetworkManager`,
`bluetooth` and `power-profiles-daemon`, and start the Hyprland session from your
display manager or TTY.

> **Clone to `~/ashen`.** `scripts/` is deliberately *not* stowed — the shell calls
> those scripts by absolute path (`$HOME/ashen/scripts/ashen-wallpaper.sh`), so the
> repo has to live at `~/ashen`.

> **The configs are stow-symlinked.** Editing `~/.config/hypr/…` or
> `~/.config/quickshell/ashen/…` edits the repo directly — there is no second copy
> to keep in sync.

> **XDG folders.** If your locale created localized user folders (`~/Imágenes`
> instead of `~/Pictures`), create the English ones too — the scripts expect
> `~/Pictures/Wallpapers`, `~/Pictures/Screenshots` and `~/Videos` literally,
> whatever the system language. `setup-system.sh` does this for you.

## Update

**To update Ashen, just re-run the setup:**

```bash
bash ~/ashen/scripts/setup-system.sh
```

It pulls the latest repo, and if anything changed it re-runs itself with the new
version — so new configs **and** any new packages they need are applied in one
pass (a `git pull` alone can leave the shell half-updated and broken). It also
refreshes Oh My Zsh + Powerlevel10k + plugins, regenerates the GTK palette from
the current wallpaper (an update usually brings new templates) and reloads
Quickshell. Nothing is reinstalled if it's already current. The self-update is
skipped automatically if you have local changes in the repo (pass `--no-pull` to
force-skip it).

If you use one of the **fixed colour schemes** instead of Dynamic, pick it again
in Settings → Appearance once after updating: that palette is written by the
shell, so the setup script cannot regenerate it for you.

### Coming from a much older version

Installs from before **1.5.1** rewrote the working tree at install time (an
install-time `sed` that is long gone), so their clone is dirty — and a dirty
tree is exactly what makes the self-update above skip itself, quietly leaving
you on the old code. Throw those local edits away first:

```bash
cd ~/ashen
git status                       # anything listed here is about to be discarded
git fetch origin
git reset --hard origin/main     # or `git stash` if you actually wrote something
bash scripts/setup-system.sh
```

Two things to expect on that first run:

- **stow may report a conflict for a package.** That means a real file — not a
  symlink — is sitting where a config belongs; `~/.zshrc` is the usual one.
  Move it aside (`mv ~/.zshrc ~/.zshrc.mine`) and re-run. Only the package that
  conflicts is skipped, the other eight still land.
- **Log out and back in** afterwards if the bar looks half-dressed: an old
  session is still holding the previous Hyprland config and the old
  environment.

## Usage

| Keys | Action |
|---|---|
| `SUPER` (tap) | launcher |
| `SUPER + SHIFT + W` | wallpaper picker (drives dynamic theming) |
| `SUPER + I` | settings |
| `SUPER + T` | terminal |

The keyboard layout pill in the bar is **read-only**. Layouts are declared in
`hypr/.config/hypr/conf/input.lua` (`kb_layout = "us"`) and switched from
**Settings → System → Keyboard**.

## Notes

- The Hyprland config is **Lua** (`hyprland.lua` + `conf/*.lua`), not `hyprland.conf`.
  `hyprctl keyword` does **not** work against it — use `hyprctl eval '<lua>'` to try
  things at runtime.
- Shell IPC: `qs -c ashen ipc show` lists every callable target.
- Reload the shell with `pkill quickshell; setsid nohup quickshell -c ashen &`.
- Window opacity: a `windowrule` opacity value is **multiplied** by
  `active_opacity`/`inactive_opacity` unless you append `override`. That is why the
  browser rule reads `opacity 0.85 override 0.80 override`.

## Status

2.1.1

## License

MIT — see [LICENSE](LICENSE).
