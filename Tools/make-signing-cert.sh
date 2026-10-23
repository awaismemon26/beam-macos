#!/bin/bash
# Creates Beam's release signing certificate once: a self-signed code-signing identity named "Beam"
# (10 years, RSA 2048) exported as Beam.p12 with a random password. Signing every release with the
# same certificate lets macOS keep Accessibility across updates. The default folder is git-ignored.
#
#   Tools/make-signing-cert.sh [out-dir]     (default: private/signing)
set -euo pipefail
OUT="${1:-$(cd "$(dirname "$0")/.." && pwd)/private/signing}"
mkdir -p "$OUT"
chmod 700 "$OUT" "$(dirname "$OUT")"
[ -e "$OUT/Beam.p12" ] && { echo "error: $OUT/Beam.p12 already exists; remove it to make a new certificate"; exit 1; }

OPENSSL=/usr/bin/openssl   # the system one: its .p12 encryption is what `security import` accepts (OpenSSL 3's is not)
CONF="$(mktemp)"
trap 'rm -f "$CONF"' EXIT
cat > "$CONF" <<'CNF'
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = Beam
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:FALSE
CNF

PASSWORD="$($OPENSSL rand -hex 16)"
"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$CONF" \
    -keyout "$OUT/Beam.key" -out "$OUT/Beam.crt" 2>/dev/null
"$OPENSSL" pkcs12 -export -inkey "$OUT/Beam.key" -in "$OUT/Beam.crt" -name Beam \
    -out "$OUT/Beam.p12" -passout "pass:$PASSWORD"
rm -f "$OUT/Beam.key" "$OUT/Beam.crt"
chmod 600 "$OUT/Beam.p12"

cat <<MSG
Created $OUT/Beam.p12 (certificate "Beam", valid 10 years).

Add two repository secrets (GitHub > Settings > Secrets and variables > Actions > New repository secret):

  BEAM_SIGNING_P12_BASE64    $(base64 < "$OUT/Beam.p12" | tr -d '\n')

  BEAM_SIGNING_P12_PASSWORD  $PASSWORD

Keep Beam.p12 somewhere safe (a lost certificate means everyone grants Accessibility once more).
Never commit it.
MSG
