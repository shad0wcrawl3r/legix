# Legix branding: render the boot-animation parts (branding/plymouth/*.svg)
# and the logo icons (branding/legix-mark.svg) to PNG here, so rsvg-convert
# is never installed in the image.
FROM registry.fedoraproject.org/fedora:45 AS branding-assets
COPY branding /branding
COPY build_files/plymouth/render.sh /render.sh
COPY build_files/branding/render-videos.py /render-videos.py
RUN --mount=type=cache,dst=/var/cache/libdnf5 dnf5 -y install librsvg2-tools ffmpeg-free python3-pillow \
 && /render.sh /branding /out \
 && mkdir -p /out/videos && python3 -I /render-videos.py /branding/ChakraPetch-Bold.ttf /out/videos

# Legix's own files as an RPM (packaging/legix.spec), so rpm owns them.
FROM registry.fedoraproject.org/fedora:45 AS legix-rpm
RUN --mount=type=cache,dst=/var/cache/libdnf5 dnf5 -y install rpm-build systemd-rpm-macros
COPY packaging/legix.spec /src/legix.spec
COPY system_files /src/system_files
COPY branding/legix-mark.svg /src/legix-mark.svg
COPY --from=branding-assets /out/plymouth /src/plymouth
COPY --from=branding-assets /out/icons /src/icons
RUN rpmbuild -bb /src/legix.spec \
      --define "_sourcedir /src" --define "_topdir /rpmbuild" \
      --define "legix_build_version $(date -u +%Y%m%d.%H%M)" \
 && mkdir -p /out && cp /rpmbuild/RPMS/noarch/legix-*.rpm /out/

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY --from=legix-rpm /out /legix-rpms
# Public half of the image signing key, installed so devices can verify updates.
COPY cosign.pub /cosign.pub
# Patched Noctalia RPM (lock-screen on-screen keyboard), released by
# shad0wcrawl3r/noctalia-osk and fetched by CI. Empty = Fedora's package.
COPY noctalia-rpms /noctalia-rpms
COPY --from=branding-assets /out/icons /branding-png/icons
COPY --from=branding-assets /out/videos /branding-video
COPY branding /branding

# Base Image
FROM ghcr.io/ublue-os/bazzite-deck-gnome:stable
## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:testing
# FROM ghcr.io/ublue-os/aurora:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:44
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
