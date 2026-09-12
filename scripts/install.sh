#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest_app="/Applications/DuoHinge.app"

# Never replace a running executable or follow a destination symlink.
if pgrep -x DuoHinge >/dev/null; then
    echo "Quit DuoHinge before installing." >&2
    exit 1
fi
if [ -L "$dest_app" ] || { [ -e "$dest_app" ] && [ ! -d "$dest_app" ]; }; then
    echo "Refusing unexpected destination: $dest_app" >&2
    exit 1
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/duohinge-build.XXXXXX")"
echo "Building Release. Build products and log: $build_dir"
# Pass signing overrides as arguments, e.g. DEVELOPMENT_TEAM=YOUR_TEAM_ID.
if ! xcodebuild -project "$project_dir/DuoHinge.xcodeproj" -scheme DuoHinge \
    -configuration Release -destination 'platform=macOS' \
    -derivedDataPath "$build_dir" "$@" build > "$build_dir/build.log" 2>&1; then
    tail -n 60 "$build_dir/build.log" >&2
    exit 1
fi

src_app="$build_dir/Build/Products/Release/DuoHinge.app"
if [ ! -x "$src_app/Contents/MacOS/DuoHinge" ]; then
    echo "Built executable not found: $src_app" >&2
    exit 1
fi
codesign --verify --deep --strict "$src_app"

# Stage a complete bundle on the same volume before changing the installation.
stage_dir="$(mktemp -d "/Applications/.duohinge-install.XXXXXX")"
ditto "$src_app" "$stage_dir/DuoHinge.app"
if pgrep -x DuoHinge >/dev/null; then
    echo "DuoHinge started during the build. Quit it and retry. Staged app: $stage_dir" >&2
    exit 1
fi
if [ -e "$dest_app" ]; then
    mv "$dest_app" "$stage_dir/Previous-DuoHinge.app"
fi
if ! mv "$stage_dir/DuoHinge.app" "$dest_app"; then
    if [ -d "$stage_dir/Previous-DuoHinge.app" ]; then
        mv "$stage_dir/Previous-DuoHinge.app" "$dest_app"
    fi
    exit 1
fi
echo "Installed $dest_app (not launched)."
echo "Previous installation, if present: $stage_dir/Previous-DuoHinge.app"
echo "Permission continuity depends on the signing identity, bundle ID, and macOS."
echo "This development install is not a notarized public distribution."
