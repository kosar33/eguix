#!/bin/bash
set -e

if [ -z "$1" ]; then
    echo "Использование: $0 <диск>"
    exit 1
fi

DISK=$1

# Создание разделов GPT
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 100%

# Форматирование
mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F -L guix-root "${DISK}2"

# Монтирование
mount "${DISK}2" /mnt
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

echo "Разметка завершена!"
