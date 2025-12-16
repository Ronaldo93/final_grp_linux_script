# install gum if not installed
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

# function to show welcome banner
show_banner() {
    clear
    gum style --border double --border-foreground 208 --padding "1 2" --margin "1" -- <<EOF
Welcome to User Management
------------------------------
This script will help you manage users and groups on the server.
EOF
}

# function to add user to admin group
add_user_to_admin() {
    user=$(gum input --placeholder "Username to add to admin group")
    [[ -z $user ]] && return

    if ! id "$user" &>/dev/null; then
        gum style --foreground 196 "User $user does not exist."
        gum style --foreground 240 "Press Enter to continue..." && read -rs
        return
    fi

    if groups "$user" | grep -qw "admin"; then
        gum style --foreground 214 "User $user is already in admin group."
    else
        sudo usermod -aG admin "$user"
        gum style --foreground 82 "User $user added to admin group."
    fi
    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# function to remove user from admin group
remove_user_from_admin() {
    user=$(gum input --placeholder "Username to remove from admin group")
    [[ -z $user ]] && return

    if ! id "$user" &>/dev/null; then
        gum style --foreground 196 "User $user does not exist."
        gum style --foreground 240 "Press Enter to continue..." && read -rs
        return
    fi

    if ! groups "$user" | grep -qw "admin"; then
        gum style --foreground 214 "User $user is not in admin group."
    else
        sudo gpasswd -d "$user" admin
        gum style --foreground 82 "User $user removed from admin group."
    fi
    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# function to list all users
list_users() {
    gum style --foreground 45 --bold "System Users:"
    awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd | gum format
    echo ""
    gum style --foreground 45 --bold "Admin Group Members:"
    getent group admin 2>/dev/null | cut -d: -f4 || echo "(admin group does not exist)"
    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# function to create new user
create_user() {
    user=$(gum input --placeholder "Enter the new username")
    [[ -z $user ]] && return

    if id "$user" &>/dev/null; then
        gum style --foreground 196 "User $user already exists."
        gum style --foreground 240 "Press Enter to continue..." && read -rs
        return
    fi

    if gum confirm "Create user $user?"; then
        sudo useradd -m -s /bin/bash "$user"
        gum style --foreground 82 "User $user created."
        if gum confirm "Set password for $user?"; then
            sudo passwd "$user"
        fi
    fi
    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# function to delete user
delete_user() {
    user=$(gum input --placeholder "Enter the username to delete")
    [[ -z $user ]] && return

    if ! id "$user" &>/dev/null; then
        gum style --foreground 196 "User $user does not exist."
        gum style --foreground 240 "Press Enter to continue..." && read -rs
        return
    fi

    if gum confirm --negative "Cancel" "Delete user $user? This cannot be undone!"; then
        if gum confirm "Also remove home directory?"; then
            sudo userdel -r "$user"
        else
            sudo userdel "$user"
        fi
        gum style --foreground 82 "User $user deleted."
    fi
    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# main menu loop
while true; do
    show_banner

    action=$(gum choose \
        "List Users" \
        "Create User" \
        "Delete User" \
        "Add User to admin group" \
        "Remove User from admin group" \
        "Exit")

    case $action in
        "List Users")
            list_users
            ;;
        "Create User")
            create_user
            ;;
        "Delete User")
            delete_user
            ;;
        "Add User to admin group")
            add_user_to_admin
            ;;
        "Remove User from admin group")
            remove_user_from_admin
            ;;
        "Exit"|"")
            gum style --foreground 82 "Goodbye!"
            exit 0
            ;;
    esac
done