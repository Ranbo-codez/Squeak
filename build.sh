#!/bin/bash
# Builds Squeak.app — a menu-bar app, universal (Apple silicon + Intel), macOS 13+.
#
#   ./build.sh            build into build/Squeak.app
#   ./build.sh --install  build, copy to ~/Applications and launch
#   ./build.sh --dmg      build and package build/Squeak.dmg
#
# Needs only Apple's Command Line Tools (xcode-select --install). No Xcode project, no dependencies.
set -e
cd "$(dirname "$0")"
VERSION=1.0.1
BUNDLE_ID=com.ranbirdhall.squeak
APP=build/Squeak.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources build/obj

for ARCH in arm64 x86_64; do
  swiftc -swift-version 5 -Osize -wmo -target $ARCH-apple-macos13 Sources/*.swift -o build/obj/Squeak-$ARCH \
    -framework AppKit -framework IOKit -framework ServiceManagement
done
lipo -create build/obj/Squeak-arm64 build/obj/Squeak-x86_64 -output $APP/Contents/MacOS/Squeak

# The app icon is drawn in code (IconArt.appIcon), so it's rendered at build time — no binary assets in the repo.
$APP/Contents/MacOS/Squeak --icon build/obj/Squeak.iconset
iconutil -c icns build/obj/Squeak.iconset -o $APP/Contents/Resources/AppIcon.icns

cat > $APP/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>Squeak</string>
<key>CFBundleDisplayName</key><string>Squeak</string>
<key>CFBundleExecutable</key><string>Squeak</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>© Ranbir Dhall. PolyForm Noncommercial 1.0.0.</string>
</dict></plist>
EOF

# Ad-hoc signature with a fixed designated requirement (the bundle ID) instead of the default per-build hash.
# macOS ties Accessibility / Input Monitoring permission to this requirement, so it survives rebuilds.
codesign --force --sign - -r="designated => identifier \"$BUNDLE_ID\"" $APP
echo "Built $APP ($VERSION, $(lipo -archs $APP/Contents/MacOS/Squeak))"

case "$1" in
  --install)
    pkill -x Squeak 2>/dev/null || true
    for i in $(seq 50); do pgrep -x Squeak >/dev/null || break; sleep 0.1; done   # wait until it has fully quit
    mkdir -p ~/Applications && rm -rf ~/Applications/Squeak.app && cp -R $APP ~/Applications/
    sleep 0.3 && open ~/Applications/Squeak.app
    echo "Installed to ~/Applications/Squeak.app" ;;
  --dmg)
    STAGE=build/dmg && mkdir -p $STAGE && cp -R $APP $STAGE/ && ln -s /Applications $STAGE/Applications
    hdiutil create -quiet -volname Squeak -srcfolder $STAGE -fs HFS+ -format UDZO -ov build/Squeak.dmg
    echo "Packaged build/Squeak.dmg" ;;
esac
