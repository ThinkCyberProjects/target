#!/usr/bin/env bash

INSTALL_DIR="/opt/target"
TARGET_SCRIPT="$INSTALL_DIR/target.sh"
TARGET_ENV="$INSTALL_DIR/target.env"

# Require sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Create and install files
mkdir -p "$INSTALL_DIR"
cp "$(dirname "$0")/target.sh" "$TARGET_SCRIPT"
touch "$TARGET_ENV"

# Set permissions so user can use without sudo
chown -R "$SUDO_USER:$SUDO_USER" "$INSTALL_DIR"
chmod 775 "$INSTALL_DIR"
chmod 755 "$TARGET_SCRIPT"
chmod 664 "$TARGET_ENV"

# Append target function and source line to shell configs
for rc in "/home/$SUDO_USER/.bashrc" "/home/$SUDO_USER/.zshrc"; do
  [ -f "$rc" ] || touch "$rc"
  if ! grep -q 'target()' "$rc"; then
    cat >> "$rc" << EOF

# target tool
[ -f "/opt/target/target.env" ] && source "/opt/target/target.env"
target() { bash "/opt/target/target.sh" "\$@"; source "/opt/target/target.env" 2>/dev/null; }

EOF
    echo "[*] Updated $rc"
  fi
done

echo "[✔] Target installed to /opt/target"
echo "[*] Restart your terminal or run: source ~/.bashrc or source ~/.zshrc"
