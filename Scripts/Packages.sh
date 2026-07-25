#!/bin/bash

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}

	echo " "

	# 删除本地可能存在的同名或冲突软件包
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

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

	# 处理克隆的仓库
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
# 【修复】HomeProxy + sing-box (从 sbwml 仓库拉取兼容版本)
# 原 VIKINGYFY/homeproxy 已删除，改用 sbwml/openwrt_helloworld (分支 v5)
# ==========================================
echo ">>> 拉取 HomeProxy + sing-box (兼容版本)..."
rm -rf /tmp/helloworld
git clone --depth=1 --single-branch --branch v5 "https://github.com/sbwml/openwrt_helloworld.git" /tmp/helloworld

if [ -d "/tmp/helloworld/sing-box" ] && [ -d "/tmp/helloworld/luci-app-homeproxy" ]; then
	# 删除 feeds 中的旧版
	rm -rf ../feeds/packages/net/sing-box
	rm -rf ../feeds/luci/applications/luci-app-homeproxy

	# 复制兼容版本到编译目录
	cp -r /tmp/helloworld/sing-box ../feeds/packages/net/sing-box
	cp -r /tmp/helloworld/luci-app-homeproxy ./luci-app-homeproxy

	rm -rf /tmp/helloworld
	echo ">>> HomeProxy (sing-box 1.12.25 兼容版) 拉取完成！"
else
	rm -rf /tmp/helloworld
	echo ">>> [错误] HomeProxy/sing-box 拉取失败，请检查网络！"
	exit 1
fi

# ==========================================
# 实用工具 (精简保留)
# ==========================================

UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"

# ==========================================
# 以下全部注释 (与使用场景无关)
# ==========================================
# UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
# UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
# UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
# UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
# UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
# UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
# UPDATE_PACKAGE "fancontrol" "rockjake/luci-app-fancontrol" "main"
# UPDATE_PACKAGE "gecoosac" "openwrt-fork/openwrt-gecoosac" "main"
# UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
# UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
# UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
# UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
# UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"
# UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
# UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
# UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
# UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"

# ==========================================
# 删除官方冲突的默认插件
# 【重要】不要删除 dae*，DAED 主力需要！
# 【重要】不要删除 v2ray-geodata，HomeProxy 需要！
# ==========================================
rm -rf ../feeds/luci/applications/luci-app-{passwall*,mosdns,dockerman,bypass*}
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
# .config 追加 (DAED + HomeProxy + 常用插件 + 防冲突)
# ==========================================
cat >> ../.config <<EOF

# --- 防冲突补丁 ---
# CONFIG_PACKAGE_luci-light is not set
# CONFIG_PACKAGE_wpad-basic-mbedtls is not set
# CONFIG_PACKAGE_wpad-basic-wolfssl is not set
# CONFIG_PACKAGE_wpad-basic is not set
# CONFIG_PACKAGE_dnsmasq is not set
# CONFIG_PACKAGE_firewall is not set
# CONFIG_PACKAGE_iptables is not set
# CONFIG_PACKAGE_kmod-ipt-core is not set
# CONFIG_PACKAGE_kmod-nft-fullcone is not set
# CONFIG_PACKAGE_luci-ssl is not set
# CONFIG_PACKAGE_luci-ssl-openssl is not set
# CONFIG_PACKAGE_luci-ssl-wolfssl is not set
# CONFIG_PACKAGE_px5g is not set
# CONFIG_PACKAGE_luci-app-passwall is not set

# --- DAED 主力透明代理 ---
CONFIG_PACKAGE_luci-app-daed=y
CONFIG_PACKAGE_dae=y

# --- HomeProxy 服务器端 (sing-box 1.12.25 兼容版) ---
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_v2ray-geodata=y
CONFIG_PACKAGE_v2ray-geosite=y

# --- 常用插件：UPnP / Samba4 / ZeroTier ---
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_zerotier=y

# --- 实用工具 ---
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-cpufreq=y

# --- 主题与语言 ---
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_default-settings-chn=y
EOF
