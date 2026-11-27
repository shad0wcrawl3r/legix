#!/usr/bin/env bash
# Smoke-test the built Legix image before it is pushed.
#
# Usage: smoke-test.sh <built-image> <device-base-image>
#   <built-image>        local image to test, e.g. localhost/legix:latest
#   <device-base-image>  the image the Legion Go switches/upgrades FROM. Every
#                        SELinux type the built image labels files with must
#                        already exist in this image's compiled policy, or
#                        `bootc switch` fails on the device with
#                        "fsetxattr(security.selinux): Invalid argument".
set -euo pipefail

IMAGE="$1"
DEVICE_BASE="$2"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
fail=0

in_image() { podman run --rm --pull=never --network=none --entrypoint /bin/bash "$IMAGE" -c "$1"; }

check() {
  if in_image "$2" >/dev/null 2>&1; then
    echo "ok   - $1"
  else
    echo "::error title=Smoke test::$1"
    fail=1
  fi
}

echo "== Legix RPM"
check "Legix's files are owned by the legix RPM and unmodified by build.sh" \
  "rpm -q legix && rpm -V --nomtime legix && test \"\$(rpm -qf --qf '%{NAME}\n' /usr/lib/os-session-select /usr/libexec/legix-away /usr/libexec/legionforge-away /etc/pam.d/noctalia /usr/share/legix/grub-custom.cfg /usr/share/plymouth/themes/legix/gem.png /usr/share/icons/hicolor/256x256/apps/legix-logo.png /usr/lib/systemd/user/legix-steam-videos.service | sort -u)\" = legix"
check "Legix services enabled through the RPM's presets" \
  "test -L /etc/systemd/system/multi-user.target.wants/legix-flatpak-setup.service && test -L /etc/systemd/system/multi-user.target.wants/legix-grub-autohide.service && test -L /etc/systemd/user/default.target.wants/legix-desktop-session.service && test -L /etc/systemd/user/default.target.wants/legix-steam-videos.service"

echo "== Packages and session wiring"
check "packages installed (niri noctalia wtype xwayland-satellite portals)" \
  "rpm -q niri noctalia wtype xwayland-satellite xdg-desktop-portal-gnome xdg-desktop-portal-gtk"
check "niri wayland session exists" \
  "test -f /usr/share/wayland-sessions/niri.desktop"
check "os-session-select override is executable and parses" \
  "test -x /usr/lib/os-session-select && bash -n /usr/lib/os-session-select"
check "os-session-select defaults to niri" \
  "grep -q '^desktop_session=\"niri.desktop\"' /usr/lib/os-session-select"
check "steamos-manager default desktop is niri" \
  "grep -qx 'desktop = \"niri.desktop\"' /usr/share/steamos-manager/platform.toml"
check "noctalia user unit installed" \
  "test -f /usr/lib/systemd/user/noctalia.service"
check "noctalia is pulled in by niri.service" \
  "test \"\$(readlink -f /usr/lib/systemd/user/niri.service.wants/noctalia.service)\" = /usr/lib/systemd/user/noctalia.service"
check "no Noctalia settings shipped (first-run wizard must appear)" \
  "! find /etc/skel /usr/share/noctalia -name settings.toml 2>/dev/null | grep -q ."

check "steamos-manager desktop pinned to niri at login (OpenGamepadUI path)" \
  "test -x /usr/libexec/legix-desktop-session && bash -n /usr/libexec/legix-desktop-session && test -L /etc/systemd/user/default.target.wants/legix-desktop-session.service"

check "Noctalia defaults ship, are valid, and are seeded before Noctalia starts" \
  "noctalia config validate /usr/share/legix/noctalia/00-legix-defaults.toml 2>&1 | grep -q 'Config is valid' && ! noctalia config validate /usr/share/legix/noctalia/00-legix-defaults.toml 2>&1 | grep -q 'unknown setting' && test -x /usr/libexec/legix-noctalia-defaults && grep -q legix-noctalia-defaults /usr/lib/systemd/user/noctalia.service.d/10-legix-defaults.conf"
check "Noctalia wizard state not shipped (wizard must appear on first start)" \
  "! find /etc/skel /usr/share -path '*noctalia*' \\( -name .setup-complete -o -name settings.toml \\) 2>/dev/null | grep -q ."
check "Bazzite Portal does not autostart for new users" \
  "test ! -e /etc/skel/.config/autostart/bazzite-portal.desktop"

check "desk security: Noctalia lock with its on-screen keyboard; Gaming Mode in the power menu" \
  "test -x /usr/libexec/legix-away && bash -n /usr/libexec/legix-away && test ! -e /usr/lib/systemd/user/niri.service.wants/legix-away-on-resume.service && test ! -e /usr/lib/systemd/user/legix-away-on-resume.service && grep -qx 'lock_before_suspend = true' /usr/share/legix/noctalia/00-legix-defaults.toml && grep -qx 'keyboard = \"auto\"' /usr/share/legix/noctalia/00-legix-defaults.toml && grep -A3 '^\\[idle.behavior.lock\\]' /usr/share/legix/noctalia/00-legix-defaults.toml | grep -q 'enabled = true' && grep -q 'Gaming Mode (Steam PIN)' /usr/share/legix/noctalia/00-legix-defaults.toml"

check "on-screen keyboard: plugin enabled, always-visible bar button calls its service" \
  "f=/usr/share/legix/noctalia/00-legix-defaults.toml; grep -q 'enabled = \\[ .omerfuyar/keyboard. \\]' \$f && grep -qE '^ +.legix-osk.,$' \$f && grep -A1 '^\\[widget.legix-osk\\]' \$f | grep -qx 'type = \"custom_button\"' && grep -q 'left = \"exec noctalia msg plugin omerfuyar/keyboard:service all osk\"' \$f && noctalia config validate \$f 2>&1 | grep -q 'Config is valid' && ! noctalia config validate \$f 2>&1 | grep -q 'unknown setting'"

check "Noctalia lock screen has the on-screen keyboard (lockscreen.keyboard setting)" \
  "printf '[lockscreen]\\nkeyboard = \"auto\"\\n' > /tmp/osk.toml && noctalia config validate /tmp/osk.toml 2>&1 | grep -q 'Config is valid' && ! noctalia config validate /tmp/osk.toml 2>&1 | grep -q 'unknown setting'"

echo "== GNOME removed, niri essentials kept"
check "GNOME desktop removed (gdm gnome-shell gnome-session gnome-control-center)" \
  "! rpm -q gdm gnome-shell gnome-session gnome-control-center | grep -qv 'is not installed' && test ! -e /usr/share/wayland-sessions/gnome.desktop"
check "kept: sddm, oo7 password store + PAM unlock, portals, nautilus, VPN dialogs, pinentry, GTK3 theme" \
  "rpm -q sddm oo7-daemon oo7-portal pam_oo7 xdg-desktop-portal-gnome xdg-desktop-portal-gtk nautilus gnome-disk-utility NetworkManager-openvpn-gnome NetworkManager-openconnect-gnome pinentry-gnome3 adw-gtk3-theme"
check "unused GNOME pieces removed (mutter, gnome-settings-daemon, evolution-data-server, docs)" \
  "! rpm -q mutter gnome-settings-daemon evolution-data-server gnome-user-docs gnome-backgrounds gjs | grep -qv 'is not installed'"
check "no leftover GNOME Shell extensions" \
  "test ! -e /usr/share/gnome-shell/extensions"
check "ujust parses and has the Legix recipes" \
  "JUST_JUSTFILE=/usr/share/ublue-os/justfile just --list | grep -q restore-noctalia-setup"
check "no GNOME-only ujust recipes left" \
  "! JUST_JUSTFILE=/usr/share/ublue-os/justfile just --list | grep -qE 'restore-gnome-(de-settings|folders)' && ! JUST_JUSTFILE=/usr/share/ublue-os/justfile just --show restore-virtual-keyboard | grep -q gnome-extensions"

echo "== Boot animation"
check "Legix Plymouth theme installed and set as default" \
  "rpm -q plymouth-plugin-script && grep -qx 'Theme=legix' /etc/plymouth/plymouthd.conf && for f in legix.plymouth legix.script l-left.png l-right.png v.png gem.png gem-glow.png wordmark.png bar.png bar-bg.png; do test -s /usr/share/plymouth/themes/legix/\$f || exit 1; done"
check "initramfs carries the Legix theme, the script plugin and ostree" \
  "i=\$(ls /usr/lib/modules/*/initramfs.img) && l=\$(lsinitrd \"\$i\") && grep -q 'plymouth/themes/legix/legix.script' <<< \"\$l\" && grep -q 'plymouth/script.so' <<< \"\$l\" && grep -q 'ostree-prepare-root' <<< \"\$l\""

echo "== Image signature trust"
check "policy.json trusts ghcr.io/shad0wcrawl3r/legix via sigstore + registries.d attachments" \
  "jq -e '.transports.docker[\"ghcr.io/shad0wcrawl3r/legix\"][0] | .type == \"sigstoreSigned\" and .keyPath == \"/etc/pki/containers/legix.pub\"' /etc/containers/policy.json && grep -q 'use-sigstore-attachments: true' /etc/containers/registries.d/legix.yaml && jq -e '.transports.docker[\"ghcr.io/ublue-os\"]' /etc/containers/policy.json"
if cmp -s <(in_image "cat /etc/pki/containers/legix.pub") cosign.pub; then
  echo "ok   - shipped signing key matches cosign.pub"
else
  echo "::error title=Smoke test::shipped /etc/pki/containers/legix.pub differs from cosign.pub"
  fail=1
fi

check "pre-rename name ghcr.io/shad0wcrawl3r/legionforge still trusted (same key) during the move" \
  "jq -e '.transports.docker[\"ghcr.io/shad0wcrawl3r/legionforge\"][0] | .type == \"sigstoreSigned\" and .keyPath == \"/etc/pki/containers/legix.pub\"' /etc/containers/policy.json && grep -q 'ghcr.io/shad0wcrawl3r/legionforge:' /etc/containers/registries.d/legix.yaml"

echo "== Lean desktop"
check "removed: Waydroid/LXC, Web Apps, Rygel, Help; no stray Bazzite launcher entries" \
  "! rpm -q waydroid lxc webapp-manager rygel yelp | grep -qv 'is not installed' && ! ls /usr/share/applications/{discourse,bazzite-documentation,waydroid-container-restart,bbrew,Waydroid,webapp-manager}.desktop 2>/dev/null | grep -q . && grep -qx NoDisplay=true /usr/share/applications/yad-icon-browser.desktop"
check "Homebrew not set up by default (masked, no tarball, no profile hook)" \
  "test \"\$(readlink /etc/systemd/system/brew-setup.service)\" = /dev/null && test ! -e /usr/share/homebrew.tar.zst && test ! -e /etc/profile.d/brew.sh"
check "Flatpak trim + Zen setup enabled" \
  "test -x /usr/libexec/legix-flatpak-setup && bash -n /usr/libexec/legix-flatpak-setup && test -L /etc/systemd/system/multi-user.target.wants/legix-flatpak-setup.service && grep -q app.zen_browser.zen /usr/libexec/legix-flatpak-setup"
check "niri default config: Noctalia launcher on Mod+Space, Ptyxis terminal, valid" \
  "niri validate -c /etc/niri/config.kdl && grep -q 'Mod+Space .*panel-toggle\" \"launcher' /etc/niri/config.kdl && grep -q 'Mod+T .*ptyxis' /etc/niri/config.kdl && ! grep -q 'spawn-at-startup \"waybar\"' /etc/niri/config.kdl"

check "GRUB menu auto-hide: custom.cfg is valid GRUB script, hook enabled" \
  "grub2-script-check /usr/share/legix/grub-custom.cfg && grep -q 'Installed by legix-grub-autohide' /usr/share/legix/grub-custom.cfg && test -x /usr/libexec/legix-grub-autohide && bash -n /usr/libexec/legix-grub-autohide && test -L /etc/systemd/system/multi-user.target.wants/legix-grub-autohide.service"

check "Bluetooth host privacy off (LE keyboards survive reboots)" \
  "grep -qx 'Privacy=off' /etc/bluetooth/main.conf && ! grep -q '^Privacy=device' /etc/bluetooth/main.conf"

echo "== Trimmed for the Legion Go"
check "trimmed: no cosign/AWS SDK, NVIDIA/Intel firmware, toolchain, ROCm, extra locales, Steam bootstrap, docs" \
  "! rpm -q cosign python3-botocore nvidia-gpu-firmware intel-gpu-firmware iwlwifi-mvm-firmware intel-opencl llvm22-libs gcc kernel-devel rocm-runtime glibc-all-langpacks | grep -qv 'is not installed' && rpm -q glibc-langpack-en && test ! -e /usr/share/gamescope-session-plus/bootstrap_steam.tar.zst && test -z \"\$(ls -A /usr/share/doc)\""
check "second trim: no input methods, printing, OVMF, Intel VA driver, buildah, other Wi-Fi firmware; cups-libs, ghostscript, CJK fonts kept" \
  "! rpm -qa 'ibus*' | grep -q . && ! rpm -q python3-ibus mozc libpinyin-data cldr-emoji-annotation unicode-ucd cups hplip gutenprint edk2-ovmf libva-intel-media-driver cpp buildah atheros-firmware brcmfmac-firmware | grep -qv 'is not installed' && rpm -q cups-libs ghostscript google-noto-sans-cjk-fonts realtek-firmware mt7xxx-firmware && test ! -e /etc/xdg/autostart/ibus-mozc-launch-xwayland.desktop"
check "Gaming Mode stack still intact after the trim (OpenGamepadUI, Steam, 32-bit Mesa, AMD/MediaTek firmware)" \
  "rpm -q opengamepadui gamescope-session-ogui-steam steam mesa-vulkan-drivers.i686 mesa-vulkan-drivers.x86_64 amd-gpu-firmware perl-interpreter embree godot-runner && ls /usr/lib/firmware/mediatek | grep -q ."
check "ujust legix-extras exists and only offers installable groups" \
  "JUST_JUSTFILE=/usr/share/ublue-os/justfile just --show legix-extras | grep -q 'rpm-ostree install' && ! JUST_JUSTFILE=/usr/share/ublue-os/justfile just --show legix-extras | grep -qE 'ScopeBuddy\"|kernel-devel'"

echo "== Legix branding"
check "os-release says Legix (ID stays bazzite for Bazzite's tools) with the Legix logo icon" \
  "grep -qx 'NAME=\"Legix\"' /usr/lib/os-release && grep -qx 'PRETTY_NAME=\"Legix\"' /usr/lib/os-release && grep -qx 'ID=bazzite' /usr/lib/os-release && grep -qx 'LOGO=legix-logo' /usr/lib/os-release && test -s /usr/share/icons/hicolor/scalable/apps/legix-logo.svg && test -s /usr/share/icons/hicolor/256x256/apps/legix-logo.png"
check "image-info, fastfetch logo and welcome banner are Legix" \
  "jq -e '(.\"image-ref\" | endswith(\"ghcr.io/shad0wcrawl3r/legix\"))' /usr/share/ublue-os/image-info.json && grep -q '38;2;229;67;45' /usr/share/ublue-os/bazzite/fastfetch.jsonc && cmp -s /usr/share/ublue-os/bazzite/logo.svg /usr/share/icons/hicolor/scalable/apps/legix-logo.svg && grep -q '^# .*Legix' /usr/share/ublue-os/motd/template.md && grep -q '^Legix' /etc/system-release"
check "image-info keeps Bazzite's image-name/vendor (Deck autologin and handheld setup match on 'deck')" \
  "jq -e '(.\"image-name\" | test(\"deck\")) and .\"image-vendor\" == \"ublue-os\"' /usr/share/ublue-os/image-info.json"
check "Steam startup/suspend videos are Legix's, with the per-user swap for existing Bazzite and older Legix copies" \
  "for f in bazzite.webm bazzite-oled.webm bazzite-suspend.webm bazzite-suspend-oled.webm; do s=\$(md5sum < /usr/share/ublue-os/bazzite/\$f | cut -d' ' -f1); grep -qx \"\$s\" /usr/share/legix/bazzite-video-md5sums && exit 1; done; test \$(wc -l < /usr/share/legix/bazzite-video-md5sums) -ge 2 && test -x /usr/libexec/legix-steam-videos && bash -n /usr/libexec/legix-steam-videos && grep -qx 697755798da9b57a19d55f5b264dcf47 /usr/share/legix/bazzite-video-md5sums && test -L /etc/systemd/user/default.target.wants/legix-steam-videos.service && grep -qx 'Name=Legix Updater' /usr/share/applications/io.github.rfrench3.bazzite-updater.desktop"
check "no Bazzite name left in os-release display fields" \
  "! grep -E '^(NAME|PRETTY_NAME|BOOTLOADER_NAME|DEFAULT_HOSTNAME|LOGO)=' /usr/lib/os-release | grep -qi bazzite"
check "pre-rename paths still work (away script link, seeder removes the old defaults file)" \
  "test \"\$(readlink /usr/libexec/legionforge-away)\" = legix-away && grep -q 'rm -f \"\$dir/00-legionforge-defaults.toml\"' /usr/libexec/legix-noctalia-defaults"

echo "== SELinux types vs device policy (${DEVICE_BASE})"
in_image "cat /etc/selinux/targeted/contexts/files/file_contexts" > "$WORK/file_contexts"
if ! podman image exists "$DEVICE_BASE"; then
  podman pull -q "$DEVICE_BASE" >/dev/null
fi
podman run --rm --pull=never --network=none --entrypoint /bin/bash "$DEVICE_BASE" \
  -c 'cat "$(ls /etc/selinux/targeted/policy/policy.* | sort -V | tail -1)"' > "$WORK/device_policy"

python3 - "$WORK/file_contexts" "$WORK/device_policy" <<'PY' || fail=1
import re, struct, sys
fc, pol = open(sys.argv[1]).read(), open(sys.argv[2], "rb").read()
types = sorted(set(re.findall(r":object_r:([A-Za-z0-9_]+):", fc)))

def defined(name):
    # In a compiled policydb each type symbol is stored as
    # <u32 name length><u32 value><u32 properties><u32 bounds><name>,
    # so check the length field 16 bytes before each occurrence
    # (12 for older policy versions without bounds).
    n = name.encode()
    ln = struct.pack("<I", len(n))
    i = pol.find(n)
    while i != -1:
        if pol[i - 16:i - 12] == ln or pol[i - 12:i - 8] == ln:
            return True
        i = pol.find(n, i + 1)
    return False

# Self-test, so a policy format change can't make this check silently
# pass (or fail) everything.
if not defined("bin_t") or defined("legix_selftest_nonexistent_t"):
    print("::error title=SELinux check self-test failed::cannot parse the device policy; update smoke-test.sh")
    sys.exit(1)
if len(types) < 100:
    print(f"::error title=SELinux check self-test failed::only {len(types)} types parsed from file_contexts")
    sys.exit(1)

missing = [t for t in types if not defined(t)]
print(f"checked {len(types)} file context types, {len(missing)} unknown to the device policy")
for t in missing:
    print(f"::error title=SELinux type unknown to device policy::{t} (bootc switch would fail with fsetxattr EINVAL)")
sys.exit(1 if missing else 0)
PY

if (( fail )); then
  echo "Smoke test FAILED"
  exit 1
fi
echo "Smoke test passed"
