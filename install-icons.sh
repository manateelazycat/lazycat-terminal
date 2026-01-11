#!/bin/bash

# Install icons to user's local icon directory
ICON_DIR="$HOME/.local/share/icons/hicolor"
APP_DIR="$HOME/.local/share/applications"

# Create icon directories if they don't exist
mkdir -p "$ICON_DIR/32x32/apps"
mkdir -p "$ICON_DIR/48x48/apps"
mkdir -p "$ICON_DIR/96x96/apps"
mkdir -p "$ICON_DIR/128x128/apps"
mkdir -p "$ICON_DIR/scalable/apps"
mkdir -p "$APP_DIR"

# Copy icons to the icon directories
cp icons/32x32/lazycat-terminal.png "$ICON_DIR/32x32/apps/"
cp icons/48x48/lazycat-terminal.png "$ICON_DIR/48x48/apps/"
cp icons/96x96/lazycat-terminal.png "$ICON_DIR/96x96/apps/"
cp icons/128x128/lazycat-terminal.png "$ICON_DIR/128x128/apps/"
cp icons/lazycat-terminal.svg "$ICON_DIR/scalable/apps/"

# Install .desktop file
cp lazycat-terminal.desktop "$APP_DIR/"

# Update icon cache
gtk-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || gtk4-update-icon-cache -f -t "$ICON_DIR" 2>/dev/null || true

# Update desktop database
update-desktop-database "$APP_DIR" 2>/dev/null || true

echo "Icons and desktop file installed successfully!"
echo "Icon directory: $ICON_DIR"
echo "Desktop file: $APP_DIR/lazycat-terminal.desktop"
echo ""
echo "You may need to restart your window manager or log out/in for the changes to take effect."

