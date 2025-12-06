#!/usr/bin/env bash
set -euo pipefail

# Make sure gum is available before running any of the status helpers.
if ! command -v gum >/dev/null 2>&1; then
    # install gum on ubuntu for now (see https://github.com/charmbracelet/gum#installation)
    echo "gum not found, installing..." >&2
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
	cat <<'EOF' >&2
We have installed gum for you.
Please re-run server_mgmt.sh after the installation is complete.
EOF
	exit 1
fi

# require root privileges for checking system configuration
if [[ $EUID -ne 0 ]]; then
	cat <<'EOF' >&2
server_mgmt.sh inspects the host configuration and therefore must run with root privileges.
Invoke it with sudo (sudo ./server_mgmt.sh) or run it as root before checking again.
EOF
	exit 1
fi

results=()
failed=0

execute_check() {
	local label=$1
	local -n script=$2
	if gum spin --spinner line --title "Checking $label" -- bash -c "$script"; then
		results+=("✅ $label")
	else
		results+=("❌ $label")
		failed=1
	fi
}

# validate script snippets
check_update=$(cat <<'EOF'
set -euo pipefail
[[ -d /var/lib/apt/lists ]] && [[ $(find /var/lib/apt/lists -maxdepth 1 -type f 2>/dev/null | wc -l) -gt 0 ]]
EOF
)

check_packages=$(cat <<'EOF'
set -euo pipefail
packages=(openssh-server ufw build-essential curl wget git tar gzip zip unzip rsync cron nginx mysql-server mysql-client php php-fpm php-mysql php-xml php-mbstring php-curl php-zip php-gd php-cli)
missing=()
for pkg in "${packages[@]}"; do
	if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
		missing+=("$pkg")
	fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
	printf "Missing packages: %s\n" "${missing[*]}" >&2
	exit 1
fi
EOF
)

check_firewall=$(cat <<'EOF'
set -euo pipefail
status=$(ufw status)
printf '%s' "$status" | grep -q "Status: active"
printf '%s' "$status" | grep -q "OpenSSH"
printf '%s' "$status" | grep -q "Nginx Full"
EOF
)

check_library=$(cat <<'EOF'
set -euo pipefail
[[ -d /var/www/library ]] || exit 1
[[ -f /var/www/library/info.php ]] || exit 1
grep -q "phpinfo" /var/www/library/info.php
EOF
)

check_nginx=$(cat <<'EOF'
set -euo pipefail
[[ -f /etc/nginx/sites-available/library ]] || exit 1
[[ -L /etc/nginx/sites-enabled/library ]] || exit 1
[[ "$(readlink -f /etc/nginx/sites-enabled/library)" == "/etc/nginx/sites-available/library" ]] || exit 1
nginx -t >/dev/null
systemctl is-active --quiet nginx
EOF
)

check_user_group=$(cat <<'EOF'
set -euo pipefail
user_to_check="sysadmin"
group_to_check="admin"
id "$user_to_check" >/dev/null 2>&1
getent group "$group_to_check" >/dev/null 2>&1
groups "$user_to_check" | grep -q "\b$group_to_check\b"
EOF
)

check_permission=$(cat <<'EOF'
set -euo pipefail
user_to_check="sysadmin"
group_to_check="admin"
[[ "$(stat -c '%U:%G' /var/www/library)" == "${user_to_check}:${group_to_check}" ]]
[[ "$(stat -c '%U:%G' /etc/nginx/nginx.conf)" == "${user_to_check}:${group_to_check}" ]]
[[ "$(stat -c '%U:%G' /etc/nginx/sites-available/library)" == "${user_to_check}:${group_to_check}" ]]
EOF
)

execute_check "[00-system-update.sh] APT cache" check_update
execute_check "[01-install-deps.sh] Packages" check_packages
execute_check "[02-serversetup.sh] Firewall + PHP" check_firewall
execute_check "[02-serversetup.sh] Library directory" check_library
execute_check "[03-webserversetup.sh] Nginx site" check_nginx
execute_check "[04-usercreation.sh] User & Group" check_user_group
execute_check "[05-permissionsetup.sh] Permissions" check_permission

summary="$(printf "%s\n" "${results[@]}")"
if [[ $failed -eq 0 ]]; then
	gum style --border double --padding "1 2" --margin "1" -- <<EOF
Library management checks succeeded
-------------------------------
$summary
EOF
	exit 0
else
	gum style --border double --border-foreground 208 --padding "1 2" --margin "1" -- <<EOF
Library management checks failed
------------------------------
$summary
EOF
	exit 1
fi
