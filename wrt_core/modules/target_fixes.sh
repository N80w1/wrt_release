#!/usr/bin/env bash
# 目标平台收尾修复与构建前调整。

fix_default_set() {
    local patches_dir="${PATCHES_DIR:-${BASE_PATH:-$SCRIPT_DIR}/patches}"

    # 删除默认密码
    sed -i "/shadow/d" $(find "$BUILD_DIR/feeds/luci/applications/luci-app-ttyd" "$BUILD_DIR/package/" -type f -name "root" 2>/dev/null)

    # 修改默认主题为argon
    sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" $(find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" 2>/dev/null)

    if [ "$THEME_SET" = "argon" ] && [ -f "$patches_dir/990_set_argon_primary" ]; then
        install -Dm755 "$patches_dir/990_set_argon_primary" "$BUILD_DIR/files/etc/uci-defaults/990_set_argon_primary"
    fi

    if [ -f "$patches_dir/991_custom_settings" ]; then
        install -Dm755 "$patches_dir/991_custom_settings" "$BUILD_DIR/files/etc/uci-defaults/991_custom_settings"
    fi

    find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" \
        -exec sed -i "/attendedsysupgrade/d" {} + 2>/dev/null || true

    local patches_dir="${PATCHES_DIR:-${BASE_PATH:-$SCRIPT_DIR}/patches}"
    if [ -f "$patches_dir/earth.jpg.xz.b64" ]; then
        mkdir -p "$BUILD_DIR/files/www/luci-static/argon/background"
        python3 - "$patches_dir/earth.jpg.xz.b64" "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg" << 'EOF_PY' || true
import sys, base64, re, io
raw_b64 = re.sub(r'[^A-Za-z0-9+/=]', '', open(sys.argv[1]).read())
raw_b64 += '=' * ((4 - len(raw_b64) % 4) % 4)
data = base64.b64decode(raw_b64)
try:
    from PIL import Image
    im = Image.open(io.BytesIO(data)).convert("RGB")
    im.save(sys.argv[2], format="JPEG", quality=90)
except Exception:
    open(sys.argv[2], "wb").write(data)
EOF_PY
        chmod 644 "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg" 2>/dev/null || true
        local argon_bg_dir
        argon_bg_dir=$(find "$BUILD_DIR/feeds" "$BUILD_DIR/package" -type d -path "*/luci-theme-argon/htdocs/luci-static/argon/background" 2>/dev/null | head -n 1)
        if [ -n "$argon_bg_dir" ] && [ -s "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg" ]; then
            rm -f "$argon_bg_dir"/* 2>/dev/null || true
            cp -f "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg" "$argon_bg_dir/earth.jpg"
        fi
    fi
}

fix_miniupnpd() {
    local iptables_file="$BUILD_DIR/feeds/packages/net/miniupnpd/files/miniupnpd.defaults"
    local nftables_file="$BUILD_DIR/feeds/packages/net/miniupnpd/files/miniupnpd.nft.defaults"
    if [ -f "$iptables_file" ]; then
        sed -i 's/prerouting_rule/zone_wan_prerouting/g' "$iptables_file"
        sed -i 's/forwarding_rule/zone_wan_forward/g' "$iptables_file"
    fi
    if [ -f "$nftables_file" ]; then
        sed -i 's/prerouting_wan/prerouting_wan_upnp/g' "$nftables_file"
    fi
}

change_dnsmasq2full() {
    if [ -d "$BUILD_DIR/package/network/services/dnsmasq" ]; then
        find "$BUILD_DIR/package/network/services/dnsmasq" -type f -name "Makefile" \
            -exec sed -i 's/PKG_DEFAULT:=.*/PKG_DEFAULT:=dnsmasq-full/g' {} + 2>/dev/null || true
    fi
}

fix_mk_def_depends() {
    local makefiles
    makefiles=$(find "$BUILD_DIR/feeds" "$BUILD_DIR/package" -type f -name "Makefile" 2>/dev/null)
    if [ -n "$makefiles" ]; then
        echo "$makefiles" | xargs sed -i 's/DEFAULT_DEPENDS +=/DEPENDS +=/g' 2>/dev/null || true
    fi
}

fix_kconfig_recursive_dependency() {
    find "$BUILD_DIR/target/linux" -type f -name "Kconfig*" 2>/dev/null | xargs sed -i '/select PACKAGE_kmod-crypto-hash/d' 2>/dev/null || true
}

update_default_lan_addr() {
    local uci_defaults
    uci_defaults=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type f -name "*base-files*" -o -name "*uci-defaults*" 2>/dev/null)
    if [ -n "$uci_defaults" ] && [ -n "$LAN_IP" ]; then
        echo "$uci_defaults" | xargs sed -i "s/192.168.1.1/$LAN_IP/g" 2>/dev/null || true
    fi
}

remove_something_nss_kmod() {
    local nss_dir="$BUILD_DIR/package/kernel/mac80211"
    if [ -d "$nss_dir" ]; then
        find "$nss_dir" -type f -name "Makefile" -exec sed -i '/kmod-qca-nss-drv/d' {} + 2>/dev/null || true
    fi
}

update_affinity_script() {
    local irq_file
    irq_file=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type f -name "*set_irq_affinity*" 2>/dev/null | head -n 1)
    if [ -n "$irq_file" ]; then
        chmod +x "$irq_file" 2>/dev/null || true
    fi
}

update_ath11k_fw() {
    local ath11k_dir
    ath11k_dir=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type d -name "ath11k-firmware" 2>/dev/null | head -n 1)
    if [ -n "$ath11k_dir" ]; then
        touch "$ath11k_dir/.updated" 2>/dev/null || true
    fi
}

fix_mkpkg_format_invalid() {
    find "$BUILD_DIR/include" -type f -name "*.mk" 2>/dev/null | xargs sed -i 's/$(TAR) -/$(TAR) --no-same-owner -/g' 2>/dev/null || true
}

change_cpuusage() {
    local cpu_file
    cpu_file=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type f -name "*cpuusage*" 2>/dev/null | head -n 1)
    if [ -n "$cpu_file" ]; then
        sed -i 's/top -n 1/top -b -n 1/g' "$cpu_file" 2>/dev/null || true
    fi
}

update_nss_pbuf_performance() {
    local pbuf_file
    pbuf_file=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type f -name "*nss*pbuf*" 2>/dev/null | head -n 1)
    if [ -n "$pbuf_file" ]; then
        touch "$pbuf_file" 2>/dev/null || true
    fi
}

update_nss_diag() {
    local diag_file
    diag_file=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type f -name "*nss*diag*" 2>/dev/null | head -n 1)
    if [ -n "$diag_file" ]; then
        touch "$diag_file" 2>/dev/null || true
    fi
}

fix_compile_coremark() {
    local coremark_dir
    coremark_dir=$(find "$BUILD_DIR/package" "$BUILD_DIR/feeds" -type d -name "coremark" 2>/dev/null | head -n 1)
    if [ -n "$coremark_dir" ] && [ -f "$coremark_dir/Makefile" ]; then
        sed -i 's/-O2/-O3/g' "$coremark_dir/Makefile" 2>/dev/null || true
    fi
}

add_backup_info_to_sysupgrade() {
    local sysupgrade_conf="$BUILD_DIR/files/etc/sysupgrade.conf"
    if [ -f "$sysupgrade_conf" ]; then
        echo "/etc/config/" >> "$sysupgrade_conf"
    fi
}

fix_rust_compile_error() {
    local rust_mk
    rust_mk=$(find "$BUILD_DIR/include" "$BUILD_DIR/package" -type f -name "*rust*.mk" 2>/dev/null | head -n 1)
    if [ -n "$rust_mk" ]; then
        sed -i 's/CARGO_HOME/RUST_CARGO_HOME/g' "$rust_mk" 2>/dev/null || true
    fi
}
