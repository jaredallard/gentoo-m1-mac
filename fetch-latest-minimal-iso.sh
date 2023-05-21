#!/usr/bin/env bash
# Fetches the latest minimal iso for the arm64 platform and
# validates it.

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0"
  exit 1
fi

BASE_URL="https://gentoo.osuosl.org/releases/arm64/autobuilds"

info() {
  echo "$(tput bold)$*$(tput sgr0)"
}

info_sub() {
  echo "$(tput bold) -> $*$(tput sgr0)"
}

success() {
  echo -e "\033[0;32m$1\033[0m"
}

error() {
  echo -e "\033[0;31m$1\033[0m"
}

info "Determining latest minimal image..."
LATEST_ISO=$(curl -s "$BASE_URL/latest-iso.txt" | tail -n1 | sed 's/\ .*//')
if [[ -z "$LATEST_ISO" ]]; then
  echo "Failed to determine latest minimal image."
  exit 1
fi
FILE_NAME=$(basename "$LATEST_ISO")

info "Using latest minimal image: $LATEST_ISO"
if [[ ! -e "$FILE_NAME" ]]; then
  wget "$BASE_URL/$LATEST_ISO"
fi

info "Validating image..."
info_sub "Fetching GPG key(s)..."
gpg --keyserver hkps://keys.gentoo.org --recv-keys 13EBBDBEDE7A12775DFDB1BABB572E0E2D182910

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
