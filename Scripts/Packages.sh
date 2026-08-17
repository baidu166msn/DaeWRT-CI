#!/bin/bash

# ==============================================================================
# DaeWRT-CI 第三方软件包
# ==============================================================================

UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo " "
	echo "========== Installing: $PKG_NAME =========="

	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"

		local FOUND_DIRS
		FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ \
			-maxdepth 4 \
			-type d \
			\( -name "$NAME" -o -name "luci-theme-$NAME" -o -name "luci-app-$NAME" \) \
			2>/dev/null)

		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				[ -n "$DIR" ] || continue
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" \
		"https://github.com/$PKG_REPO.git"

	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find "./$REPO_NAME"/*/ -maxdepth 3 \
			-type d \
			-iname "*$PKG_NAME*" \
			-prune \
			-exec cp -rf {} ./ \;
		rm -rf "./$REPO_NAME/"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi
}

# ==============================================================================
# 1. DAED
# ==============================================================================

UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"

# ==============================================================================
# 2. 存储工具
# ==============================================================================

UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"


# ==============================================================================
# 3. Argon
# ==============================================================================

UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"

# ==============================================================================
# 4. 明确不加入的第三方插件
# ==============================================================================

# UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
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
# UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "luci-app-timewol luci-app-wolplus"
# UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"
# UPDATE_PACKAGE "luci-app-pushbot" "zzsj0928/luci-app-pushbot" "master"
# UPDATE_PACKAGE "luci-app-lucky" "sirpdboy/luci-app-lucky" "main"

# ==============================================================================
# 5. 删除与当前架构冲突的默认插件
# ==============================================================================

rm -rf ../feeds/luci/applications/luci-app-passwall*
rm -rf ../feeds/luci/applications/luci-app-mosdns
rm -rf ../feeds/luci/applications/luci-app-dockerman
rm -rf ../feeds/luci/applications/luci-app-bypass*

# 引入项目自定义 package
cp -r "$GITHUB_WORKSPACE/package/"* ./ 2>/dev/null || true

# ==============================================================================
# 6. Argon 兼容性修复
# ==============================================================================

find . -type f -path "*/argon/header.ut" \
	-exec sed -i \
	"s/import { srand } from 'math';/\/\/ import { srand } from 'math';/g" \
	{} +

find ../feeds/ -type f -path "*/argon/header.ut" \
	-exec sed -i \
	"s/import { srand } from 'math';/\/\/ import { srand } from 'math';/g" \
	{} + 2>/dev/null || true

# ==============================================================================
# 7. 最终 .config 补充
# ==============================================================================

cat >> ../.config <<'CONFIGEOF'

# ------------------------------------------------------------------------------
# DaeWRT 核心软件
# ------------------------------------------------------------------------------

CONFIG_PACKAGE_luci-app-daed=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y

# sing-box：仅服务器
CONFIG_PACKAGE_sing-box=y

# Samba
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y

# ZeroTier
CONFIG_PACKAGE_zerotier=y
CONFIG_PACKAGE_luci-app-zerotier=y


# 存储
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-diskman=y

# LuCI
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-cpufreq=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_default-settings-chn=y

# 禁止重复/冲突组件
# CONFIG_PACKAGE_daed-next is not set
# CONFIG_PACKAGE_luci-app-homeproxy is not set
# CONFIG_PACKAGE_homeproxy is not set
# CONFIG_PACKAGE_luci-app-upnp is not set
# CONFIG_PACKAGE_miniupnpd is not set
# CONFIG_PACKAGE_kmod-nft-fullcone is not set

CONFIGEOF
