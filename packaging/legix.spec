# Legix's own files, packaged so rpm owns them: `rpm -qf` names them, `rpm -V
# legix` checks them, and a file dropped from the package disappears from the
# image instead of lingering. Built in the Containerfile's legix-rpm stage.
#
# Only files no other package owns go here. Edits to Bazzite's or Fedora's
# files (os-release, platform.toml, the Steam videos, fastfetch, policy.json)
# stay in build_files/build.sh.
#
# Sources (in %{_sourcedir}):
#   system_files/      the tree installed under /
#   plymouth/*.png     boot animation parts (rendered in branding-assets)
#   icons/<size>.png   logo icons (rendered in branding-assets)
#   legix-mark.svg     scalable logo

%global legix_version %{?legix_build_version}%{!?legix_build_version:0}

Name:           legix
Version:        %{legix_version}
Release:        1%{?dist}
Summary:        Legix system files: session wiring, services, boot theme, branding
License:        Apache-2.0
URL:            https://github.com/shad0wcrawl3r/legix
BuildArch:      noarch

BuildRequires:  systemd-rpm-macros
Requires:       plymouth-plugin-script
%{?systemd_requires}

%description
Legix's own files for the Legion Go image: Steam's Switch to Desktop override,
login-time services, Noctalia defaults and lock-screen PAM service, the GRUB
auto-hide hook, image signature lookup, ujust recipes, the Plymouth boot
theme and the Legix logo icons.

%install
cp -a %{_sourcedir}/system_files/. %{buildroot}/
find %{buildroot} -name .gitkeep -delete
find %{buildroot} -depth -type d -empty -delete

chmod 0755 %{buildroot}%{_libexecdir}/legix-* %{buildroot}/usr/lib/os-session-select
# Pre-rename name, in case a user's own Noctalia config still calls it.
ln -s legix-away %{buildroot}%{_libexecdir}/legionforge-away

install -m0644 %{_sourcedir}/plymouth/*.png %{buildroot}%{_datadir}/plymouth/themes/legix/

install -Dm0644 %{_sourcedir}/legix-mark.svg \
    %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/legix-logo.svg
for png in %{_sourcedir}/icons/*.png; do
    size="$(basename "$png" .png)"
    install -Dm0644 "$png" "%{buildroot}%{_datadir}/icons/hicolor/${size}x${size}/apps/legix-logo.png"
done
install -Dm0644 %{_sourcedir}/icons/256.png %{buildroot}%{_datadir}/pixmaps/legix-logo.png

# Enable the services through presets, the Fedora way: %%post applies them on
# first install.
install -Dm0644 /dev/stdin %{buildroot}%{_presetdir}/50-legix.preset <<'EOF'
enable legix-flatpak-setup.service
enable legix-grub-autohide.service
EOF
install -Dm0644 /dev/stdin %{buildroot}%{_userpresetdir}/50-legix.preset <<'EOF'
enable legix-desktop-session.service
enable legix-steam-videos.service
EOF

%post
%systemd_post legix-flatpak-setup.service legix-grub-autohide.service
%systemd_user_post legix-desktop-session.service legix-steam-videos.service

%preun
%systemd_preun legix-flatpak-setup.service legix-grub-autohide.service
%systemd_user_preun legix-desktop-session.service legix-steam-videos.service

%files
%{_libexecdir}/legix-*
%{_libexecdir}/legionforge-away
/usr/lib/os-session-select
%config(noreplace) %{_sysconfdir}/pam.d/noctalia
%config(noreplace) %{_sysconfdir}/containers/registries.d/legix.yaml
%{_datadir}/legix/
%{_datadir}/ublue-os/just/60-custom.just
%{_unitdir}/legix-*.service
%{_userunitdir}/legix-*.service
%dir %{_userunitdir}/noctalia.service.d
%{_userunitdir}/noctalia.service.d/10-legix-defaults.conf
%{_presetdir}/50-legix.preset
%{_userpresetdir}/50-legix.preset
%{_datadir}/plymouth/themes/legix/
%{_datadir}/icons/hicolor/*/apps/legix-logo.*
%{_datadir}/pixmaps/legix-logo.png
