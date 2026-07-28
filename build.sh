#!/bin/bash
# Build m_tools.app (native Swift), a DMG, and optionally an MDM-deployable .pkg.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD="$DIR/build"
APP="$BUILD/m_tools.app"
VERSION="1.0.0"
BUNDLE_ID="io.internal.mtools"

# `./build.sh --run` quits any running instance, relaunches from build/, and
# skips the DMG — the fast dev loop. Plain `./build.sh` builds the DMG too.
# `./build.sh --pkg` additionally builds m_tools-<version>.pkg for MDM deployment
# (see docs/deployment.md — an MDM installs it as root, which is what avoids both the
# admin prompt and the Gatekeeper "unidentified developer" prompt).
RUN=0
PKG=0
for arg in "$@"; do
    [ "$arg" = "--run" ] && RUN=1
    [ "$arg" = "--pkg" ] && PKG=1
done

rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> Compiling Swift sources"
# find, not a glob, so files nested under Sources/Tools/ etc. are picked up reliably.
SOURCES=()
while IFS= read -r -d '' f; do SOURCES+=("$f"); done < <(find "$DIR/Sources" -name '*.swift' -print0)

swiftc -swift-version 5 -O -target "$(uname -m)-apple-macos13.0" \
    -o "$APP/Contents/MacOS/m_tools" \
    "${SOURCES[@]}" \
    -framework AppKit -framework SwiftUI -framework CoreImage -framework Security -framework WebKit \
    -framework UniformTypeIdentifiers -framework CryptoKit

echo "==> Writing Info.plist"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>m_tools</string>
    <key>CFBundleIdentifier</key><string>io.internal.mtools</string>
    <key>CFBundleName</key><string>m_tools</string>
    <key>CFBundleDisplayName</key><string>m_tools</string>
    <key>CFBundleIconFile</key><string>m_tools.icns</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Internal tool — not for external distribution.</string>
</dict>
</plist>
PLIST

echo "==> Generating app icon"
# tools/makeicon.swift writes the multi-resolution .icns directly (no sips/iconutil,
# no image assets — icon is drawn in code, matching the "no image assets" convention).
swift "$DIR/tools/makeicon.swift" "$APP/Contents/Resources/m_tools.icns"

echo "==> Code signing"
# A *stable* signing identity is what lets macOS preserve any future permission grant
# (e.g. Accessibility, if the command palette ever needs a global hotkey) across
# rebuilds/updates — the grant is keyed to the identity's certificate (its SHA-1), NOT
# the app's name or path. Ad-hoc signatures ("-") change every build, which would reset
# any such grant every time. Two deliberately separate roles:
#   • m_tools-dev      optional, per-developer, local — keeps YOUR rebuilds' grant.
#   • m_tools-release  the ONE shared identity every published release must use, so end
#                        users keep their grant across updates. Export it as a .p12 and
#                        import it on each release machine / CI. See CONTRIBUTING > Releasing.
# Set RELEASE_CERT_SHA to that shared cert's SHA-1 to hard-fail a release signed by the
# wrong identity (find it with: security find-identity -p codesigning).
RELEASE_CERT_SHA="9CA869539D55D6F71EE11EAC6A235FFE46CF6927"

# Echo a code-signing identity's SHA-1 by (sub)name, or nothing. Matched without -v: a
# self-signed cert is usable for signing even when it isn't a trusted root (-v hides it).
find_identity() {
    security find-identity -p codesigning 2>/dev/null \
        | awk -v name="$1" '$0 ~ name { print $2; exit }' || true
}

SIGN_ID="-"
if [ "$RUN" = "1" ]; then
    # Dev rebuild — prefer the local convenience cert, else ad-hoc.
    if [ -n "$(find_identity 'm_tools-dev')" ]; then
        SIGN_ID="m_tools-dev"
        echo "    dev identity 'm_tools-dev'"
    else
        echo "    ad-hoc (create a 'm_tools-dev' cert if you ever need permission grants to persist across rebuilds)"
    fi
else
    # Release build (DMG) — require the shared release identity so users keep any grant.
    RELEASE_SHA="$(find_identity 'm_tools-release')"
    if [ -n "$RELEASE_SHA" ]; then
        SIGN_ID="m_tools-release"
        echo "    release identity 'm_tools-release' ($RELEASE_SHA)"
    else
        echo "    WARNING: no 'm_tools-release' identity — see CONTRIBUTING > Releasing." >&2
        if [ -n "$(find_identity 'm_tools-dev')" ]; then
            SIGN_ID="m_tools-dev"
            echo "             falling back to 'm_tools-dev' — OK for local DMG testing, NOT for release." >&2
        else
            echo "             falling back to ad-hoc — OK for local DMG testing, NOT for release." >&2
        fi
    fi
    # If a canonical release identity is pinned, the chosen signer MUST match it.
    if [ -n "$RELEASE_CERT_SHA" ]; then
        CHOSEN_SHA=""
        [ "$SIGN_ID" != "-" ] && CHOSEN_SHA="$(find_identity "$SIGN_ID")"
        if [ "$CHOSEN_SHA" != "$RELEASE_CERT_SHA" ]; then
            echo "!!! Release signed by the WRONG identity (${CHOSEN_SHA:-ad-hoc}); expected $RELEASE_CERT_SHA." >&2
            echo "    Aborting to avoid shipping a build with a mismatched signing identity." >&2
            exit 1
        fi
    fi
fi
codesign --force --deep -s "$SIGN_ID" "$APP"

if [ "$RUN" = "1" ]; then
    echo "==> Relaunching"
    killall m_tools 2>/dev/null || true
    open "$APP"
    echo "==> Done: $APP (relaunched, DMG skipped)"
    exit 0
fi

echo "==> Building DMG"
DMG="$DIR/m_tools.dmg"
STAGE="$BUILD/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/m_tools.app"
rm -f "$DMG"
hdiutil create -volname "m_tools" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done: $APP"
echo "==> DMG:  $DMG"

if [ "$PKG" = "1" ]; then
    # An installer package for MDM (Jamf / Kandji / Intune / Mosyle) to push. This is what
    # removes both prompts on managed Macs, and it's worth being precise about why, because
    # they're two unrelated things:
    #
    #   1. The admin prompt exists because writing to /Applications needs admin rights. An
    #      MDM runs the installer as root, so nobody is asked for a password.
    #   2. The "unidentified developer" prompt exists because Gatekeeper checks the
    #      com.apple.quarantine attribute that browsers stamp on downloads. Files an MDM
    #      lays down are never quarantined, so Gatekeeper never evaluates the app — which
    #      is why a self-signed identity is fine here, with no notarization involved.
    #
    # A .pkg is used rather than shipping the .app because MDM app-deployment mechanisms
    # expect a package, and a package can carry a postinstall script if this ever needs one.
    echo "==> Building installer package"
    PKG_ROOT="$BUILD/pkg-root"
    PKG_OUT="$DIR/m_tools-${VERSION}.pkg"
    rm -rf "$PKG_ROOT"
    mkdir -p "$PKG_ROOT/Applications"
    cp -R "$APP" "$PKG_ROOT/Applications/m_tools.app"

    # --install-location / with the payload rooted at Applications/ (not --install-location
    # /Applications with a bare bundle) so the package can't nest itself as
    # /Applications/m_tools.app/m_tools.app on reinstall.
    #
    # --ownership recommended: files land as root:wheel regardless of who built them, which
    # is what /Applications expects and what stops a later update needing repair.
    pkgbuild \
        --root "$PKG_ROOT" \
        --identifier "$BUNDLE_ID" \
        --version "$VERSION" \
        --install-location / \
        --ownership recommended \
        "$PKG_OUT" >/dev/null

    rm -rf "$PKG_ROOT"

    # Signing the package is optional here: MDM installs bypass Gatekeeper either way, and
    # signing with a self-signed identity gains nothing a trusted one would. Done anyway
    # when an *installer* identity happens to exist, since some MDMs surface the signature.
    PKG_SIGN_ID="$(find_identity 'm_tools-installer')"
    if [ -n "$PKG_SIGN_ID" ]; then
        productsign --sign "m_tools-installer" "$PKG_OUT" "$PKG_OUT.signed" >/dev/null
        mv "$PKG_OUT.signed" "$PKG_OUT"
        echo "    signed with 'm_tools-installer'"
    else
        echo "    unsigned (fine for MDM — see docs/deployment.md)"
    fi

    echo "==> PKG:  $PKG_OUT"
fi
