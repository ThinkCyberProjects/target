#!/usr/bin/env bash

TARGET_ENV="/opt/target/target.env"

show_help() {
  cat << EOF
Commands:
  <name> <value>    Set variable
  <name>            Show variable value
  all               Show all variables
  delete <name>     Delete a variable
  clear             Remove all variables
  export            Save readable export file (target_export_TIMESTAMP.txt)
  rng               Save /24 network ranges to 'rng'
  uninstall         Remove the tool
  help              Show this help
EOF
}

validate_name() {
  [[ "$1" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}

case "$1" in
  "" | help)
    show_help
    ;;
  all)
    if [ ! -s "$TARGET_ENV" ]; then
      echo "No variables found."
      exit 0
    fi
    echo "==== Current Variables ===="
    grep '^export ' "$TARGET_ENV" | while read -r line; do
      name=$(echo "$line" | cut -d' ' -f2 | cut -d= -f1)
      val=$(echo "$line" | cut -d= -f2- | sed 's/^"//;s/"$//')
      printf "\$%-15s -> %s\n" "$name" "$val"
    done
    ;;
  delete)
    shift
    name="$1"
    validate_name "$name" || { echo "Invalid variable name."; exit 1; }
    sed -i "/^export $name=/d" "$TARGET_ENV"
    echo "Deleted variable '$name'."
    ;;
  clear)
    > "$TARGET_ENV"
    echo "All variables cleared."
    ;;
  export)
    outfile="target_export_$(date +%Y%m%d_%H%M%S).txt"
    outpath="$(pwd)/$outfile"
    {
      echo "Target Variables Export - $(date)"
      echo "----------------------------------------"
      grep '^export ' "$TARGET_ENV" | while read -r line; do
        name=$(echo "$line" | cut -d' ' -f2 | cut -d= -f1)
        val=$(echo "$line" | cut -d= -f2- | sed 's/^"//;s/"$//')
        printf "\$%-15s -> %s\n" "$name" "$val"
      done
    } > "$outpath"
    echo "Exported to: $outpath"
    ;;
  rng)
    echo "==== Gathering Network Ranges ===="
    networks=()
    while read -r iface cidr; do
      ip=${cidr%/*}
      net=${ip%.*}.0/24
      echo "$iface -> $net"
      networks+=("$net")
    done < <(ip -4 -o addr show scope global | awk '!/ lo /{print $2, $4}')
    rng_val=$(printf "%s " "${networks[@]}" | sed 's/ *$//')
    sed -i '/^export rng=/d' "$TARGET_ENV"
    echo "export rng=\"$rng_val\"" >> "$TARGET_ENV"
    echo "Saved 'rng' = $rng_val"
    ;;
  uninstall)
    echo "Uninstalling target tool..."
    echo "Removing /opt/target (requires sudo)..."
    sudo rm -rf "/opt/target"
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
      sed -i.bak '/# target tool/,+2d' "$rc"
    done
    echo "Target tool removed. Please restart your terminal."
    ;;
  *)
    name="$1"
    shift
    validate_name "$name" || { echo "Invalid variable name."; exit 1; }

    if [ -z "$1" ]; then
      val=$(grep "^export $name=" "$TARGET_ENV" | cut -d= -f2- | sed 's/^"//;s/"$//')
      [ -z "$val" ] && echo "Variable '$name' not set." || echo "\$$name -> $val"
      exit
    fi

    value="$1"

    if grep -q "^export $name=" "$TARGET_ENV"; then
      old_val=$(grep "^export $name=" "$TARGET_ENV" | cut -d= -f2- | sed 's/^"//;s/"$//')
      echo "Variable '$name' is already set to '$old_val'. Overwrite? (y/N)"
      read -r confirm
      [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
      sed -i "/^export $name=/d" "$TARGET_ENV"
    fi

    echo "export $name=\"$value\"" >> "$TARGET_ENV"
    echo "Set \$$name = $value"
    ;;
esac
