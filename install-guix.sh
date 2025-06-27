#!/bin/sh
set -e

# Конфигурация
REPO_URL="https://github.com/kosar33/eguix"
TMP_DIR="/tmp/guix-installer"
ROOT_MOUNT="/mnt"
CONFIG_DIR="$TMP_DIR/configs"

# Глобальные переменные для разделов
EFI_PART=""
ROOT_PART=""

# Проверка root-прав
if [ "$(id -u)" -ne 0 ]; then
    echo "Запустите скрипт с правами root!"
    exit 1
fi

# Функция клонирования репозитория
clone_repo() {
    echo "### Проверка установки Git..."
    if ! command -v git &> /dev/null; then
        echo "Git не установлен. Пытаюсь установить..."
        if command -v guix &> /dev/null; then
            guix install git
        else
            echo "Не удалось установить Git! Установите вручную."
            exit 1
        fi
        hash -r
    fi
    
    echo "### Клонирование репозитория..."
    if [ -d "$TMP_DIR" ]; then
        echo "Обновление существующей копии..."
        cd "$TMP_DIR"
        git pull --ff-only
        cd - >/dev/null
    else
        git clone "$REPO_URL" "$TMP_DIR"
    fi
    
    # Проверка успешности клонирования
    if [ ! -d "$CONFIG_DIR" ] || [ ! -f "$CONFIG_DIR/configuration.scm" ]; then
        echo "Ошибка: не найдены конфигурационные файлы в репозитории!"
        exit 1
    fi
    
    echo "Репозиторий успешно клонирован в $TMP_DIR"
}

# Функция проверки зеркал
check_mirrors() {
    echo "### Проверка доступности зеркал..."
    if [ ! -f "$CONFIG_DIR/guix-env-fallback" ]; then
        echo "Ошибка: скрипт guix-env-fallback не найден!"
        return 1
    fi
    
    # Запуск скрипта и экспорт переменных
    source "$CONFIG_DIR/guix-env-fallback"
    
    echo "Выбранные зеркала:"
    echo " - Guix: $GUIX_PACKAGE_CNAMED_URL"
    echo " - Nonguix: $GUIX_NONGUIX_PROXY_URL"
    
    export GUIX_SUBSTITUTE_URLS
    export GUIX_PACKAGE_CNAMED_URL
    export GUIX_NONGUIX_PROXY_URL
}

# Функция разметки диска
partition_disk() {
    echo -e "\n### Разметка диска"
    read -p "Введите диск для установки (например /dev/sda): " DISK
    
    # Проверка ввода
    if [ ! -b "$DISK" ]; then
        echo "Ошибка: $DISK не является блочным устройством!"
        return 1
    fi
    
    # Запрос подтверждения
    echo -e "\nВСЕ ДАННЫЕ НА $DISK БУДУТ УДАЛЕНЫ!"
    read -p "Продолжить? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Отмена операции."
        return
    fi
    
    # Вызов скрипта разметки
    if [ -f "$TMP_DIR/scripts/disk-partition.sh" ]; then
        "$TMP_DIR/scripts/disk-partition.sh" "$DISK"
    else
        echo "Скрипт разметки не найден! Использую встроенную логику..."
        
        # Создание разделов
        parted -s "$DISK" mklabel gpt
        parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
        parted -s "$DISK" set 1 esp on
        parted -s "$DISK" mkpart primary ext4 512MiB 100%
        
        # Форматирование
        mkfs.fat -F32 "${DISK}1"
        mkfs.ext4 -F -L guix-root "${DISK}2"
        
        # Монтирование
        mount "${DISK}2" "$ROOT_MOUNT"
        mkdir -p "$ROOT_MOUNT/boot/efi"
        mount "${DISK}1" "$ROOT_MOUNT/boot/efi"
    fi
    
    # Сохраняем пути разделов
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
    
    echo "Разметка завершена:"
    echo " - EFI раздел: $EFI_PART"
    echo " - Корневой раздел: $ROOT_PART"
}

# Функция настройки сети
setup_network() {
    echo -e "\n### Настройка сети"
    
    if [ -f "$TMP_DIR/scripts/network-setup.sh" ]; then
        "$TMP_DIR/scripts/network-setup.sh"
    else
        echo "Скрипт настройки сети не найден! Использую встроенную логику..."
        
        echo "### Выберите тип подключения:"
        echo "1) Ethernet"
        echo "2) Wi-Fi"
        read -p "Ваш выбор: " NET_TYPE

        case $NET_TYPE in
            1)
                ip -br link show
                read -p "Введите интерфейс (например enp0s25): " IFACE
                ip link set "$IFACE" up
                dhclient -v "$IFACE"
                ;;
            2)
                ip -br link show
                read -p "Введите интерфейс (например wlp2s0): " IFACE
                read -p "SSID сети: " SSID
                read -sp "Пароль: " PASS
                echo
                
                wpa_passphrase "$SSID" "$PASS" > /tmp/wifi.conf
                wpa_supplicant -B -c /tmp/wifi.conf -i "$IFACE"
                dhclient -v "$IFACE"
                ;;
            *)
                echo "Неверный выбор!"
                return 1
                ;;
        esac
    fi
    
    # Проверка соединения
    echo "Проверка соединения с зеркалом..."
    if ping -c 2 -W 3 ya.ru &> /dev/null; then
        echo "Соединение успешно установлено!"
    else
        echo "Предупреждение: не удалось проверить соединение"
    fi
}

# Функция установки системы
install_system() {
    # Проверка монтирования
    if ! mount | grep -q "$ROOT_MOUNT"; then
        echo "Ошибка: корневая файловая система не смонтирована!"
        echo "Сначала выполните разметку диска."
        return 1
    fi
    
    if [ -z "$EFI_PART" ] || [ -z "$ROOT_PART" ]; then
        echo "Ошибка: разделы диска не определены!"
        return 1
    fi
    
    echo -e "\n### Копирование конфигурации"
    mkdir -p "$ROOT_MOUNT/etc/guix"
    cp "$CONFIG_DIR/channels.scm" "$ROOT_MOUNT/etc/guix/"
    cp "$CONFIG_DIR/configuration.scm" "$ROOT_MOUNT/etc/guix/"
    
    mkdir -p "$ROOT_MOUNT/etc/guix/scripts"
    cp "$CONFIG_DIR/guix-env-fallback" "$ROOT_MOUNT/etc/guix/scripts/"
    chmod +x "$ROOT_MOUNT/etc/guix/scripts/guix-env-fallback"
    
    mkdir -p "$ROOT_MOUNT/usr/bin"
    cp "$CONFIG_DIR/eguix" "$ROOT_MOUNT/usr/bin/"
    chmod +x "$ROOT_MOUNT/usr/bin/eguix"
    
    # Обновление UUID в конфигурации
    EFI_UUID=$(blkid -o value -s UUID "$EFI_PART")
    if [ -z "$EFI_UUID" ]; then
        echo "Ошибка: не удалось определить UUID EFI раздела!"
        return 1
    fi
    sed -i "s/XXXX-XXXX/$EFI_UUID/" "$ROOT_MOUNT/etc/guix/configuration.scm"
    
    echo -e "\n### Запуск установки Guix через лучшее зеркало"
    
    # Используем переменные из check_mirrors или значения по умолчанию
    GUIX_PACKAGE_CNAMED_URL=${GUIX_PACKAGE_CNAMED_URL:-"https://mirrors.sjtug.sjtu.edu.cn/guix"}
    GUIX_SUBSTITUTE_URLS=${GUIX_SUBSTITUTE_URLS:-"$GUIX_PACKAGE_CNAMED_URL"}
    
    echo "Используется зеркало: $GUIX_PACKAGE_CNAMED_URL"
    
    # Проверка доступности guix перед установкой
    if ! command -v guix &> /dev/null; then
        echo "Ошибка: guix не найден! Убедитесь, что вы в live-среде Guix."
        return 1
    fi
    
    guix system init \
        "$ROOT_MOUNT/etc/guix/configuration.scm" \
        "$ROOT_MOUNT" \
        --substitute-urls="$GUIX_SUBSTITUTE_URLS"
    
    echo -e "\n\nУстановка завершена успешно!"
    echo "Выберите пункт перезагрузки"
}

reboot_system() {
    umount -R "$ROOT_MOUNT"
    reboot
}

#Меню
while true; do
    echo -e "\n\n===== Guix OS Installer (РФ версия) ====="
    echo "0. Клонировать/обновить репозиторий"
    echo "1. Разметка диска"
    echo "2. Настройка сети"
    echo "3. Проверить зеркала"
    echo "4. Установить систему"
    echo "5. Выполнить ВСЕ шаги"
    echo "r. Перезагрузка"
    echo "q. Выход"
    read -p "Выберите действие: " choice

    case $choice in
        0) clone_repo ;;
        1) partition_disk ;;
        2) setup_network ;;
        3) check_mirrors ;;
        4) install_system ;;
        5) 
            clone_repo
            check_mirrors
            partition_disk
            setup_network
            install_system
            ;;
        "r") reboot_system ;;
        "q") 
            echo "Выход из инсталлятора"
            exit 0
            ;;
        *) 
            echo "Неверный выбор! Попробуйте снова."
            sleep 1
            ;;
    esac
done
