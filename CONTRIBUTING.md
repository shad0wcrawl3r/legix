# Contributing

## Workflow

`main` is protected. Nothing is pushed to it directly.

1. Branch from an up-to-date `main`, named `<type>/<short-description>`
   (e.g. `feat/niri-session`, `fix/selinux-switch`).
2. Open a pull request. The PR title must follow
   [Conventional Commits](https://www.conventionalcommits.org): `type(scope): subject`.
3. Wait for the required checks: **Build and push image** and **Lint PR title**.
   Resolve all review conversations.
4. **Squash-merge.** The PR title becomes the single commit on `main` and the
   branch is deleted automatically.

Every merge to `main` triggers a signed image build at
`ghcr.io/shad0wcrawl3r/legix`, so treat merging as releasing.

## Commit / PR title types

| Type       | Use for                                                    |
|------------|------------------------------------------------------------|
| `feat`     | New packages, sessions, services or user-facing behaviour  |
| `fix`      | Fixes to the image or build                                |
| `perf`     | Smaller/faster image or boot                               |
| `refactor` | Restructuring build scripts without behaviour change       |
| `docs`     | README / docs only (does not trigger an image build)       |
| `ci`       | GitHub Actions, Dependabot, Renovate                       |
| `build`    | Containerfile, Justfile, disk/ISO config                   |
| `chore`    | Anything else                                              |
| `revert`   | Reverting a previous change                                |

Subjects are imperative, lowercase, no trailing period:
`feat: add niri and noctalia shell`. Append `!` for changes that need users
to act (e.g. `feat!: switch base to bazzite-deck-gnome`).

## Where files go

- **New Legix files** (scripts, units, configs, theme assets): put them under
  `system_files/` and list them in `%files` of `packaging/legix.spec`.
  The Containerfile's `legix-rpm` stage builds that spec into the `legix` RPM,
  and rpmbuild fails on any file the spec doesn't list. Enable services in
  the spec's preset files, not with `systemctl enable` in `build.sh`.
- **Changes to other packages' files** (os-release, `platform.toml`, Bazzite's
  logos and videos, `policy.json`) stay in `build_files/build.sh`. An RPM
  can't own a file another package already owns.

## Patched Noctalia (lock-screen keyboard)

**This is a hard requirement.** Don't remove the fetch step or the smoke test's lock-screen
keyboard check. Without the feature, a keyboardless Go can't unlock its desktop. Any change to
how Noctalia is installed must keep both.

Legix ships Noctalia with upstream PR #5233 (the lock-screen on-screen keyboard).
The RPM is built and released by
[shad0wcrawl3r/noctalia-osk](https://github.com/shad0wcrawl3r/noctalia-osk), once per
Fedora noctalia version. CI downloads it with `.github/scripts/fetch-noctalia.sh`,
which checks `SHA256SUMS` and the GitHub build-provenance attestation. To change the
patch, open a PR there and bump its `REVISION`.

For a local `just build` with the patch:

```sh
.github/scripts/fetch-noctalia.sh noctalia-rpms
```

Without it, the image uses Fedora's noctalia, and the smoke test's lock-screen
keyboard check fails.

## Smoke test

Every build runs `.github/scripts/smoke-test.sh` before anything is pushed. It
checks:

- the expected packages are installed;
- Switch to Desktop opens niri, and Noctalia is set to start with it;
- no Noctalia settings are shipped, so the first-run wizard appears;
- every SELinux type in the image already exists in the policy of
  `DEVICE_BASE_IMAGE` (set in `build.yml`). That is the image the Legion Go
  switches or upgrades from. If the check fails, `bootc switch` would fail
  on the device with `fsetxattr(security.selinux): Invalid argument`.

If you change the base variant in `Containerfile`, check what the device runs
(`bootc status`) and update `DEVICE_BASE_IMAGE` to match.

## Installer ISO (not distributed)

Legix doesn't build or publish installer ISOs. Users install Bazzite and then
`bootc switch` (see README). A CI ISO build existed briefly. It was dropped on 2026-11-20,
after the first ISO came out at 5.82 GiB, too big to host on a free tier.

`just build-iso` can still build one locally on an x86 Linux machine with podman, from
`disk_config/iso.toml`. Two catches from the CI attempt:
- **Fedora 45 package repos:** bootc-image-builder only reads `/etc/yum.repos.d`, and
  Fedora 45 keeps its repo files in `/usr/share/dnf5/repos.d`. So build it from a derived
  image that copies `fedora.repo` and `fedora-updates.repo` into `/etc/yum.repos.d`.
- **Ubuntu 26.04 hosts:** osbuild fails there with
  `mount: /run/osbuild/tree/dev: permission denied`, but works on Ubuntu 24.04.

## Branding

Legix's name and logo replace Bazzite's wherever the system shows them, and stay out of the
places Bazzite's own tools rely on. `build.sh` (*Legix branding*) does this:
- **os-release:** `NAME`, `PRETTY_NAME`, `LOGO=legix-logo`, the URLs, `BOOTLOADER_NAME` and
  `DEFAULT_HOSTNAME`. `ID` stays `bazzite` on purpose, because ujust, updates and helpers
  check it.
- **image-info.json:** the image name and ref.
- **Logo:** the `legix-logo` icon in every size, rendered from `branding/legix-mark.svg`.
  Bazzite's `logo.svg`, `logo.txt` (fastfetch) and `updatelogo.png` are swapped for Legix's.
- **Terminal:** fastfetch colours, and the welcome banner.
- **Boot animation:** the Plymouth theme.
- **Steam videos:** Gaming Mode's startup and suspend videos, rendered by
  `build_files/branding/render-videos.py`. `legix-steam-videos` replaces users' existing Bazzite copies, and only those.
- **Launcher:** "Bazzite Updater" is renamed "Legix Updater".

Links to Bazzite's docs and community are kept and labelled as Legix's base. The smoke
test checks all of the above.

## Signing key

Images are signed with cosign. `cosign.pub` is committed; the private key is the
`SIGNING_SECRET` repository secret and must never be committed (`cosign.key` is
gitignored).
