# Target Tool

**Target** is a lightweight, bash-based IP management utility crafted for red teams and security professionals. It lets you name, store, and retrieve IP addresses on-the-fly, making enumeration and exploitation faster and more organized.

> No bloated dependencies. No database. Just sharp, shell-native command-line efficiency.

---

## Features

- 🔹 Store IPs under human-readable names
- 🔹 Auto-discover local /24 ranges
- 🔹 Export saved targets to a file
- 🔹 Instantly integrate with `nmap`, `nxc`, `enum4linux`, and others
- 🔹 Easy uninstall, clean session clearing

---

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/ThinkCyberProjects/target/main/target_setup.sh | bash
source ~/.bashrc # or ~/.zshrc depending on your shell
```

---

## Usage

```bash
target <name> [ip]    # Save IP under a name, or retrieve IP by name
target all            # List all stored targets
target rng            # Auto-detect local /24s and save as $rng
target delete <name>  # Delete a saved target
target clear          # Remove all targets
target export         # Export all targets to timestamped file
target uninstall      # Completely remove the tool
```

---

## Examples

### Save and Retrieve
```bash
target web 10.10.10.5
target dc1 192.168.56.100

echo $web   # Outputs 10.10.10.5
echo $dc1   # Outputs 192.168.56.100
```

### Integration with Tools

#### **Nmap**
```bash
nmap -sC -sV -Pn $web
nmap -p- $dc1
nmap -iL <(echo $rng | tr ' ' '\n')
```

#### **NXC (Netexec / CrackMapExec)**
```bash
nxc smb $dc1 -u admin -p 'Summer2024!'
nxc smb $rng --shares
```

#### **Enum4linux**
```bash
enum4linux -a $dc1
```

#### **Hydra, Nikto, Curl, Gobuster, etc.**
```bash
hydra -l admin -P rockyou.txt smb://$web
nikto -h http://$web
curl http://$web/index.php
```

#### **Export for Notes or Reporting**
```bash
target export  # Saves IP list with names to a .txt file
```

---

## Uninstall
```bash
target uninstall
```
This removes all aliases, scripts, and variables. No trace left.

---

## Who is this for?
- Red Team Operators
- CTF Players
- Penetration Testers
- OSCP/CRTP/CRTO candidates who want clean opsec tooling

---

## License
MIT License (do what you want, but don't be evil)

---

## ⚡️ Pro Tip
Use `target rng` early in your engagement to auto-populate `$rng` with active /24s for use in bulk scanning.

```bash
nmap -sn $rng
```

---

## Contribute
Pull requests are welcome. If you've got aliases or scripts to hook into other tools, share them.

**Stay sharp. Stay fast. Stay stealthy.**
