#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# install gum if not installed
if ! command -v gum >/dev/null 2>&1; then
    echo "gum not found, installing..." >&2
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
    cat <<'EOF' >&2
We have installed gum for you.
Please re-run server-management.sh after the installation is complete.
EOF
    exit 1
fi

pause() {
    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

show_banner() {
    clear
    gum style --border double --border-foreground 33 --padding "1 2" --margin "1" -- <<EOF
Server Management
------------------------------
Manage your library server installation
EOF
}

install_server() {
    gum style --foreground 45 --bold "Installing Server..."
    echo ""

    scripts=(
        "00-system-update.sh"
        "01-install-deps.sh"
        "02-serversetup.sh"
        "03-webserversetup.sh"
        "04-usercreation.sh"
        "05-permissionsetup.sh"
    )

    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPT_DIR/$script" ]]; then
            gum style --foreground 214 "Running $script..."
            if ! sudo bash "$SCRIPT_DIR/$script"; then
                gum style --foreground 196 "Failed to run $script"
                pause
                return 1
            fi
            gum style --foreground 82 "Completed $script"
            echo ""
        else
            gum style --foreground 196 "Script not found: $script"
        fi
    done

    gum style --foreground 82 --bold "Server installation complete!"
    pause
}

backup_server() {
    gum style --foreground 214 --bold "Backup Server"
    echo ""
    gum style --foreground 196 "⚠ This feature is not implemented yet."
    gum style --foreground 240 "Planned features:"
    gum style --foreground 240 "  - Backup MySQL databases"
    gum style --foreground 240 "  - Backup /var/www/library files"
    gum style --foreground 240 "  - Backup nginx configuration"
    pause
}

check_status() {
    gum style --foreground 45 --bold "Installation Status"
    echo ""

    # Check nginx
    if command -v nginx >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx; then
            gum style --foreground 82 "✓ Nginx: installed and running"
        else
            gum style --foreground 214 "○ Nginx: installed but not running"
        fi
    else
        gum style --foreground 196 "✗ Nginx: not installed"
    fi

    # Check MySQL
    if command -v mysql >/dev/null 2>&1; then
        if systemctl is-active --quiet mysql; then
            gum style --foreground 82 "✓ MySQL: installed and running"
        else
            gum style --foreground 214 "○ MySQL: installed but not running"
        fi
    else
        gum style --foreground 196 "✗ MySQL: not installed"
    fi

    # Check PHP
    if command -v php >/dev/null 2>&1; then
        php_version=$(php -v | head -n1 | cut -d' ' -f2)
        gum style --foreground 82 "✓ PHP: installed (v$php_version)"
    else
        gum style --foreground 196 "✗ PHP: not installed"
    fi

    # Check PHP-FPM
    if systemctl is-active --quiet php*-fpm 2>/dev/null; then
        gum style --foreground 82 "✓ PHP-FPM: running"
    else
        gum style --foreground 214 "○ PHP-FPM: not running"
    fi

    # Check library directory
    if [[ -d /var/www/library ]]; then
        gum style --foreground 82 "✓ Library directory: exists"
    else
        gum style --foreground 196 "✗ Library directory: not found"
    fi

    # Check nginx site config
    if [[ -f /etc/nginx/sites-enabled/library ]]; then
        gum style --foreground 82 "✓ Nginx site config: enabled"
    else
        gum style --foreground 196 "✗ Nginx site config: not enabled"
    fi

    echo ""
    
    if gum confirm "Open a shell to inspect the server?"; then
        gum style --foreground 240 "Type 'exit' to return to this menu."
        echo ""
        bash
    fi
    
    pause
}

remove_server() {
    gum style --foreground 196 --bold "⚠ Remove Server"
    echo ""
    gum style --foreground 214 "This will remove:"
    gum style --foreground 240 "  - Nginx and its configuration"
    gum style --foreground 240 "  - MySQL server and all databases"
    gum style --foreground 240 "  - PHP and related packages"
    gum style --foreground 240 "  - /var/www/library directory"
    echo ""

    if ! gum confirm --negative "Cancel" "Are you sure you want to remove the server?"; then
        gum style --foreground 82 "Removal cancelled."
        pause
        return
    fi

    if ! gum confirm --negative "Cancel" "This will DELETE ALL DATA. Continue?"; then
        gum style --foreground 82 "Removal cancelled."
        pause
        return
    fi

    gum style --foreground 214 "Removing server components..."
    echo ""

    # Stop services
    gum style --foreground 240 "Stopping services..."
    sudo systemctl stop nginx 2>/dev/null
    sudo systemctl stop mysql 2>/dev/null
    sudo systemctl stop php*-fpm 2>/dev/null

    # Remove nginx config
    gum style --foreground 240 "Removing nginx configuration..."
    sudo rm -f /etc/nginx/sites-enabled/library
    sudo rm -f /etc/nginx/sites-available/library

    # Remove library directory
    gum style --foreground 240 "Removing library directory..."
    sudo rm -rf /var/www/library

    # Remove packages
    gum style --foreground 240 "Removing packages..."
    sudo apt purge -y nginx nginx-common mysql-server mysql-client \
        php php-fpm php-mysql php-xml php-mbstring php-curl php-zip php-gd php-cli 2>/dev/null
    sudo apt autoremove -y

    # Clean up MySQL data
    gum style --foreground 240 "Removing MySQL data..."
    sudo rm -rf /var/lib/mysql

    gum style --foreground 82 --bold "Server removed successfully."
    pause
}

# main menu loop
while true; do
    show_banner

    action=$(gum choose \
        "Install Server" \
        "Backup Server" \
        "Check Installation Status" \
        "Remove Server" \
        "Exit")

    case $action in
        "Install Server")
            install_server
            ;;
        "Backup Server")
            backup_server
            ;;
        "Check Installation Status")
            check_status
            ;;
        "Remove Server")
            remove_server
            ;;
        "Exit"|"")
            gum style --foreground 82 "Goodbye!"
            exit 0
            ;;
    esac
done
