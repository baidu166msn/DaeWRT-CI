#!/bin/bash
# ==========================================
# 【局部修补】保持全局最新，只把炸掉的 gettext-full 回退到 08.02 的稳定版
# ==========================================
echo ">>> 修复 gettext-full 编译报错 (局部回退到 0.24.2)..."
# 83c5ae5 是 08.02 成功编译时的 commit hash
git checkout 83c5ae5 -- package/libs/gettext-full
echo ">>> gettext-full 局部回退完成，其他源码保持最新！"
#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}
	echo " "
	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d -name "$NAME" -o -name "luci-theme-$NAME" -o -name "luci-app-$NAME" 2>/dev/null)
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf ./$REPO_NAME/
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f $REPO_NAME $PKG_NAME
	fi
}

# ==========================================
# 主题 (只保留 argon，在 .config 中配置)
# ==========================================
# UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
# UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
# UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
# UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"

# ==========================================
# 主力代理：DAED (透明代理)
# ==========================================
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"

# ==========================================
# HomeProxy（已禁用，DAED 主力）
# ==========================================
# UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"    ← 仓库已失效，且 GENERAL.txt 已禁用
# sing-box 升级也不再需要

# ==========================================
# 实用工具 (精简保留)
# ==========================================
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"

# ==========================================
# 以下全部注释 (与使用场景无关 / 有冲突 / 体积过大)
# ==========================================
# UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"              # 与 DAED 重叠
# UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"            # 与 DAED 重叠
# UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"  # 已弃用
# UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"             # 按需
# UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"           # 已有 ZeroTier
# UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"       # 雅典娜无风扇
# UPDATE_PACKAGE "gecoosac" "openwrt-fork/openwrt-gecoosac" "main"        # 无集客 AP
# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"        # DAED 自带 DNS 分流
# UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"            # 不挂网盘
# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"  # Qt6 太大
# UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"                            # 无 4G/5G 网卡
# UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"            # 触发 HTTPS 问题
# UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"  # 按需
# UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"                      # 已有 ZeroTier
# UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"  # 按需
# UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"        # 按需

# ==========================================
# 删除官方冲突的默认插件
# 【重要】不要删除 dae*，DAED 主力需要！
# 【重要】不要删除 v2ray-geodata/v2ray-geoip/v2ray-geosite！
# ==========================================
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,bypass*}
# 注意：不删 dae*（QiuSimons 仓库自带）
# 注意：不删 v2ray-geodata（DAED 需要）
cp -r $GITHUB_WORKSPACE/package/* ./ 2>/dev/null || true

# ==========================================
# 修复 luci-app-daed 相关 Makefile 和启动逻辑
# ==========================================
if [ -f "luci-app-daed/daed/Makefile" ]; then
	sed -i 's/pnpm install ; \\/pnpm install --no-frozen-lockfile ; \\/g' luci-app-daed/daed/Makefile
	sed -i 's|github.com/daeuniverse/quic-go|github.com/olicesx/quic-go|g' luci-app-daed/daed/Makefile
fi

if [ -f "luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed" ]; then
	sed -i 's|/run/i\\  procd_set_param|/procd_set_param command/i \\\tprocd_set_param|g' luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed
fi

# ==========================================
# 【关键】创建 DAED 启动时序 hotplug 脚本
# 解决"重启后 eBPF 先加载、代理隧道没就绪、DNS 全断"的问题
# ==========================================
mkdir -p $GITHUB_WORKSPACE/package/base-files/files/etc/hotplug.d/iface
cat > $GITHUB_WORKSPACE/package/base-files/files/etc/hotplug.d/iface/99-daed-start <<'EOF'
[ "$ACTION" = "ifup" ] && [ "$INTERFACE" = "wan" ] && {
    sleep 10
    local wait=0
    while [ $wait -lt 30 ]; do
        nslookup baidu.com 223.5.5.5 >/dev/null 2>&1 && break
        sleep 2
        wait=$((wait + 2))
    done
    /etc/init.d/daed start
}
EOF
chmod +x $GITHUB_WORKSPACE/package/base-files/files/etc/hotplug.d/iface/99-daed-start

# ==========================================
# .config 追加 (DAED + 常用插件 + 防冲突)
# ==========================================
cat >> ../.config <<'CONFIGEOF'

# --- 防冲突补丁 ---
# CONFIG_PACKAGE_luci-light is not set
# CONFIG_PACKAGE_wpad-basic-mbedtls is not set
# CONFIG_PACKAGE_wpad-basic-wolfssl is not set
# CONFIG_PACKAGE_wpad-basic is not set
# CONFIG_PACKAGE_dnsmasq is not set
# CONFIG_PACKAGE_firewall is not set
# CONFIG_PACKAGE_kmod-nft-fullcone is not set

# --- DAED 主力透明代理 ---
CONFIG_PACKAGE_luci-app-daed=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_daed-next=y

# --- HomeProxy 已禁用 ---
# CONFIG_PACKAGE_luci-app-homeproxy is not set
CONFIG_PACKAGE_sing-box=y

# --- 常用插件 ---
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-cpufreq=y

# --- 主题与语言 ---
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_default-settings-chn=y
CONFIGEOF
