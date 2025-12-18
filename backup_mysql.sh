#!/bin/bash

# MySQL Backup Script with Gum UI
# NOTE: Assumes MySQL has NO secure authentication (root connects without password)

# Defaults
DEFAULT_BACKUP_DIR="/var/backups/mysql"
DEFAULT_DATABASE="library_db"
DEFAULT_MYSQL_USER="root"
DEFAULT_MYSQL_HOST="localhost"

# Logging
log_info()    { gum style --foreground 33  "[INFO] $1"; }
log_success() { gum style --foreground 82  "[OK] $1"; }
log_warning() { gum style --foreground 214 "[WARN] $1"; }
log_error()   { gum style --foreground 196 "[ERROR] $1"; }
log_step()    { gum style --foreground 141 ">> $1"; }

# Cleanup on failure
cleanup_failed_backup() {
    local file="$1"
    [[ -n "$file" && -f "$file" ]] && { log_warning "Removing incomplete: $file"; rm -f "$file" "${file}.gz" 2>/dev/null; }
}

cleanup_failed_restore() {
    local file="$1"
    [[ -n "$file" && -f "$file" ]] && { log_warning "Removing temp: $file"; rm -f "$file"; }
}

trap_cleanup() {
    log_warning "Interrupted. Cleaning up..."
    [[ -n "$CURRENT_BACKUP_FILE" ]] && cleanup_failed_backup "$CURRENT_BACKUP_FILE"
    [[ -n "$CURRENT_TEMP_FILE" ]] && cleanup_failed_restore "$CURRENT_TEMP_FILE"
    exit 1
}
trap trap_cleanup SIGINT SIGTERM

# Install gum if missing
if ! command -v gum >/dev/null 2>&1; then
    echo "Installing gum..." >&2
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt update && sudo apt install gum
    echo "Gum installed. Please re-run this script." >&2
    exit 1
fi

sudo -v || { echo "sudo authentication failed"; exit 1; }

show_banner() {
    clear
    gum style --border double --border-foreground 33 --padding "1 2" --margin "1" -- <<EOF
MySQL Backup Utility
Using passwordless MySQL authentication
Default DB: $DEFAULT_DATABASE | Dir: $DEFAULT_BACKUP_DIR
EOF
}

show_config() {
    gum style --border rounded --border-foreground 240 --padding "1" -- \
        "User: $DEFAULT_MYSQL_USER | Host: $DEFAULT_MYSQL_HOST | DB: $DEFAULT_DATABASE | Dir: $DEFAULT_BACKUP_DIR"
}

perform_backup() {
    local db_name backup_dir mysql_user mysql_host BACKUP_FILE TIMESTAMP
    
    show_config && echo ""
    
    # Prompt with defaults
    db_name=$(gum input --placeholder "Database (default: $DEFAULT_DATABASE)")
    [[ -z "$db_name" ]] && db_name="$DEFAULT_DATABASE"
    
    backup_dir=$(gum input --placeholder "Backup dir (default: $DEFAULT_BACKUP_DIR)")
    [[ -z "$backup_dir" ]] && backup_dir="$DEFAULT_BACKUP_DIR"
    
    mysql_user=$(gum input --placeholder "MySQL user (default: $DEFAULT_MYSQL_USER)")
    [[ -z "$mysql_user" ]] && mysql_user="$DEFAULT_MYSQL_USER"
    
    mysql_host=$(gum input --placeholder "MySQL host (default: $DEFAULT_MYSQL_HOST)")
    [[ -z "$mysql_host" ]] && mysql_host="$DEFAULT_MYSQL_HOST"

    echo ""
    log_info "Config: DB=$db_name, Dir=$backup_dir, User=$mysql_user@$mysql_host"
    
    gum confirm "Proceed with backup?" || { log_warning "Cancelled."; read -rs; return; }

    # Create backup directory
    log_step "Creating backup directory..."
    if ! sudo mkdir -p "$backup_dir"; then
        log_error "Failed to create: $backup_dir"
        read -rs; return 1
    fi
    sudo chmod 750 "$backup_dir"

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$backup_dir/${db_name}_backup_$TIMESTAMP.sql"
    CURRENT_BACKUP_FILE="$BACKUP_FILE"

    # Verify database exists
    log_step "Verifying database..."
    if ! sudo mysql -u "$mysql_user" -h "$mysql_host" -e "USE $db_name" 2>/dev/null; then
        log_error "Database '$db_name' not found!"
        CURRENT_BACKUP_FILE=""
        read -rs; return 1
    fi

    # Perform backup
    log_step "Dumping database: $db_name..."
    if sudo bash -c "mysqldump -u '$mysql_user' -h '$mysql_host' '$db_name' > '$BACKUP_FILE'" 2>&1; then
        if [[ ! -s "$BACKUP_FILE" ]]; then
            log_error "Backup file is empty!"
            cleanup_failed_backup "$BACKUP_FILE"
            CURRENT_BACKUP_FILE=""
            read -rs; return 1
        fi

        log_success "Dump complete: $(du -h "$BACKUP_FILE" | cut -f1)"

        log_step "Compressing..."
        if gzip "$BACKUP_FILE"; then
            sudo chmod 640 "${BACKUP_FILE}.gz"
            log_success "Compressed: ${BACKUP_FILE}.gz ($(du -h "${BACKUP_FILE}.gz" | cut -f1))"
        else
            log_warning "Compression failed, keeping uncompressed."
            sudo chmod 640 "$BACKUP_FILE"
        fi
        
        CURRENT_BACKUP_FILE=""
        echo ""
        gum style --border double --border-foreground 82 --padding "1" "BACKUP COMPLETE: ${BACKUP_FILE}.gz"
    else
        log_error "Backup failed!"
        cleanup_failed_backup "$BACKUP_FILE"
        CURRENT_BACKUP_FILE=""
    fi

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

restore_backup() {
    local backup_file db_name mysql_user mysql_host temp_file="" backup_dir
    
    show_config && echo ""

    # Get backup directory
    backup_dir=$(gum input --placeholder "Backup directory (default: $DEFAULT_BACKUP_DIR)")
    [[ -z "$backup_dir" ]] && backup_dir="$DEFAULT_BACKUP_DIR"

    if [[ ! -d "$backup_dir" ]]; then
        log_error "Directory not found: $backup_dir"
        read -rs; return 1
    fi

    # Find backup files and let user select
    log_info "Scanning $backup_dir for backups..."
    mapfile -t backup_files < <(find "$backup_dir" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.sql.gz" \) 2>/dev/null | sort -r)

    if [[ ${#backup_files[@]} -eq 0 ]]; then
        log_warning "No backup files found in $backup_dir"
        read -rs; return
    fi

    # Build selection list with file info
    local file_options=()
    for f in "${backup_files[@]}"; do
        local fname=$(basename "$f")
        local fsize=$(du -h "$f" 2>/dev/null | cut -f1)
        local fdate=$(stat -c '%y' "$f" 2>/dev/null | cut -d'.' -f1)
        file_options+=("$fname ($fsize, $fdate)")
    done

    log_step "Select a backup file:"
    selected=$(printf '%s\n' "${file_options[@]}" | gum choose)
    [[ -z "$selected" ]] && { log_warning "No file selected."; read -rs; return; }

    # Extract filename from selection
    selected_name=$(echo "$selected" | sed 's/ (.*//')
    backup_file="$backup_dir/$selected_name"

    if [[ ! -f "$backup_file" ]]; then
        log_error "File not found: $backup_file"
        read -rs; return 1
    fi
    log_info "Selected: $backup_file"

    db_name=$(gum input --placeholder "Target database (default: $DEFAULT_DATABASE)")
    [[ -z "$db_name" ]] && db_name="$DEFAULT_DATABASE"
    
    mysql_user=$(gum input --placeholder "MySQL user (default: $DEFAULT_MYSQL_USER)")
    [[ -z "$mysql_user" ]] && mysql_user="$DEFAULT_MYSQL_USER"
    
    mysql_host=$(gum input --placeholder "MySQL host (default: $DEFAULT_MYSQL_HOST)")
    [[ -z "$mysql_host" ]] && mysql_host="$DEFAULT_MYSQL_HOST"

    echo ""
    log_warning "This will OVERWRITE data in '$db_name'!"
    gum confirm --negative "Cancel" "Proceed with restore?" || { log_warning "Cancelled."; read -rs; return; }

    # Ensure database exists
    log_step "Preparing database..."
    if ! sudo mysql -u "$mysql_user" -h "$mysql_host" -e "CREATE DATABASE IF NOT EXISTS \`$db_name\`;" 2>&1; then
        log_error "Failed to create database '$db_name'"
        read -rs; return 1
    fi

    # Decompress if needed
    if [[ "$backup_file" == *.gz ]]; then
        log_step "Decompressing..."
        temp_file="/tmp/restore_${db_name}_$$.sql"
        CURRENT_TEMP_FILE="$temp_file"
        
        if ! gunzip -c "$backup_file" > "$temp_file"; then
            log_error "Decompression failed!"
            cleanup_failed_restore "$temp_file"
            CURRENT_TEMP_FILE=""
            read -rs; return 1
        fi
        backup_file="$temp_file"
    fi

    # Restore
    log_step "Restoring to: $db_name..."
    if sudo mysql -u "$mysql_user" -h "$mysql_host" "$db_name" < "$backup_file" 2>&1; then
        table_count=$(sudo mysql -u "$mysql_user" -h "$mysql_host" -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$db_name';" 2>/dev/null)
        log_success "Restore complete! Tables: $table_count"
    else
        log_error "Restore failed!"
    fi

    # Cleanup temp file
    [[ -n "$temp_file" && -f "$temp_file" ]] && rm -f "$temp_file"
    CURRENT_TEMP_FILE=""

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

list_backups() {
    local backup_dir
    
    backup_dir=$(gum input --placeholder "Backup directory (default: $DEFAULT_BACKUP_DIR)")
    [[ -z "$backup_dir" ]] && backup_dir="$DEFAULT_BACKUP_DIR"

    echo ""
    if [[ ! -d "$backup_dir" ]]; then
        log_warning "Directory not found: $backup_dir"
    else
        log_info "Backups in $backup_dir:"
        ls -lah "$backup_dir"/*.sql* 2>/dev/null || echo "  (none)"
    fi

    gum style --foreground 240 "Press Enter to continue..." && read -rs
}

# Main loop
while true; do
    show_banner

    action=$(gum choose "Perform Backup" "Restore Backup" "List Backups" "Exit")

    case $action in
        "Perform Backup") perform_backup ;;
        "Restore Backup") restore_backup ;;
        "List Backups")   list_backups ;;
        "Exit"|"")        gum style --foreground 82 "Goodbye!"; exit 0 ;;
    esac
done
