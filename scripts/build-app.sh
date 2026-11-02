#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

build_app() {
    product="$1"
    name="$2"
    bundle_id="$3"
    swift build -c release --product "$product"
    bin_dir="$(swift build -c release --show-bin-path)"
    app="${PWD}/dist/${name}.app"
    mkdir -p "$app/Contents/MacOS"
    cp "$bin_dir/$product" "$app/Contents/MacOS/$product"
    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$name</string>
  <key>CFBundleDisplayName</key><string>$name</string>
  <key>CFBundleIdentifier</key><string>$bundle_id</string>
  <key>CFBundleExecutable</key><string>$product</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
    printf 'Built: %s\n' "$app"
}

case "${1:-all}" in
    penrose) build_app PenroseWallpaper "Penrose Nocturne" local.penrose.nocturne ;;
    life) build_app LifeWallpaper "Life Matte Gold" local.wallpaper.life-matte-gold ;;
    all)
        build_app PenroseWallpaper "Penrose Nocturne" local.penrose.nocturne
        build_app LifeWallpaper "Life Matte Gold" local.wallpaper.life-matte-gold
        ;;
    *) printf 'Usage: %s [penrose|life|all]\n' "$0" >&2; exit 2 ;;
esac
