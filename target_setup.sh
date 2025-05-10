#!/usr/bin/env bash

# setup.sh - Installs the 'target' tool anywhere

TARGET_SCRIPT="$HOME/.target.sh"
TARGET_VARS="$HOME/.target_vars"

# Write the main 'target' script
#echo "Writing $TARGET_SCRIPT..."
cat > "$TARGET_SCRIPT" << 'EOF'
#!/usr/bin/env bash

TARGET_VARS="$HOME/.target_vars"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load saved variables
[ -f "$TARGET_VARS" ] && source "$TARGET_VARS"

# Show help menu
show_help() {
    cat << HELP
==========================================
 Target - Variable Shortcut Manager (v1.2)
==========================================

Usage: target <command> [args]

Commands:
  <name> [ip]     Save IP under 'name', or if no IP given, show saved IP.
  all             List all saved variables.
  rng             Show /24 network ranges and save to 'rng' variable.
  clear           Erase all saved variables.
  delete <name>   Remove variable 'name'.
  export          Export variables to a timestamped file in current dir.
  uninstall       Completely uninstall target tool.
  help            Show this menu.

Examples:
  target myhost 192.168.1.5		# Save the IP into 'myhost'
  target myhost          		# Show IP of 'myhost'
  target rng             		# Get local /24s
  target uninstall       		# Completely remove target tool

========================================
     .. Created by DS for RTX ..
========================================

HELP
}

# Main dispatch
cmd="$1"
if [ "$#" -gt 0 ]; then
    shift
fi

case "$cmd" in
  help|"")
    show_help
    ;;

  uninstall)
    echo -e "${YELLOW}Uninstalling target tool...${NC}"
    
    # Remove alias from shell rc files
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ]; then
            # Remove the alias line and empty lines around it
            sed -i.bak '/# target tool/d' "$rc"
            sed -i '/alias target=.source.*target\.sh.*/d' "$rc"
            echo -e "${GREEN}Removed alias from $rc${NC}"
        fi
    done
    
    # Remove created files
    if [ -f "$TARGET_VARS" ]; then
        rm -f "$TARGET_VARS"
        echo -e "${GREEN}Removed $TARGET_VARS${NC}"
    fi
    
    # Remove the script file itself
    SCRIPT_PATH="$HOME/.target.sh"
    if [ -f "$SCRIPT_PATH" ]; then
        rm -f "$SCRIPT_PATH"
        echo -e "${GREEN}Removed $SCRIPT_PATH${NC}"
    fi
    
    # Unset any loaded variables
    if [ -f "$TARGET_VARS" ]; then
        while IFS= read -r v; do 
            unset "${v%%=*}" 2>/dev/null
        done < "$TARGET_VARS"
    fi
    
    echo -e "${GREEN}Target tool completely uninstalled!${NC}"
    echo -e "${YELLOW}Please restart your terminal or start a new shell session.${NC}"
    
    # Since we're running through source, we need to return
    return 0
    ;;

  clear)
    if [ -f "$TARGET_VARS" ]; then
      while IFS= read -r v; do unset "${v%%=*}"; done < "$TARGET_VARS"
      : > "$TARGET_VARS"
    fi
    echo -e "${YELLOW}All variables cleared.${NC}"
    ;;

  export)
    outfile="target_export_$(date +%Y%m%d_%H%M%S).txt"
    {
      echo "Target Variables Export - $(date)"
      echo "----------------------------------------"
      if [ -s "$TARGET_VARS" ]; then
        while IFS='=' read -r key value; do
          printf "%-20s -> %s\n" "\$${key}" "$value"
        done < "$TARGET_VARS"
      else
        echo "No variables to export."
      fi
    } > "./$outfile"
    echo -e "${CYAN}Exported variables to ${NC}$(pwd)/$outfile"
    ;;

  rng)
    echo "==== Gathering Network Ranges ===="
    networks=()
    while read -r iface cidr; do
      ip=${cidr%/*}
      net=${ip%.*}.0/24
      echo -e "${CYAN}${iface}${NC} -> ${GREEN}${net}${NC}"
      networks+=("$net")
    done < <(ip -4 -o addr show scope global | awk '!/ lo /{print $2, $4}')
    if [ "${#networks[@]}" -eq 0 ]; then
      echo -e "${RED}No non-loopback interfaces found.${NC}"
    else
      rng_val=$(printf "%s " "${networks[@]}")
      rng_val=${rng_val% }
      if grep -q '^rng=' "$TARGET_VARS"; then
        sed -i "s|^rng=.*|rng=$rng_val|" "$TARGET_VARS"
      else
        echo "rng=$rng_val" >> "$TARGET_VARS"
      fi
      export rng="$rng_val"
      echo -e "${GREEN}Saved 'rng' = $rng_val${NC}"
    fi
    ;;

  delete)
    name="$1"
    if [ -z "$name" ]; then
      echo -e "${RED}Missing variable name.${NC}"
      show_help
      return
    fi
    grep -v "^${name}=" "$TARGET_VARS" > "${TARGET_VARS}.tmp" && mv "${TARGET_VARS}.tmp" "$TARGET_VARS"
    unset "$name"
    echo -e "${YELLOW}Variable '$name' deleted.${NC}"
    ;;

  all)
    echo "==== Current Variables ===="
    if [ -s "$TARGET_VARS" ]; then
      while IFS='=' read -r key value; do
        printf "%-20s -> %s\n" "\$${key}" "$value"
      done < "$TARGET_VARS"
    else
      echo -e "${RED}No variables available.${NC}"
    fi
    ;;

  *)
    name="$cmd"
    ipaddr="$1"
    if [ -z "$ipaddr" ]; then
      val=$(grep -m1 "^${name}=" "$TARGET_VARS" | cut -d'=' -f2-)
      if [ -z "$val" ]; then
        echo -e "${RED}Variable '$name' not set.${NC}"
      else
        echo -e "${CYAN}\$${name}${NC} -> ${GREEN}${val}${NC}"
      fi
    else
      if [[ ! "$ipaddr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid IP format: $ipaddr${NC}" >&2
        exit 1
      fi
      if grep -q "^${name}=" "$TARGET_VARS"; then
        sed -i "s|^${name}=.*|${name}=${ipaddr}|" "$TARGET_VARS"
      else
        echo "${name}=${ipaddr}" >> "$TARGET_VARS"
      fi
      export "$name"="$ipaddr"
      echo -e "${GREEN}Set '${name}' to '${ipaddr}' and saved to ${TARGET_VARS}.${NC}"
    fi
    ;;
esac
EOF

# Make it executable
chmod +x "$TARGET_SCRIPT"

# Ensure the variables file exists
touch "$TARGET_VARS"

# Append alias to shell rc files if missing
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc" ] || touch "$rc"
  if ! grep -Fxq "alias target='source $TARGET_SCRIPT'" "$rc"; then
    cat >> "$rc" << ALIAS

# target tool
alias target='source $TARGET_SCRIPT'
ALIAS
  fi
done

# Finish
echo -e "\n${GREEN}Target Setup complete!${NC}"
echo "[*] Restart your terminal"
