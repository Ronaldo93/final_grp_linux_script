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

# handle ctrl c
trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT

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

check_packages=$(
  cat <<'EOF'
set -euo pipefail
packages=(openssh-server ufw build-essential curl wget git tar gzip zip unzip rsync cron nginx mysql-server mysql-client php php-fpm php-mysql php-xml php-mbstring php-curl php-zip php-gd php-cli)
missing=()
for pkg in "${packages[@]}"; do
	if ! sudo dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
		missing+=("$pkg")
	fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
	printf "Missing packages: %s\n" "${missing[*]}" >&2
	exit 1
fi
EOF
)

check_firewall=$(
  cat <<'EOF'
set -euo pipefail
status=$(sudo ufw status)
printf '%s' "$status" | grep -q "Status: active"
printf '%s' "$status" | grep -q "OpenSSH"
printf '%s' "$status" | grep -q "Nginx Full"
EOF
)

check_library=$(
  cat <<'EOF'
set -euo pipefail
sudo test -d /var/www/library || exit 1
sudo test -f /var/www/library/index.php || exit 1
EOF
)

check_nginx=$(
  cat <<'EOF'
set -euo pipefail
sudo test -f /etc/nginx/sites-available/library || exit 1
sudo test -L /etc/nginx/sites-enabled/library || exit 1
[[ "$(sudo readlink -f /etc/nginx/sites-enabled/library)" == "/etc/nginx/sites-available/library" ]] || exit 1
sudo nginx -t >/dev/null
sudo systemctl is-active --quiet nginx
EOF
)

check_user_group=$(
  cat <<'EOF'
set -euo pipefail
user_to_check="sysadmin"
group_to_check="admin"
sudo id "$user_to_check" >/dev/null 2>&1
sudo getent group "$group_to_check" >/dev/null 2>&1
sudo groups "$user_to_check" | grep -qE "\b$group_to_check\b"
EOF
)

check_permission=$(
  cat <<'EOF'
set -euo pipefail
user_to_check="sysadmin"
group_to_check="admin"
[[ "$(sudo stat -c '%U:%G' /var/www/library)" == "${user_to_check}:${group_to_check}" ]]
[[ "$(sudo stat -c '%U:%G' /etc/nginx/nginx.conf)" == "${user_to_check}:${group_to_check}" ]]
[[ "$(sudo stat -c '%U:%G' /etc/nginx/sites-available/library)" == "${user_to_check}:${group_to_check}" ]]
EOF
)

check_website_config=$(
  cat <<'EOF'
set -euo pipefail
config_file="/etc/nginx/sites-available/library"
sudo test -f "$config_file" || exit 1
# Verify listening on port 80
sudo grep -qE "^\s*listen\s+80" "$config_file" || exit 1
# Verify root path is correct
sudo grep -qE "^\s*root\s+/var/www/library" "$config_file" || exit 1
# Verify index includes index.php
sudo grep -qE "^\s*index.*index\.php" "$config_file" || exit 1
# Verify PHP handling is configured
sudo grep -qE "location.*\.php" "$config_file" || exit 1
sudo grep -q "fastcgi_pass" "$config_file" || exit 1
# Verify website responds (basic connectivity test)
curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -qE "^(200|301|302)$"
EOF
)

check_database=$(
  cat <<'EOF'
set -euo pipefail
# Check MySQL service is running
sudo systemctl is-active --quiet mysql || sudo systemctl is-active --quiet mariadb || exit 1
# Check MySQL can accept connections
sudo mysqladmin ping -u root --silent >/dev/null 2>&1 || sudo mysqladmin ping --silent >/dev/null 2>&1 || exit 1
# Check MySQL is listening on default port
sudo ss -tlnp | grep -q ":3306" || exit 1
# Check library database exists (optional - won't fail if DB doesn't exist yet)
# sudo mysql -u root -e "USE library" >/dev/null 2>&1 || true
EOF
)

execute_check "[01-install-deps.sh] Packages" check_packages
execute_check "[02-serversetup.sh] Firewall + PHP" check_firewall
execute_check "[02-serversetup.sh] Library directory" check_library
execute_check "[03-webserversetup.sh] Nginx site" check_nginx
execute_check "[03-webserversetup.sh] Website config" check_website_config
execute_check "[04-usercreation.sh] User & Group" check_user_group
execute_check "[05-permissionsetup.sh] Permissions" check_permission
execute_check "[Database] MySQL service" check_database

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
