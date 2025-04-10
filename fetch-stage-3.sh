#!/usr/bin/env bash
# Fetches the latest minimal iso for the arm64 platform and
# validates it.

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0"
  exit 1
fi

# BASE_URL is the URL to download builds from. This can be changed to
# use a mirror closer to the current user. Do not include a trailing
# slash.
BASE_URL="https://gentoo.rgst.io/gentoo/releases/arm64/autobuilds"

# GPGHOME is the directory to store GPG data in. We use our own home
# directory to avoid modifying the user's.
export GPGHOME="$(mktemp -d)"
trap 'rm -rf $GPGHOME' EXIT

info() {
  echo "$(tput bold)$*$(tput sgr0)"
}

info_sub() {
  echo "$(tput bold) -> $*$(tput sgr0)"
}

success() {
  echo -e "\033[0;32m$*\033[0m"
}

error() {
  echo -e "\033[0;31m$*\033[0m"
}

if [[ ! -e "/usr/share/openpgp-keys/gentoo-release.asc" ]]; then
  error "Missing gentoo release keys, are you on a livecd install?" \
    "(checked /usr/share/openpgp-keys/gentoo-release.asc)"
  exit 1
fi

if [[ "$(pwd)" != "/mnt/gentoo" ]]; then
  error "Must be ran in /mnt/gentoo"
  exit 1
fi

if [[ -e "latest-stage3-arm64-desktop-systemd.tar.xz" ]]; then
  error "Image already exists, refusing to continue." \
    "To force a re-download, delete latest-stage3-arm64-desktop-systemd.tar.xz."
  exit 0
fi

info "Preparing to fetch minimal image"
info_sub "Ensuring GPG keys are trusted"
gpg --import /usr/share/openpgp-keys/gentoo-release.asc

info "Determining latest minimal image..."
tmpFile=$(mktemp)
trap 'rm -f $tmpFile' EXIT
wget -q -O "$tmpFile" "$BASE_URL/latest-stage3-arm64-desktop-systemd.txt"

info_sub "Checking latest-stage3-arm64-desktop-systemd.txt signature..."
gpg --verify "$tmpFile" || {
  error "Failed to validate latest-stage3-arm64-desktop-systemd.txt"
  exit 1
}

# Grab the autobuild name.
LATEST_AUTOBUILD=$(grep "stage3-arm64-desktop-systemd" "$tmpFile" | tail -n1 | sed 's/\ .*//')
if [[ -z "$LATEST_AUTOBUILD" ]]; then
  echo "Failed to determine latest minimal stage3 build."
  exit 1
fi
FILE_NAME=$(basename "$LATEST_AUTOBUILD")

info "Using latest minimal image: $LATEST_AUTOBUILD"
# If it exists, but wasn't renamed, it's likely incomplete. Download again.
if [[ -e "$FILE_NAME" ]] && [[ ! -e "latest-stage3-arm64-desktop-systemd.tar.xz" ]]; then
  rm "$FILE_NAME"
fi

if [[ ! -e "$FILE_NAME" ]]; then
  wget "$BASE_URL/$LATEST_AUTOBUILD"
fi

info_sub "Fetching download signature..."
if [[ ! -e "$FILE_NAME.asc" ]]; then
  wget "$BASE_URL/$LATEST_AUTOBUILD.asc"
fi

info_sub "Checking image signature..."
gpg --verify "$FILE_NAME.asc" || {
  error "Failed to validate image."
  exit 1
}

success "Sccessfully validated image."

info "Image is available at: $(pwd)/latest-stage3-arm64-desktop-systemd.tar.xz"
mv "$FILE_NAME" latest-stage3-arm64-desktop-systemd.tar.xz
