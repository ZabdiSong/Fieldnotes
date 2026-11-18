#!/bin/zsh
set -eu
cd "${0:A:h}"
stage=$(mktemp -d /private/tmp/fieldnotes-icon.XXXXXX)
trap 'rm -rf "$stage"' EXIT
iconset="$stage/Fieldnotes.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  /usr/bin/sips -s format png -z "$size" "$size" Assets/penguin.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  /usr/bin/sips -s format png -z "$retina" "$retina" Assets/penguin.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
/usr/bin/iconutil -c icns "$iconset" -o Assets/Fieldnotes.icns
echo "Created Assets/Fieldnotes.icns"
