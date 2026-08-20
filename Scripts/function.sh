#!/bin/bash

function cat_kernel_config() {
  if [ -f "$1" ]; then
    cat >> "$1" <<EOF
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_CGROUPS=y
CONFIG_KPROBES=y
CONFIG_NET_INGRESS=y
CONFIG_NET_EGRESS=y
CONFIG_NET_SCH_INGRESS=m
CONFIG_NET_CLS_BPF=m
CONFIG_NET_CLS_ACT=y
CONFIG_BPF_STREAM_PARSER=y
CONFIG_DEBUG_INFO=y
# CONFIG_DEBUG_INFO_REDUCED is not set
CONFIG_DEBUG_INFO_BTF=y
CONFIG_KPROBE_EVENTS=y
CONFIG_BPF_EVENTS=y
CONFIG_NET_SCH_BPF=y
CONFIG_SCHED_CLASS_EXT=y
CONFIG_PROBE_EVENTS_BTF_ARGS=y
CONFIG_ARM64_CONTPTE=y
CONFIG_PERSISTENT_HUGE_ZERO_FOLIO=n
CONFIG_NO_PAGE_MAPMAP=n
CONFIG_ARM64_BRBE=y
CONFIG_NF_CONNTRACK_DSCPREMARK_EXT=y
EOF
    echo "cat_kernel_config to $1 done"
  fi
}

function cat_ebpf_config() {
  cat >> "$1" <<EOF
#eBPF
CONFIG_DEVEL=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_KERNEL_DEBUG_INFO_REDUCED=n
CONFIG_KERNEL_DEBUG_INFO_BTF=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_BPF=y
CONFIG_KERNEL_BPF_EVENTS=y
CONFIG_BPF_TOOLCHAIN_HOST=y
CONFIG_KERNEL_XDP_SOCKETS=y
CONFIG_PACKAGE_kmod-xdp-sockets-diag=y
CONFIG_KERNEL_TRANSPARENT_HUGEPAGE=y
# CONFIG_KERNEL_TRANSPARENT_HUGEPAGE_ALWAYS is not set
CONFIG_KERNEL_TRANSPARENT_HUGEPAGE_MADVISE=y
# CONFIG_KERNEL_TRANSPARENT_HUGEPAGE_NEVER is not set
EOF
}

function set_kernel_size() {
  image_file='./target/linux/qualcommax/image/ipq60xx.mk'
  if [ -f "$image_file" ]; then
    sed -i "/^define Device\/jdcloud_re-cs-02/,/^endef/ { /KERNEL_SIZE := 6144k/s//KERNEL_SIZE := 12288k/ }" "$image_file"
    echo "Kernel size for jdcloud_re-cs-02 expanded to 12M"
  fi
}

function enable_skb_recycler() {
  cat >> "$1" <<EOF
CONFIG_KERNEL_SKB_RECYCLER=y
CONFIG_KERNEL_SKB_RECYCLER_MULTI_CPU=y
EOF
}

function generate_config() {
  config_file=".config"
  # 合并设备专属配置和通用配置
  cat "$GITHUB_WORKSPACE/Config/${WRT_CONFIG}.txt" "$GITHUB_WORKSPACE/Config/GENERAL.txt" > "$config_file"
  
  # 【修复】正确提取 subtarget (如 ipq60xx)，而不是设备名
  local target=$(grep -m 1 -oP '^CONFIG_TARGET_[a-z0-9]+_\K[a-z0-9]+(?==y)' "$GITHUB_WORKSPACE/Config/$WRT_CONFIG.txt")
  
  if [ -z "$target" ]; then
    echo "Warning: Could not extract subtarget from config!"
  else
    echo "Detected subtarget: $target"
  fi

  # 增加 eBPF 和内存回收
  cat_ebpf_config "$config_file"
  enable_skb_recycler "$config_file"
  
  # 高通平台专属调整
  if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
    set_kernel_size
    if [ -n "$target" ]; then
      cat_kernel_config "./target/linux/qualcommax/${target}/config-default"
    fi
  fi
}
