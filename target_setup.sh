#!/usr/bin/env bash

# setup.sh - Installs the 'target' tool anywhere

TARGET_SCRIPT="$HOME/.target.sh"
TARGET_VARS="$HOME/.target_vars"


# Write the main 'target' script
#echo "Writing $TARGET_SCRIPT..."
cat > "$TARGET_SCRIPT" << 'EOF'
#!/usr/bin/env bash
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  SOURCED=1
else
  SOURCED=0
fi


TARGET_VARS="$HOME/.target_vars"
IPV4_REGEX='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
DOMAIN_REGEX='^([A-Za-z0-9](-?[A-Za-z0-9])*\.)+[A-Za-z]{2,}$'
# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load saved variables safely (handles space-separated lists)
if [ -f "$TARGET_VARS" ]; then
  while IFS='=' read -r key val; do
    # strip surrounding quotes, if any
    val=${val#\"}; val=${val%\"}
    export "$key"="$val"
  done < "$TARGET_VARS"
fi


# Show help menu
show_help() {
    cat << HELP
==========================================
 Target - Variable Shortcut Manager (v1.4)
==========================================

Usage: target <command> [args]

Commands:
  <name> [ip]     <name> [value]  Save an IPv4 or domain under 'name'.
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
     .. Created for RTX ..
========================================

HELP
}

# Main dispatch
cmd="$1"
if [ "$#" -gt 0 ]; then
    shift
fi

case "$cmd" in
  ""|help)
    show_help
    ;;

  uninstall)
    echo -e "${YELLOW}Uninstalling target tool...${NC}"
    
# Remove all Target traces from rc files
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$rc" ]; then
        sed -i.bak \
            -e '/# target tool/d' \
            -e '/source[[:space:]]\+.*\.target\.sh/d' \
            -e "/alias[[:space:]]\+target=.*\.target\.sh'/d" \
            -e '/^target() { source .*target\.sh "\$@"; }$/d' \
            "$rc"
        echo -e "${GREEN}Cleaned entries from $rc${NC}"
    fi
done
    # Unset any loaded variables
	if [ -f "$TARGET_VARS" ]; then
	    while IFS= read -r v; do 
	        unset "${v%%=*}" 2>/dev/null
	    done < "$TARGET_VARS"
	fi
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
    

    echo -e "${GREEN}Target tool completely uninstalled!${NC}"
    echo -e "${YELLOW}Please restart your terminal or start a new shell session.${NC}"
    
    if (( SOURCED )); then
      return 0
    else
      exit 0
    fi
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
	  value="$1"
	  if [ -z "$value" ]; then
	    # display
	    stored=$(grep -m1 "^${name}=" "$TARGET_VARS" | cut -d'=' -f2-)
	    if [ -z "$stored" ]; then
	      echo -e "${RED}Variable '$name' not set.${NC}"
	    else
	      echo -e "${CYAN}\$${name}${NC} -> ${GREEN}${stored}${NC}"
	    fi
	    exit
	  fi
	
	  # decide if IP or domain
	  if [[ "$value" =~ $IPV4_REGEX ]]; then
	    type="IP"
	  elif [[ "$value" =~ $DOMAIN_REGEX ]]; then
	    type="DOMAIN"
	  else
	    echo -e "${RED}Invalid format: '$value' is neither an IPv4 nor a valid domain.${NC}"
	    exit 1
	  fi
	
	  # save (allow multiple)
	  if grep -q "^${name}=" "$TARGET_VARS"; then
	    # append if not already present
	    old=$(grep "^${name}=" "$TARGET_VARS" | cut -d'=' -f2-)
	    if [[ ! " $old " =~ " $value " ]]; then
	      new="$old $value"
	      sed -i.bak "s|^${name}=.*|${name}=\"${new}\"|" "$TARGET_VARS"

	    fi
	  else
	    echo "${name}=\"${value}\"" >> "$TARGET_VARS"
	  fi
	
	  export "$name"="$value"
	  echo -e "${GREEN}Set ${type} '${name}' -> '${value}'${NC}"
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
  if ! grep -Fxq "target() { source \"$TARGET_SCRIPT\" \"\$@\"; }" "$rc"; then
    cat >> "$rc" << EOF

# target tool
target() { source "$TARGET_SCRIPT" "\$@"; }

EOF
  fi
done

# Finish
echo -e "\n${GREEN}Target Setup complete!${NC}"
echo "[*] Restart your terminal"
