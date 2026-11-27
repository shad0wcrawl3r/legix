# Legix

<p align="center"><img src="branding/legix-mark.svg" width="140" alt="Legix logo: a red visor with L-shaped fins and an ember gem"></p>

*Formerly LegionForge.* Website: [legix.shadowcrawler.dev](https://legix.shadowcrawler.dev)

Legix is a custom [Bazzite](https://bazzite.gg) image for handheld gaming PCs. It is built
for the original **Lenovo Legion Go** (Z1 Extreme). Gaming Mode is the same as stock Bazzite.
Desktop Mode is **[niri](https://github.com/YaLTeR/niri)**, a scrolling tiling Wayland
compositor, with the **[Noctalia](https://noctalia.dev)** shell.

- **Base:** `ghcr.io/ublue-os/bazzite-deck-gnome:stable`, rebuilt every day, so you get Bazzite
  and Fedora updates through Legix.
- **Desktop:** niri and Noctalia, from the official Fedora repositories (no COPRs). The one
  exception is Noctalia itself, see below. The GNOME desktop is removed.
- **Signed:** every image is signed with cosign, and the device checks the signature on
  every update (see step 5). The public key is [`cosign.pub`](cosign.pub).

## Required: Noctalia with the lock-screen keyboard

Legix requires a Noctalia build whose lock screen has an on-screen keyboard. The
Legion Go is often used without a physical keyboard, and without this a locked desktop
can't be unlocked at all. Fedora's noctalia doesn't have the feature yet (upstream PR
[noctalia-dev/noctalia#5233](https://github.com/noctalia-dev/noctalia/pull/5233)).

- **Where it comes from:** [shad0wcrawl3r/noctalia-osk](https://github.com/shad0wcrawl3r/noctalia-osk)
  rebuilds Fedora's package with that patch, and Legix installs its signed-provenance
  releases.
- **Enforced by the build:** if the build can't get a verified release, or the result lacks
  the lock-screen keyboard, it fails and no image is published.
- **When the patch retires:** once Fedora's noctalia includes the feature, noctalia-osk
  publishes a release saying so, and Legix goes back to Fedora's package.

## What's different from stock Bazzite

| | Stock Bazzite (Deck, GNOME) | Legix |
|---|---|---|
| Gaming Mode | Steam via OpenGamepadUI | Same |
| Switch to Desktop | GNOME | niri with the Noctalia shell |
| Desktop lock | GNOME's (needs a keyboard to unlock) | Noctalia's lock screen with an on-screen keyboard; locks after 5 minutes idle and before sleep |
| On-screen keyboard in the desktop | GNOME's | Noctalia [Keyboard](https://github.com/noctalia-dev/community-plugins) plugin, from the keyboard button on the bar |
| Heroic Games Launcher (Epic, GOG, Amazon) | Not installed | Installed from Flathub on first boot after switching (needs internet) |
| Bazzite Portal at login | Opens | Doesn't open (it's still in the app launcher) |
| GNOME desktop, extensions, GNOME Settings | Installed | Removed (about 200 MB) |
| NVIDIA/Intel firmware, compilers, ROCm, all languages, Steam's offline bootstrap, CJK input methods (ibus), printing | Installed | Left out: Legix is tuned for the Legion Go (about 3 GB smaller). `ujust legix-extras` adds most back |

You bring your own niri and Noctalia dotfiles. The image only sets a few Noctalia defaults:
a full-width bar, icon-only widgets, the keyboard button, and the lock settings. Your own
files in `~/.config/noctalia/`, and anything you change in Noctalia's Settings, override
them.

## Install

You need a device that already runs **Bazzite Deck with GNOME** (`bazzite-deck-gnome`).
Switching to Legix keeps your games, Steam library, Flatpaks, saves and settings,
because it only replaces the operating system, not your home folder.

> [!IMPORTANT]
> Start from the **GNOME** handheld edition of Bazzite. Switching straight from the KDE
> edition (`bazzite-deck`) fails with `fsetxattr(security.selinux): Invalid argument`,
> because the two editions have different SELinux policies. If you run the KDE edition,
> first switch to `ghcr.io/ublue-os/bazzite-deck-gnome:stable`, reboot, then follow the
> steps below.

### 1. Install Bazzite

Skip this if Bazzite is already installed. Download Bazzite from [bazzite.gg](https://bazzite.gg)
and choose your handheld and the **GNOME** desktop. Install it and finish the first-run setup.

### 2. Check which edition you run

In Desktop Mode, open a terminal (Ptyxis) and run:

```sh
bootc status
```

The `Booted image` line must say `bazzite-deck-gnome`.

### 3. Keep a way back

Pin your current system so it stays in the boot menu as a fallback:

```sh
sudo ostree admin pin 0
```

### 4. Switch to Legix

```sh
sudo bootc switch ghcr.io/shad0wcrawl3r/legix:latest
systemctl reboot
```

The first switch downloads the whole image (about 5 GB). Later updates only download what
changed.

### 5. Turn on signature checking

Your old system didn't know Legix's signing key, so the first switch can't check the
signature. Now that Legix is running, it does. Switch again with signature checking
turned on. This downloads nothing new:

```sh
sudo bootc switch --enforce-container-sigpolicy ghcr.io/shad0wcrawl3r/legix:latest
systemctl reboot
```

From then on, the device refuses any update that isn't signed with Legix's key
([`cosign.pub`](cosign.pub)). `rpm-ostree status` then shows the image as
`ostree-image-signed:docker://ghcr.io/shad0wcrawl3r/legix:latest`, the same way stock Bazzite
shows its own image.

### 6. Set up locking

- **The desktop** locks with Noctalia's lock screen and your account password. Touch the
  screen to bring up its on-screen keyboard.
- **Gaming Mode** is guarded by Steam's PIN. In Gaming Mode, open **Settings → Security** and
  turn on the lock-screen PIN for startup, for waking from sleep and for switching to Desktop
  Mode. Without a PIN, anyone can use Gaming Mode.

## Using it

- **Gaming Mode** works like stock Bazzite.
- **Switch to Desktop** (in the Steam menu) opens niri. The first time, Noctalia's setup
  wizard runs.
- **Noctalia's power menu:**
  - **Lock** shows Noctalia's lock screen. Touch it, or tap the keyboard button next to the
    password box, for the on-screen keyboard. The desktop also locks after 5 minutes idle
    and before sleep.
  - **Gaming Mode (Steam PIN)** leaves the desktop for Gaming Mode, closing its apps.
  - **Lock and suspend** locks, then sleeps.
- **On-screen keyboard:** tap the keyboard button on the bar, then **On-screen keyboard**.

### Commands

| Command | What it does |
|---|---|
| `ujust away` | Go to Gaming Mode now |
| `ujust lock` | Lock the desktop now |
| `ujust legix-extras` | Add back what Legix leaves out: NVIDIA or Intel firmware, compilers, ROCm, all languages, CJK input methods, printing |
| `ujust restore-noctalia-setup` | Back up your Noctalia settings and run its setup wizard again |
| `ujust niri-validate` | Check your niri config for errors |

## Moving from LegionForge

The project and its image were renamed on 2026-11-20. Images are still published as
`ghcr.io/shad0wcrawl3r/legionforge` for now, so existing installs keep updating. Move over in
two steps. The first update teaches the device to trust the new name:

```sh
sudo bootc upgrade && systemctl reboot
sudo bootc switch --enforce-container-sigpolicy ghcr.io/shad0wcrawl3r/legix:latest && systemctl reboot
```

The old name stops getting updates after 2027-01-31.

## Updates

Updates don't install by themselves. Like stock Bazzite's Deck images, Legix leaves that
to Steam, so a download never starts in the middle of a game:

- **System (Legix itself):** in Gaming Mode, open **Settings → System → Check for updates**.
  This installs the newest Legix image. It takes effect after a restart.
- **Apps (Flatpaks):** open **Legix Updater** on the desktop. It updates the system and your
  Flatpaks together. You can also use the **Bazaar** app store.
- **From a terminal:**

  ```sh
  sudo bootc upgrade
  systemctl reboot
  ```

New Legix images are built every day.

## Going back to stock Bazzite

- **Once:** choose the previous entry in the boot menu.
- **Undo the last switch or update:** `sudo bootc rollback`, then reboot.
- **Permanently:** `sudo bootc switch ghcr.io/ublue-os/bazzite-deck-gnome:stable`, then reboot.

Your home folder isn't touched in any of these.

## Known limitations

- Built and tested on the original Legion Go only. Other handhelds that run Bazzite Deck
  GNOME should work but are untested.
- niri's default config expects `alacritty` and `fuzzel`, which aren't installed. Bring
  your own niri config, or use Noctalia's launcher.

## Contributing

`main` is protected. See [CONTRIBUTING.md](CONTRIBUTING.md) for the branch, pull request
and commit conventions, and for the smoke test every build runs.

## Credits

Legix is based on [Bazzite](https://bazzite.gg) ([source](https://github.com/ublue-os/bazzite)),
built with [Universal Blue](https://universal-blue.org)'s
[image-template](https://github.com/ublue-os/image-template). It keeps Bazzite's Gaming Mode,
updates and tools; the name, logo and boot animation are Legix's own. Bazzite's docs and
community still cover most of the system. Licensed under Apache 2.0.

Legix is an independent project. It isn't affiliated with or endorsed by Lenovo, Valve or
the Bazzite project. "Legion Go" is a trademark of Lenovo, used here only to name the
hardware Legix supports.
