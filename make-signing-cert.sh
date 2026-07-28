#!/bin/bash
# Creates the m_tools code-signing identity and everything the release workflow needs from
# it — save this as tools/make-signing-cert.sh in the repo.
#
# Why this exists instead of the Keychain Access instructions: exporting a .p12 from the GUI
# is greyed out unless the *private key* is part of the selection, which is easy to get wrong
# (see the note at the bottom). Generating the identity with openssl sidesteps that entirely,
# is reproducible, and hands you the base64 blob and SHA-1 fingerprint the setup needs.
#
# Usage:
#   ./tools/make-signing-cert.sh                 # → m_tools-release identity
#   ./tools/make-signing-cert.sh m_tools-dev     # → local per-developer identity
#
# Nothing it writes should ever be committed — .gitignore already blocks *.p12.
set -euo pipefail

NAME="${1:-m_tools-release}"
OUT_DIR="${TMPDIR:-/tmp}/m_tools-signing"
KEY="$OUT_DIR/$NAME.key"
CRT="$OUT_DIR/$NAME.crt"
P12="$OUT_DIR/$NAME.p12"
CONF="$OUT_DIR/$NAME.cnf"

# /usr/bin/openssl explicitly (macOS ships LibreSSL) so a Homebrew OpenSSL earlier in PATH
# can't change the PKCS#12 encryption to something `security import` chokes on.
OPENSSL=/usr/bin/openssl

mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

# A config file rather than `-addext`: that flag is OpenSSL 1.1.1+ and isn't reliably
# available in the LibreSSL that macOS ships.
#
# The extensions aren't decoration — `codesign` and `security find-identity -p codesigning`
# only consider a certificate usable for signing if it carries the codeSigning extended key
# usage, so a cert generated without these is silently invisible to the build.
cat > "$CONF" <<EOF
[ req ]
distinguished_name = dn
x509_extensions    = ext
prompt             = no

[ dn ]
CN = $NAME

[ ext ]
basicConstraints     = critical,CA:FALSE
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
subjectKeyIdentifier = hash
EOF

echo "==> Generating a 10-year self-signed code-signing certificate: $NAME"
"$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$KEY" -out "$CRT" -config "$CONF" 2>/dev/null

# Random password: it only ever needs to travel from here into a GitHub secret, so there's
# no reason for a human-chosen one.
PASSWORD="$("$OPENSSL" rand -base64 24)"

echo "==> Packaging as PKCS#12"
"$OPENSSL" pkcs12 -export \
    -inkey "$KEY" -in "$CRT" -name "$NAME" \
    -out "$P12" -passout pass:"$PASSWORD"

chmod 600 "$P12" "$KEY"

# `security find-identity` prints the SHA-1 as uppercase hex with no separators, which is the
# form build.sh's RELEASE_CERT_SHA comparison expects — so strip openssl's colons.
SHA1="$("$OPENSSL" x509 -in "$CRT" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':')"

echo "==> Importing into your login keychain (so local builds can sign)"
security import "$P12" \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$PASSWORD" \
    -T /usr/bin/codesign \
    -A >/dev/null
echo "    imported"

echo
echo "==> Verifying the identity is visible to codesign"
# Deliberately not `-v`: a self-signed root isn't a *trusted* root, so -v would hide it —
# but it's still perfectly usable for signing, which is all build.sh needs.
if security find-identity -p codesigning | grep -q "$NAME"; then
    security find-identity -p codesigning | grep "$NAME"
else
    echo "    !!! '$NAME' not found — signing will fall back to ad-hoc." >&2
    echo "        Check the codeSigning extension survived: openssl x509 -in $CRT -noout -text" >&2
    exit 1
fi

cat <<SUMMARY

────────────────────────────────────────────────────────────────────────────
Done. Local builds will now sign with '$NAME' automatically.
SUMMARY

if [ "$NAME" = "m_tools-dev" ]; then
    cat <<'DEV'

That's the local per-developer identity — nothing further to do, and nothing to upload.
DEV
    exit 0
fi

cat <<SUMMARY

Three things left, for the release identity only:

1. GitHub secret  RELEASE_CERT_P12_BASE64
   Copied to your clipboard now. Paste it at:
   Settings → Secrets and variables → Actions → New repository secret

2. GitHub secret  RELEASE_CERT_PASSWORD
   $PASSWORD

3. build.sh       RELEASE_CERT_SHA="$SHA1"

Then store the .p12 and its password in the team vault and delete the local copies:

     cp "$P12" ~/Desktop/          # → team vault, then remove from Desktop
     rm -rf "$OUT_DIR"

Losing this .p12 means future releases get a *different* signing identity, which resets
any permission grant users have accumulated — macOS keys those to the certificate, not
the app name or path.
────────────────────────────────────────────────────────────────────────────
SUMMARY

base64 -i "$P12" | tr -d '\n' | pbcopy
echo "(RELEASE_CERT_P12_BASE64 is on the clipboard)"
