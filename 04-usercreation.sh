#!/usr/bin/env bash

# user to add: sysadmin
user_to_create="sysadmin"
# default password. notice user to CHANGE IT
password="123456"
# user group admin
user_group="admin"
# check if the script is ran in sudo mode
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root"
    exit 1
fi

# handle ctrl c
trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT

# create a user
echo "[INFO] Starting user and group creation..."
echo "[INFO] Creating user $user_to_create..."

# do not add if there is already a user
if ! id "$user_to_create" >/dev/null 2>&1; then
    useradd -m "$user_to_create" -s /bin/bash
    echo "$user_to_create:$password" | chpasswd
    usermod -aG sudo "$user_to_create"
    echo "[INFO] User $user_to_create created successfully with password $password."
    echo "[WARNING] For security reason, change the password as soon as possible."
else
    echo "[INFO] User $user_to_create already exists. Skipping..."
fi


# create group if not exist
echo "[INFO] Creating group $user_group..."
if ! getent group "$user_group" >/dev/null 2>&1; then
    groupadd "$user_group"
    echo "[INFO] Group $user_group created successfully."
else
    echo "[INFO] Group $user_group already exists. Skipping..."
fi

# add user to group if not in it
# admin should match the whole word
echo "[INFO] Adding user $user_to_create to group $user_group..."
if ! groups "$user_to_create" | grep -qE "\b$user_group\b"; then
    usermod -aG "$user_group" "$user_to_create"
    echo "[INFO] User $user_to_create added to group $user_group."
else
    echo "[INFO] User $user_to_create is already in group $user_group. Skipping..."
fi

echo "[INFO] User and group creation completed successfully."