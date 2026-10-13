#!/usr/bin/env bash
# One-time setup: creates a self-signed code-signing identity in the login keychain.
# Signing with a stable identity keeps privacy grants (Accessibility etc.) across rebuilds.
set -euo pipefail

NAME="MeetingMute Dev"

if security find-identity -p codesigning | grep -q "\"$NAME\""; then
    echo "Identity \"$NAME\" already exists."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

/usr/bin/env openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null

PASS="meetingmute"
legacy=""
openssl version | grep -q "^OpenSSL 3" && legacy="-legacy"
openssl pkcs12 -export $legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -name "$NAME" -out "$TMP/id.p12" -passout "pass:$PASS"

security import "$TMP/id.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$PASS" -T /usr/bin/codesign

echo "Created identity \"$NAME\"."
