#!/usr/bin/env bash
# Usage: ./scripts/set-version.sh [VERSION]
# VERSION を省略すると最新の git tag から取得する (例: v0.3.0 → 0.3.0)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# バージョン決定
if [ $# -ge 1 ]; then
  VERSION="$1"
else
  TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
  if [ -z "$TAG" ]; then
    echo "ERROR: git tag が見つかりません。バージョンを引数で指定してください。" >&2
    exit 1
  fi
  VERSION="${TAG#v}"  # 先頭の 'v' を除去
fi

echo "Setting version: $VERSION"

# 1. cl-booth-library-manager.asd
ASD="$REPO_ROOT/cl-booth-library-manager.asd"
sed -i "s/:version \"[^\"]*\"/:version \"$VERSION\"/" "$ASD"
echo "  Updated: cl-booth-library-manager.asd"

# 2. frontend/package.json
PKG="$REPO_ROOT/frontend/package.json"
sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$VERSION\"/" "$PKG"
echo "  Updated: frontend/package.json"

echo "Done. Version set to $VERSION"
