#!/bin/bash

#WRT_REPO='https://github.com/LiBwrt/openwrt-6.x'
#WRT_BRANCH='k6.12-nss'

WRT_REPO='https://github.com/davidtall/immortalwrt'
WRT_BRANCH='viking-main'

#WRT_REPO='https://github.com/VIKINGYFY/immortalwrt'
#WRT_BRANCH='main'

if [ -n "$1" ]; then
    # 如果有传递参数，赋值给WRT_TARGET
    filename=$(basename "$1")
    export WRT_CONFIG="${filename%.*}"
else
    # 如果没有传递参数，设置默认值
    export WRT_CONFIG="IPQ60XX-NOWIFI"
fi

if [ -n "$2" ]; then
    WRT_REPO="$2"
fi

export WRT_DIR=wrt
export GITHUB_WORKSPACE=$(pwd)
export WRT_DATE=$(TZ=UTC-8 date +"%y.%m.%d_%H.%M.%S")
export WRT_VER=$(echo $WRT_REPO | cut -d '/' -f 5-)-$WRT_BRANCH
export WRT_TYPE=$(sed -n "1{s/^#//;s/\r$//;p;q}" "$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt")
export WRT_NAME='OWRT'
export WRT_SSID='OWRT'
export WRT_WORD='12345678'
export WRT_THEME='argon'
export WRT_IP='192.168.10.1'
export WRT_CI='WSL-OpenWRT-CI'
export WRT_ARCH=$(sed -n 's/.*_DEVICE_\(.*\)_DEVICE_.*/\1/p' "$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt" | head -n 1)
export CI_NAME='QCA-6.18-LiBwrt'
export WRT_TARGET=$(grep -m 1 -oP '^CONFIG_TARGET_\K[\w]+(?=\=y)' "$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt" | tr '[:lower:]' '[:upper:]')

# 1. 加载通用函数库
. "$GITHUB_WORKSPACE/Scripts/function.sh"

# 2. 克隆或更新代码库
if [ ! -d "$WRT_DIR" ]; then
  git clone --depth=1 --single-branch --branch "$WRT_BRANCH" "$WRT_REPO" "$WRT_DIR"
  cd "$WRT_DIR" || exit 1
else
  cd "$WRT_DIR" || exit 1
  git remote set-url origin "$WRT_REPO"
  rm -rf feeds/*
  git clean -f
  git reset --hard
  git pull
fi

# 3. 更新并安装 Feeds 依赖
./scripts/feeds update -a && ./scripts/feeds install -a

# 4. 执行自定义脚本与配置生成（使用子Shell避免目录错乱）
(
  cd package/ || exit 1
  [ -f "$GITHUB_WORKSPACE/Scripts/Packages.sh" ] && "$GITHUB_WORKSPACE/Scripts/Packages.sh"
  [ -f "$GITHUB_WORKSPACE/Scripts/Handles.sh" ] && "$GITHUB_WORKSPACE/Scripts/Handles.sh"
)

generate_config
[ -f "$GITHUB_WORKSPACE/Scripts/Settings.sh" ] && "$GITHUB_WORKSPACE/Scripts/Settings.sh"
[ -f "$GITHUB_WORKSPACE/diy.sh" ] && bash "$GITHUB_WORKSPACE/diy.sh"

# 5. 【核心修复】在编译和生成 defconfig 之前，强制修补源码库中的 stdcountof.h 硬编码
echo "=== 正在应用 stdcountof.h 兼容性补丁 ==="
find . -type f \( -name "options.h" -o -name "Makefile.in" -o -name "Makefile.am" \) \
  -exec sed -i 's/#include <stdcountof.h>/#define countof(a) (sizeof(a) \/ sizeof(*(a)))/g' {} + 2>/dev/null || true

grep -rl "stdcountof.h" . 2>/dev/null | xargs sed -i 's/#include <stdcountof.h>/#define countof(a) (sizeof(a) \/ sizeof(*(a)))/g' 2>/dev/null || true

# 6. 生成标准配置并预下载依赖包
make defconfig
make download -j$(nproc)

# 7. 启动编译（多线程优先，若报错自动降为单线程输出详细日志）
make -j$(nproc) || make V=s -j1
