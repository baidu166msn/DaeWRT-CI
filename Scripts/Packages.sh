#!/bin/bash
set -euo pipefail

UPDATE_PACKAGE() {
  local PKG_NAME=$1
  local PKG_REPO=$2
  local PKG_BRANCH=${3:-}
  local PKG_SPECIAL=${4:-}
  local PKG_LIST=("$PKG_NAME" ${5:-})
  local REPO_NAME=${PKG_REPO#*/}

  echo "Search & Clean: $PKG_NAME"
  find ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d -name "$PKG_NAME" -exec rm -rf {} + 2>/dev/null || true
  rm -rf "$REPO_NAME"

  if [ -n "$PKG_BRANCH" ]; then
    git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git" || return 1
  else
    git clone --depth=1 --single-branch "https://github.com/$PKG_REPO.git" || return 1
  fi

  if [[ "$PKG_SPECIAL" == "pkg" ]]; then
    find "./$REPO_NAME" -mindepth 2 -maxdepth 4 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \; 2>/dev/null || true
    rm -rf "./$REPO_NAME/"
  elif [[ "$PKG_SPECIAL" == "name" ]]; then
    mv -f "$REPO_NAME" "$PKG_NAME"
  fi
}

# 1. 主力透明代理 OpenClash (使用 pkg 模式提取)
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"

# 2. 清理冲突插件
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,bypass*} 2>/dev/null || true
find ../package/feeds -maxdepth 4 -name 'luci-app-passwall*' -exec rm -rf {} + 2>/dev/null || true

# 3. 同步自定义 package
if [ -d "$GITHUB_WORKSPACE/package" ]; then
  cp -r "$GITHUB_WORKSPACE/package/." ./ 2>/dev/null || true
fi
