#!/usr/bin/env bash
# 目标平台收尾修复与构建前调整。

apply_argon_custom_settings() {
    if [ "$THEME_SET" != "argon" ]; then
        return 0
    fi

    install -Dm755 "$PATCHES_DIR/990_set_argon_primary" "$BUILD_DIR/files/etc/uci-defaults/990_set_argon_primary"

    if [ -f "$PATCHES_DIR/earth.jpg.xz.b64" ]; then
        mkdir -p "$BUILD_DIR/files/www/luci-static/argon/background"
        base64 -d "$PATCHES_DIR/earth.jpg.xz.b64" | xz -d > "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg"
        chmod 644 "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg"
        # 同时覆盖 feeds 中 argon 主题自带的 background 目录，彻底清理 README.md 等杂项文件
        local argon_bg_dir
        argon_bg_dir=$(find "$BUILD_DIR/feeds" "$BUILD_DIR/package" -type d -path "*/luci-theme-argon/htdocs/luci-static/argon/background" 2>/dev/null | head -n 1)
        if [ -n "$argon_bg_dir" ]; then
            rm -f "$argon_bg_dir"/* 2>/dev/null || true
            cp -f "$BUILD_DIR/files/www/luci-static/argon/background/earth.jpg" "$argon_bg_dir/earth.jpg"
        fi
    fi
}

apply_common_custom_settings() {
    install -Dm755 "$PATCHES_DIR/991_custom_settings" "$BUILD_DIR/files/etc/uci-defaults/991_custom_settings"
}

remove_attendedsysupgrade_dependencies() {
    find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" \
        -exec sed -i "/attendedsysupgrade/d" {} +
}
