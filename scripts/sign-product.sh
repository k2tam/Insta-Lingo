#!/bin/sh
set -eu

product=${1:?Usage: sign-product.sh PRODUCT_PATH}
if [ ! -e "$product" ]; then
    echo "Signing failed: product not found: $product" >&2
    exit 1
fi

# Pin a certificate with CODESIGN_IDENTITY when more than one development
# identity is installed. Never silently fall back to an ad-hoc signature:
# its designated requirement changes on every rebuild and loses TCC grants.
identity=${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development:/ { print $2; exit }')}
if [ -z "$identity" ]; then
    echo "Signing failed: no Apple Development identity found. Set CODESIGN_IDENTITY to a certificate SHA-1 hash." >&2
    exit 1
fi

codesign --force --sign "$identity" --identifier com.k2tam.InstaLingo "$product"
codesign --verify --strict "$product"
