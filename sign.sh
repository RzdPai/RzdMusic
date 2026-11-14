#!/bin/bash
set -e

PRODUCT=${1:-default}
MODE=${2:-release}

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
export PATH=/root/command-line-tools/bin:$PATH
export HOME="$PROJECT_DIR/.home"
export npm_config_cache="$PROJECT_DIR/.home/.npm"
export XDG_CACHE_HOME="$PROJECT_DIR/.home/.cache"

echo "==> Building app package product=$PRODUCT mode=$MODE"
cd "$PROJECT_DIR"
hvigorw assembleApp --mode project -p product="$PRODUCT" -p buildMode="$MODE" --no-daemon

SIGNED_APP=$(find "$PROJECT_DIR/build/outputs/$PRODUCT" -name "*-signed.app" 2>/dev/null | head -1)
if [ -z "$SIGNED_APP" ]; then
    echo "ERROR: signed app not found"
    exit 1
fi

echo "==> Verifying signature"
java -jar /root/command-line-tools/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar verify-app \
    -inFile "$SIGNED_APP" \
    -outCertChain /tmp/verify_chain_out.cer \
    -outProfile /tmp/verify_profile_out.p7b

echo "==> Done: $SIGNED_APP"
