#!/bin/bash
PKG_PATH="$GITHUB_WORKSPACE/$WRT_DIR/package/"

#修复Rust编译失败 (部分包可能依赖)
RUST_FILE="$(find "$PKG_PATH/../feeds/packages" -maxdepth 4 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	echo " "
	if sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"; then
		echo "rust has been fixed!"
	fi
fi
