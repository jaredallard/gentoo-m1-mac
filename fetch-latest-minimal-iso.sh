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

# SIGNING_KEY_ID is the ID of the GPG key used to sign images. This
# should be changed ONLY if Gentoo has rotated their signing key.
SIGNING_KEY_ID="13EBBDBEDE7A12775DFDB1BABB572E0E2D182910"

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

if [[ -e "install.iso" ]]; then
  error "Image already exists, refusing to continue." \
    "To force a re-download, delete install.iso."
  exit 0
fi

info "Preparing to fetch minimal image"
info_sub "Fetching GPG key(s)..."
gpg --keyserver hkps://keys.gentoo.org --recv-keys "$SIGNING_KEY_ID"
echo -e "trust\n5\ny\n" | gpg --command-fd 0 --edit-key "$SIGNING_KEY_ID" >/dev/null

info "Determining latest minimal image..."
tmpFile=$(mktemp)
trap 'rm -f $tmpFile' EXIT
curl -s "$BASE_URL/latest-iso.txt" >"$tmpFile"

info_sub "Checking latest-iso.txt signature..."
gpg --verify "$tmpFile" || {
  error "Failed to validate latest-iso.txt"
  exit 1
}

# Grab the image name from the latest-iso.txt file for fetching later.
LATEST_ISO=$(grep "install-arm64" "$tmpFile" | tail -n1 | sed 's/\ .*//')
if [[ -z "$LATEST_ISO" ]]; then
  echo "Failed to determine latest minimal image."
  exit 1
fi
FILE_NAME=$(basename "$LATEST_ISO")

info "Using latest minimal image: $LATEST_ISO"
# If it exists, but wasn't renamed, it's likely incomplete. Download again.
if [[ -e "$FILE_NAME" ]] && [[ ! -e "install.iso" ]]; then
  rm "$FILE_NAME"
fi

if [[ ! -e "$FILE_NAME" ]]; then
  wget "$BASE_URL/$LATEST_ISO"
fi

info_sub "Fetching download signature..."
if [[ ! -e "$FILE_NAME.asc" ]]; then
  wget "$BASE_URL/$LATEST_ISO.asc"
fi

info_sub "Checking image signature..."
gpg --verify "$FILE_NAME.asc" || {
  error "Failed to validate image."
  exit 1
}

success "Sccessfully validated image."

info "Image is available at: $(pwd)/install.iso"
mv "$FILE_NAME" install.iso
