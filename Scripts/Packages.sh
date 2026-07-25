#!/bin/bash

# ==============================================================================
# OpenWrt / DaeWRT 雅典娜定制包脚本
# 目标设备：JDCloud Athena / qualcommax ipq60xx
# 使用场景：
#   1. Daed 主力透明代理
#   2. HomeProxy 仅服务器端，必须保留
#   3. NSS 硬件加速
#   4. UPnP / Samba4 / ZeroTier
#   5. 雅典娜 LED / eMMC / USB 存储扩容
# ==============================================================================

# 如果命令失败立即停止
set -e

# ==============================================================================
# 通用函数：安装/更新 GitHub 包
# ==============================================================================
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)
	local REPO_NAME=${PKG_REPO#*/}

	echo " "
	echo ">>> 处理包：$PKG_NAME"
	echo ">>> 仓库：$PKG_REPO"
	echo ">>> 分支：$PKG_BRANCH"

	# 删除 feeds 中可能存在的同名或冲突包
	for NAME in "${PKG_LIST[@]}"; do
		echo "Search directory: $NAME"

		local FOUND_DIRS
		FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 4 -type d \
			\( -name "$NAME" -o -name "luci-theme-$NAME" -o -name "luci-app-$NAME" \) \
			2>/dev/null || true)

		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not found directory: $NAME"
		fi
	done

	# 如果本地已经存在同名目录，先删除，避免 git clone 失败
	rm -rf "./$PKG_NAME"
	rm -rf "./$REPO_NAME"

	# 克隆仓库
	git clone --depth=1 --single-branch --branch "$PKG_BRANCH" "https://github.com/$PKG_REPO.git"

	# 特殊处理
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find "./$REPO_NAME"/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
		rm -rf "./$REPO_NAME/"
	elif [[ "$PKG_SPECIAL" == "name" ]]; then
		mv -f "$REPO_NAME" "$PKG_NAME"
	fi
}

# ==============================================================================
# 清理函数：删除所有可能冲突的 HomeProxy / sing-box / helloworld 残留
# ==============================================================================
CLEAN_HOMEPROXY_SINGBOX() {
	echo ">>> 清理所有可能冲突的 HomeProxy / sing-box 残留..."

	rm -rf ../feeds/packages/net/sing-box
	rm -rf ../feeds/packages/net/homeproxy
	rm -rf ../feeds/luci/applications/luci-app-homeproxy

	rm -rf ./sing-box
	rm -rf ./homeproxy
	rm -rf ./luci-app-homeproxy

	rm -rf ../package/helloworld
	rm -rf ../package/sing-box
	rm -rf ../package/homeproxy
	rm -rf ../package/luci-app-homeproxy

	# 更广泛清理，防止其他 feed 残留
	find ../feeds ../package -maxdepth 6 -type d \
		\( -name "sing-box" -o -name "homeproxy" -o -name "luci-app-homeproxy" \) \
		-prune -exec rm -rf {} + 2>/dev/null || true

	echo ">>> HomeProxy / sing-box 残留清理完成"
}

# ==============================================================================
# 主题
# ==============================================================================
# 只保留 argon，主题包通常在源码或自定义 package 中已存在
# 如果 argon 不在默认源中，可取消下面注释
# UPDATE_PACKAGE "argon" "jerrykuku/luci-theme-argon" "master"
# UPDATE_PACKAGE "argon-config" "jerrykuku/luci-app-argon-config" "master"

# ==============================================================================
# 主力代理：Daed 透明代理
# ==============================================================================
UPDATE_PACKAGE "luci-app-daed" "QiuSimons/luci-app-daed" "kix"

# ==============================================================================
# 磁盘管理
# ==============================================================================
UPDATE_PACKAGE "diskman" "lisaac/luci-app-diskman" "master"

# ==============================================================================
# HomeProxy + sing-box
#
# 你之前的错误：
#   sing-box-1.12.25-r1
#   breaks: luci-app-homeproxy-20260717-r6[sing-box>=1.14.0_alpha1]
#
# 解决思路：
#   1. 拉取 sbwml/openwrt_helloworld v5
#   2. 使用其中 sing-box 和 luci-app-homeproxy
#   3. 如果 luci-app-homeproxy 仍然要求 sing-box >= 1.14.0_alpha1，
#      则自动 patch 依赖版本，使其允许 sing-box 1.12.25
#
# 注意：
#   patch 依赖版本只是让编译通过。
#   如果 HomeProxy 使用了 sing-box 1.14 的新特性，运行时可能异常。
#   但这是当前“必须 HomeProxy + 现有 sing-box 1.12.25”下的折中方案。
# ==============================================================================
CLEAN_HOMEPROXY_SINGBOX

echo ">>> 拉取 HomeProxy + sing-box ..."

rm -rf /tmp/helloworld
git clone --depth=1 --single-branch --branch v5 "https://github.com/sbwml/openwrt_helloworld.git" /tmp/helloworld

if [ ! -d "/tmp/helloworld/sing-box" ] || [ ! -d "/tmp/helloworld/luci-app-homeproxy" ]; then
	echo ">>> [错误] sbwml/openwrt_helloworld v5 缺少 sing-box 或 luci-app-homeproxy"
	rm -rf /tmp/helloworld
	exit 1
fi

# 复制到 package/helloworld 下，优先级更明确
mkdir -p ../package/helloworld

cp -r /tmp/helloworld/sing-box ../package/helloworld/sing-box
cp -r /tmp/helloworld/luci-app-homeproxy ../package/helloworld/luci-app-homeproxy

if [ -d "/tmp/helloworld/homeproxy" ]; then
	cp -r /tmp/helloworld/homeproxy ../package/helloworld/homeproxy
fi

if [ -d "/tmp/helloworld/v2ray-geodata" ]; then
	cp -r /tmp/helloworld/v2ray-geodata ../package/helloworld/v2ray-geodata
fi

rm -rf /tmp/helloworld

echo ">>> 检查 luci-app-homeproxy 对 sing-box 的依赖版本..."

# 如果 HomeProxy 依赖 sing-box >= 1.14.0_alpha1，则 patch 成 1.12.25
if grep -RInE "sing-box.*1\.14" ../package/helloworld/luci-app-homeproxy >/dev/null 2>&1; then
	echo ">>> 检测到 luci-app-homeproxy 依赖 sing-box >= 1.14"
	echo ">>> 当前使用 sing-box 1.12.25，开始 patch 依赖版本..."

	find ../package/helloworld/luci-app-homeproxy -type f \
		\( -name "Makefile" -o -name "*.mk" -o -name "*.json" -o -name "*.lua" \) \
		-exec sed -i 's/1\.14\.0_alpha1/1.12.25/g' {} +

	find ../package/helloworld/luci-app-homeproxy -type f \
		\( -name "Makefile" -o -name "*.mk" -o -name "*.json" -o -name "*.lua" \) \
		-exec sed -i 's/1\.14\.0/1.12.25/g' {} +

	find ../package/helloworld/luci-app-homeproxy -type f \
		\( -name "Makefile" -o -name "*.mk" -o -name "*.json" -o -name "*.lua" \) \
		-exec sed -i 's/1\.14/1.12.25/g' {} +

	echo ">>> luci-app-homeproxy 依赖版本已 patch 为 sing-box 1.12.25"
else
	echo ">>> 未检测到 sing-box >= 1.14 依赖，可能已经是兼容版本"
fi

# 检查 sing-box 版本
if [ -f "../package/helloworld/sing-box/Makefile" ]; then
	echo ">>> 当前 sing-box Makefile 版本信息："
	grep -E "PKG_VERSION|PKG_RELEASE" ../package/helloworld/sing-box/Makefile || true
fi

# 检查 HomeProxy 版本
if [ -f "../package/helloworld/luci-app-homeproxy/Makefile" ]; then
	echo ">>> 当前 luci-app-homeproxy Makefile 版本信息："
	grep -E "PKG_VERSION|PKG_RELEASE" ../package/helloworld/luci-app-homeproxy/Makefile || true
fi

echo ">>> HomeProxy / sing-box 拉取完成"

# ==============================================================================
# 删除官方冲突的默认插件
# 注意：不要删除 dae / daed / sing-box / homeproxy / v2ray-geodata
# ==============================================================================
rm -rf ../feeds/luci/applications/luci-app-passwall* || true
rm -rf ../feeds/luci/applications/luci-app-mosdns || true
rm -rf ../feeds/luci/applications/luci-app-dockerman || true
rm -rf ../feeds/luci/applications/luci-app-bypass* || true

# 复制自定义 package
cp -r "$GITHUB_WORKSPACE"/package/* ./ 2>/dev/null || true

# ==============================================================================
# 修复 luci-app-daed 相关 Makefile 和启动逻辑
# ==============================================================================
if [ -f "luci-app-daed/daed/Makefile" ]; then
	sed -i 's/pnpm install ; \\/pnpm install --no-frozen-lockfile ; \\/g' luci-app-daed/daed/Makefile
	sed -i 's|github.com/daeuniverse/quic-go|github.com/olicesx/quic-go|g' luci-app-daed/daed/Makefile
fi

if [ -f "luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed" ]; then
	sed -i 's|/run/i\\  procd_set_param|/procd_set_param command/i \\\tprocd_set_param|g' luci-app-daed/luci-app-daed/root/etc/init.d/luci_daed
fi

# ==============================================================================
# 刷新 package 缓存
# ==============================================================================
rm -rf ../tmp/

# ==============================================================================
# 追加 .config
# ==============================================================================
cat >> ../.config <<EOF

# ==============================================================================
# 防冲突补丁
# ==============================================================================
# CONFIG_PACKAGE_luci-light is not set
# CONFIG_PACKAGE_dnsmasq is not set
# CONFIG_PACKAGE_firewall is not set
# CONFIG_PACKAGE_iptables is not set
# CONFIG_PACKAGE_kmod-ipt-core is not set
# CONFIG_PACKAGE_luci-ssl is not set
# CONFIG_PACKAGE_luci-ssl-wolfssl is not set
# CONFIG_PACKAGE_px5g is not set
# CONFIG_PACKAGE_luci-app-passwall is not set
# CONFIG_PACKAGE_luci-app-mosdns is not set
# CONFIG_PACKAGE_luci-app-dockerman is not set

# 注意：
# 不要禁用 wpad-basic，除非你明确知道要使用哪个 hostapd/wpad
# 否则可能导致 WiFi 不可用

# 注意：
# 不要禁用 kmod-nft-fullcone，Daed 可能需要

# ==============================================================================
# 目标平台：京东云雅典娜 IPQ60xx
# ==============================================================================
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq60xx=y
CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_athena=y
CONFIG_TARGET_MULTI_PROFILE=n
CONFIG_TARGET_PER_DEVICE_ROOTFS=n
CONFIG_TARGET_ROOTFS_SQUASHFS=y
CONFIG_TARGET_ROOTFS_INITRAMFS=n

# ==============================================================================
# 编译优化
# ==============================================================================
CONFIG_DEVEL=n
CONFIG_CCACHE=y
CONFIG_AUTOREMOVE=y
CONFIG_KERNEL_CC_OPTIMIZE_FOR_PERFORMANCE=y
CONFIG_ATH11K_MEM_PROFILE_1G=y
CONFIG_IPQ_MEM_PROFILE_1024=y

# ==============================================================================
# LuCI / 主题 / 中文
# ==============================================================================
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-lib-base=y
CONFIG_PACKAGE_luci-lib-ipkg=y
CONFIG_PACKAGE_luci-ssl-openssl=y
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_luci-app-firewall4=y
CONFIG_PACKAGE_luci-app-opkg=y
CONFIG_PACKAGE_luci-app-fstab=y
CONFIG_PACKAGE_luci-app-mountd=y
CONFIG_PACKAGE_luci-app-ttyd=y
CONFIG_PACKAGE_luci-app-cpufreq=y
CONFIG_PACKAGE_default-settings-chn=y

# ==============================================================================
# Daed 主力透明代理
# ==============================================================================
CONFIG_PACKAGE_luci-app-daed=y
CONFIG_PACKAGE_dae=y
CONFIG_PACKAGE_daed=y
CONFIG_PACKAGE_daed-next=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_v2ray-geoip=y
CONFIG_PACKAGE_v2ray-geosite=y
CONFIG_PACKAGE_v2ray-geodata-updater=y

# ==============================================================================
# HomeProxy 服务器端
# ==============================================================================
CONFIG_PACKAGE_luci-app-homeproxy=y
CONFIG_PACKAGE_homeproxy=y
CONFIG_PACKAGE_sing-box=y

# ==============================================================================
# 常用插件：UPnP / Samba4 / ZeroTier
# ==============================================================================
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_miniupnpd=y
CONFIG_PACKAGE_luci-app-samba4=y
CONFIG_PACKAGE_samba4-server=y
CONFIG_PACKAGE_wsdd2=y
CONFIG_PACKAGE_luci-app-zerotier=y
CONFIG_PACKAGE_zerotier=y

# ==============================================================================
# 实用工具
# ==============================================================================
CONFIG_PACKAGE_luci-app-diskman=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_autocore=y
CONFIG_PACKAGE_coremark=y
CONFIG_PACKAGE_htop=y
CONFIG_PACKAGE_iperf3=y
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_wget-ssl=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_bind-dig=y
CONFIG_PACKAGE_bind-nslookup=y
CONFIG_PACKAGE_tcpdump=y
CONFIG_PACKAGE_ethtool=y
CONFIG_PACKAGE_conntrack=y

# ==============================================================================
# 雅典娜专属：LED / eMMC / 挂载扩容
# ==============================================================================
CONFIG_PACKAGE_luci-app-athena-led=y
CONFIG_PACKAGE_athena-led-control=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_automount=y
CONFIG_PACKAGE_blkid=y
CONFIG_PACKAGE_lsblk=y
CONFIG_PACKAGE_fdisk=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_resize2fs=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_tune2fs=y
CONFIG_PACKAGE_kmod-mmc=y
CONFIG_PACKAGE_kmod-sdhci=y
CONFIG_PACKAGE_kmod-sdhci-msm=y
CONFIG_PACKAGE_kmod-hwmon-core=y

# ==============================================================================
# USB / 存储
# ==============================================================================
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-xhci=y
CONFIG_PACKAGE_kmod-usb-dwc3=y
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-extras=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y

# ==============================================================================
# 文件系统
# ==============================================================================
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-f2fs=y
CONFIG_PACKAGE_mkf2fs=y
CONFIG_PACKAGE_f2fsck=y
CONFIG_PACKAGE_kmod-fs-ntfs3=y
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_exfat-fsck=y
CONFIG_PACKAGE_kmod-fs-vfat=y

# 中文与基础编码支持
CONFIG_PACKAGE_kmod-nls-base=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y
CONFIG_PACKAGE_kmod-nls-utf8=y
CONFIG_PACKAGE_kmod-nls-cp936=y

# ==============================================================================
# WiFi / 平台
# ==============================================================================
CONFIG_PACKAGE_kmod-ath11k=y
CONFIG_PACKAGE_iwinfo=y
CONFIG_PACKAGE_wireless-regdb=y

# ==============================================================================
# NSS 硬件加速
# ==============================================================================
CONFIG_PACKAGE_kmod-qca-nss-drv=y
CONFIG_PACKAGE_kmod-qca-nss-ecm=y
CONFIG_PACKAGE_kmod-qca-nss-drv-bridge-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-drv-vlan-mgr=y
CONFIG_PACKAGE_kmod-qca-nss-drv-pppoe=y
CONFIG_PACKAGE_kmod-qca-nss-drv-qdisc=y
CONFIG_PACKAGE_kmod-qca-nss-drv-map-t=y
CONFIG_PACKAGE_kmod-qca-nss-crypto=y

# ==============================================================================
# 防火墙 / NFT / Daed 内核依赖
# ==============================================================================
CONFIG_PACKAGE_firewall4=y
CONFIG_PACKAGE_nftables=y
CONFIG_PACKAGE_nftables-json=y
CONFIG_PACKAGE_iptables-nft=y
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-nf-nat=y
CONFIG_PACKAGE_kmod-nf-flow=y
CONFIG_PACKAGE_kmod-nft-core=y
CONFIG_PACKAGE_kmod-nft-nat=y
CONFIG_PACKAGE_kmod-nft-offload=y
CONFIG_PACKAGE_kmod-nft-fullcone=y
CONFIG_PACKAGE_kmod-nft-socket=y
CONFIG_PACKAGE_kmod-nft-fib=y
CONFIG_PACKAGE_kmod-nft-tproxy=y
CONFIG_PACKAGE_kmod-nft-queue=y
CONFIG_PACKAGE_kmod-nft-bridge=y
CONFIG_PACKAGE_kmod-nft-xfrm=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_kmod-netlink-diag=y

# ==============================================================================
# IPv6
# ==============================================================================
CONFIG_PACKAGE_odhcp6c=y
CONFIG_PACKAGE_odhcpd-ipv6only=y
CONFIG_PACKAGE_ip6tables-nft=y
CONFIG_PACKAGE_kmod-nf-conntrack6=y
CONFIG_PACKAGE_kmod-nf-nat6=y

# ==============================================================================
# PPPoE 拨号
# 如果路由器只是 DHCP 上网，可以删除或注释本节
# ==============================================================================
CONFIG_PACKAGE_ppp=y
CONFIG_PACKAGE_ppp-mod-pppoe=y
CONFIG_PACKAGE_luci-proto-ppp=y
CONFIG_PACKAGE_kmod-ppp=y
CONFIG_PACKAGE_kmod-pppoe=y

# ==============================================================================
# 网络性能优化
# ==============================================================================
CONFIG_PACKAGE_kmod-tcp-bbr=y
CONFIG_DEFAULT_tcp_bbr=y
EOF

echo ">>> Packages.sh 执行完成"
