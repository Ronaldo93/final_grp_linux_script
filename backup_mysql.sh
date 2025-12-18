#!/bin/bash

# MySQL Backup Script with Gum UI
# Usage: ./backup_mysql.sh

# Install gum if not installed
if ! command -v gum >/dev/null 2>&1; then
    echo "gum not found, installing..." >&2
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
    cat <<'EOF' >&2
We have installed gum for you.
Please re-run backup_mysql.sh after the installation is complete.
EOF
    exit 1
fi

# Prompt for sudo password upfront
sudo -v || { echo "sudo authentication failed"; exit 1; }

# Function to show banner
show_banner() {
    clear
    gum style --border double --border-foreground 33 --padding "1 2" --margin "1" -- <<EOF
MySQL Backup Utility
------------------------------
Backup your MySQL databases with ease
EOF
}

# Function to perform backup
perform_backup() {
    # Get database name
    db_name=$(gum input --placeholder "Enter the database name to backup")
    [[ -z "$db_name" ]] && return

    # Get backup directory
    backup_dir=$(gum input --placeholder "Enter the backup directory (e.g., /path/to/backup)")
    [[ -z "$backup_dir" ]] && return

    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"

    # Generate a timestamp for the backup file
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    # Define the backup file name
    BACKUP_FILE="$backup_dir/${db_name}_backup_$TIMESTAMP.sql"

    # Perform the backup using mysqldump
    gum style --foreground 214 "Backing up database: $db_name..."
    if mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$db_name" > "$BACKUP_FILE"; then
        gum style --foreground 82 "Backup completed successfully: $BACKUP_FILE"

        # Compress the backup file
        gzip "$BACKUP_FILE"
        gum style --foreground 82 "Backup compressed: $BACKUP_FILE.gz"
    else
        gum style --foreground 196 "Backup failed!"
    fi

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# Function to restore backup
restore_backup() {
    # Get backup file path
    backup_file=$(gum input --placeholder "Enter the path to the backup file (e.g., /path/to/backup/library_backup_20231010_120000.sql.gz)")
    [[ -z "$backup_file" ]] && return

    # Check if the backup file exists
    if [[ ! -f "$backup_file" ]]; then
        gum style --foreground 196 "Backup file not found: $backup_file"
        gum style --foreground 240 "Press Enter to continue..." && read -rs
        return
    fi

    # Get database name
    db_name=$(gum input --placeholder "Enter the database name to restore to")
    [[ -z "$db_name" ]] && return

    # Confirm restoration
    if gum confirm --negative "Cancel" "Are you sure you want to restore $backup_file to $db_name? This will overwrite existing data!"; then
        # Decompress the backup file if it's compressed
        if [[ "$backup_file" == *.gz ]]; then
            gunzip -c "$backup_file" > "${backup_file%.gz}"
            backup_file="${backup_file%.gz}"
        fi

        # Restore the backup
        gum style --foreground 214 "Restoring database: $db_name..."
        if mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$db_name" < "$backup_file"; then
            gum style --foreground 82 "Restore completed successfully!"
        else
            gum style --foreground 196 "Restore failed!"
        fi

        # Remove the decompressed file if it was created
        if [[ "$backup_file" != *.gz ]]; then
            rm "$backup_file"
        fi
    fi

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# Main menu loop
while true; do
    show_banner

    action=$(gum choose \
        "Perform Backup" \
        "Restore Backup" \
        "Exit")

    case $action in
        "Perform Backup")
            perform_backup
            ;;
        "Restore Backup")
            restore_backup
            ;;
        "Exit"|"")
            gum style --foreground 82 "Goodbye!"
            exit 0
            ;;
    esac
done

# MySQL Backup Script with Gum UI
# Usage: ./backup_mysql.sh

# Install gum if not installed
if ! command -v gum >/dev/null 2>&1; then
    echo "gum not found, installing..." >&2
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
    cat <<'EOF' >&2
We have installed gum for you.
Please re-run backup_mysql.sh after the installation is complete.
EOF
    exit 1
fi

# Prompt for sudo password upfront
sudo -v || { echo "sudo authentication failed"; exit 1; }

# Function to show banner
show_banner() {
    clear
    gum style --border double --border-foreground 33 --padding "1 2" --margin "1" -- <<EOF
MySQL Backup Utility
------------------------------
Backup your MySQL databases with ease
EOF
}

# Function to perform backup
perform_backup() {
    # Get database name
    db_name=$(gum input --placeholder "Enter the database name to backup")
    [[ -z "$db_name" ]] && return

    # Get backup directory
    backup_dir=$(gum input --placeholder "Enter the backup directory (e.g., /path/to/backup)")
    [[ -z "$backup_dir" ]] && return

    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"

    # Generate a timestamp for the backup file
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    # Define the backup file name
    BACKUP_FILE="$backup_dir/${db_name}_backup_$TIMESTAMP.sql"

    # Perform the backup using mysqldump
    gum style --foreground 214 "Backing up database: $db_name..."
    if mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$db_name" > "$BACKUP_FILE"; then
        gum style --foreground 82 "Backup completed successfully: $BACKUP_FILE"

        # Compress the backup file
        gzip "$BACKUP_FILE"
        gum style --foreground 82 "Backup compressed: $BACKUP_FILE.gz"
    else
        gum style --foreground 196 "Backup failed!"
    fi

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# Function to restore backup
restore_backup() {
    # Get backup file path
    backup_file=$(gum input --placeholder "Enter the path to the backup file (e.g., /path/to/backup/library_backup_20231010_120000.sql.gz)")
    [[ -z "$backup_file" ]] && return

    # Check if the backup file exists
    if [[ ! -f "$backup_file" ]]; then
        gum style --foreground 196 "Backup file not found: $backup_file"
        gum style --foreground 240 "Press Enter to continue..." && read -rs
        return
    fi

    # Get database name
    db_name=$(gum input --placeholder "Enter the database name to restore to")
    [[ -z "$db_name" ]] && return

    # Confirm restoration
    if gum confirm --negative "Cancel" "Are you sure you want to restore $backup_file to $db_name? This will overwrite existing data!"; then
        # Decompress the backup file if it's compressed
        if [[ "$backup_file" == *.gz ]]; then
            gunzip -c "$backup_file" > "${backup_file%.gz}"
            backup_file="${backup_file%.gz}"
        fi

        # Restore the backup
        gum style --foreground 214 "Restoring database: $db_name..."
        if mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$db_name" < "$backup_file"; then
            gum style --foreground 82 "Restore completed successfully!"
        else
            gum style --foreground 196 "Restore failed!"
        fi

        # Remove the decompressed file if it was created
        if [[ "$backup_file" != *.gz ]]; then
            rm "$backup_file"
        fi
    fi

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# Main menu loop
while true; do
    show_banner

    action=$(gum choose \
        "Perform Backup" \
        "Restore Backup" \
        "Exit")

    case $action in
        "Perform Backup")
            perform_backup
            ;;
        "Restore Backup")
            restore_backup
            ;;
        "Exit"|"")
            gum style --foreground 82 "Goodbye!"
            exit 0
            ;;
    esac
done
