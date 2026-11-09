#!/usr/bin/env bash
# 目标平台收尾修复与构建前调整。

fix_default_set() {
    local patches_dir="${PATCHES_DIR:-${BASE_PATH:-$SCRIPT_DIR}/patches}"

    # 删除默认密码
    sed -i "/shadow/d" $(find "$BUILD_DIR/feeds/luci/applications/luci-app-ttyd/" "$BUILD_DIR/package/" -type f -name "*default-settings" 2>/dev/null) 2>/dev/null || true
    # 修改默认主题为argon
    sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" $(find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" 2>/dev/null) 2>/dev/null || true

    if [ "$THEME_SET" = "argon" ] && [ -f "$patches_dir/990_set_argon_primary" ]; then
        install -Dm755 "$patches_dir/990_set_argon_primary" "$BUILD_DIR/files/etc/uci-defaults/990_set_argon_primary"
    fi

    if [ -f "$patches_dir/991_custom_settings" ]; then
        install -Dm755 "$patches_dir/991_custom_settings" "$BUILD_DIR/files/etc/uci-defaults/991_custom_settings"
    fi

    if [ -f "$patches_dir/earth.jpg.xz.b64" ]; then
        mkdir -p "$BUILD_DIR/files/www/luci-static/argon/background"
        base64 -d "$patches_dir/earth.jpg.xz.b64" | xz -d > "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg"
        chmod 644 "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg"
        local argon_bg_dir
        argon_bg_dir=$(find "$BUILD_DIR/feeds" "$BUILD_DIR/package" -type d -path "*/luci-theme-argon/htdocs/luci-static/argon/background" 2>/dev/null | head -n 1)
        if [ -n "$argon_bg_dir" ]; then
            rm -f "$argon_bg_dir"/* 2>/dev/null || true
            cp -f "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg" "$argon_bg_dir/earth.jpg"
        fi
    fi

    find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" \
        -exec sed -i "/attendedsysupgrade/d" {} + 2>/dev/null || true
}
