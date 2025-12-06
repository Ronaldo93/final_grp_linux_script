#!/usr/bin/env bash

# user to add: sysadmin
user_to_create="sysadmin"
# default password. notice user to CHANGE IT
password="123456"
# user group admin
user_group="admin"
# check if the script is ran in sudo mode
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# create a user
echo "Creating user..."

# do not add if there is already a user
if ! id "$user_to_create" >/dev/null 2>&1; then
    useradd -m "$user_to_create" -s /bin/bash
    echo "$user_to_create:$password" | chpasswd
    usermod -aG sudo "$user_to_create"
    echo "User $user_to_create created successfully with password $password. For security reason, change it as soon as possible."
else
    echo "User $user_to_create already exists. Skipping..."
fi


# create group if not exist
echo "Creating group..."
if ! getent group "$user_group" >/dev/null 2>&1; then
    groupadd "$user_group"
    echo "Group $user_group created successfully."
else
    echo "Group $user_group already exists. Skipping..."
fi

# add user to group if not in it
if ! groups "$user_to_create" | grep -q "$user_group"; then
    usermod -aG "$user_group" "$user_to_create"
    echo "User $user_to_create added to group $user_group."
else
    echo "User $user_to_create is already in group $user_group. Skipping..."
fi