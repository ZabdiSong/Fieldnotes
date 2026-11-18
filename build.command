#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p "build/modules"
stage=$(mktemp -d /private/tmp/fieldnotes-build.XXXXXX)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/Fieldnotes.app/Contents/MacOS"
mkdir -p "$stage/Fieldnotes.app/Contents/Resources"
if [[ ! -f Assets/Fieldnotes.icns ]]; then
  zsh build_icon.command
fi
cp Assets/Fieldnotes.icns "$stage/Fieldnotes.app/Contents/Resources/Fieldnotes.icns"
/usr/bin/xcrun swiftc -O -swift-version 5 -parse-as-library \
  -target "$(uname -m)-apple-macosx14.0" -module-cache-path build/modules \
  PlannerModel.swift ScheduleModel.swift PlannerStore.swift Fieldnotes.swift PlannerUI.swift CalendarViews.swift ScheduleEditors.swift TodayWidget.swift CompletionAnimation.swift -o "$stage/Fieldnotes.app/Contents/MacOS/Fieldnotes"
cp Info.plist "$stage/Fieldnotes.app/Contents/Info.plist"
/usr/bin/xattr -cr "$stage/Fieldnotes.app"
/usr/bin/codesign --force --sign - "$stage/Fieldnotes.app"
/usr/bin/codesign --verify --deep --strict "$stage/Fieldnotes.app"
/usr/bin/ditto --norsrc --noextattr "$stage/Fieldnotes.app" build/Fieldnotes.app
# Desktop cloud storage can add Finder metadata after copying; validate the sealed code.
/usr/bin/codesign --verify --deep build/Fieldnotes.app
echo "Built: ${PWD}/build/Fieldnotes.app"
