#!/bin/bash
set -euo pipefail

UPDATE_PACKAGE() {
  local PKG_NAME=$1
  local PKG_REPO=$2
  local PKG_BRANCH=${3:-}
  local REPO_NAME=${PKG_REPO#*/}

  echo "Search & Clean: $PKG_NAME"
  find ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d -name "$PKG_NAME" -exec rm -rf {} + 2>/dev/null || true
  rm -rf "$REPO_NAME"

  if [ -n "$PKG_BRANCH" ]; then
    git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git" || return 1
  else
    git clone --depth=1 --single-branch "https://github.com/$PKG_REPO.git" || return 1
  fi
}

# 1. 主力透明代理 DAED
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"

# 2. 清理冲突插件 (【修复】增加容错，防止 set -e 因找不到文件而崩溃)
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,bypass*} 2>/dev/null || true
find ../package/feeds -maxdepth 4 -name 'luci-app-passwall*' -exec rm -rf {} + 2>/dev/null || true

# 3. 修复 DAED 编译
if [ -f "luci-app-daed/daed/Makefile" ]; then
  sed -i 's/pnpm install ; \\/pnpm install --no-frozen-lockfile ; \\/g' luci-app-daed/daed/Makefile || true
  sed -i 's|github.com/daeuniverse/quic-go|github.com/olicesx/quic-go|g' luci-app-daed/daed/Makefile || true
fi

# 4. 生成 DAED Hotplug (使用 ping 替代 nslookup)
HOTPLUG_DIR="$GITHUB_WORKSPACE/wrt/files/etc/hotplug.d/iface"
mkdir -p "$HOTPLUG_DIR"

cat > "$HOTPLUG_DIR/99-daed-start" <<'EOF'
#!/bin/sh
[ "$ACTION" = "ifup" ] && [ "$INTERFACE" = "wan" ] && {
  [ -x /etc/init.d/daed ] || exit 0
  /etc/init.d/daed enabled || exit 0
  
  sleep 10
  wait=0
  while [ $wait -lt 30 ]; do
    ping -c 1 -W 2 223.5.5.5 >/dev/null 2>&1 && break
    sleep 2
    wait=$((wait + 2))
  done
  /etc/init.d/daed start
}
EOF
chmod +x "$HOTPLUG_DIR/99-daed-start"

# 5. 同步自定义 package
if [ -d "$GITHUB_WORKSPACE/package" ]; then
  cp -r "$GITHUB_WORKSPACE/package/." ./ 2>/dev/null || true
fi
