#!/bin/zsh
set -eu
cd "${0:A:h}"
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  echo "Fieldnotes needs Apple's command-line tools. Install them with: xcode-select --install"
  exit 1
fi
zsh build.command
/usr/bin/open build/Fieldnotes.app
