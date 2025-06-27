#!/bin/bash
set -e

echo "### Выберите тип подключения:"
echo "1) Ethernet"
echo "2) Wi-Fi"
read -p "Ваш выбор: " NET_TYPE

case $NET_TYPE in
    1)
        ip link
        read -p "Введите интерфейс (например enp0s25): " IFACE
        ifconfig "$IFACE" up
        dhclient "$IFACE"
        ;;
    2)
        ip link
        read -p "Введите интерфейс (например wlp2s0): " IFACE
        read -p "SSID сети: " SSID
        read -sp "Пароль: " PASS
        
        wpa_passphrase "$SSID" "$PASS" > /tmp/wifi.conf
        wpa_supplicant -B -c /tmp/wifi.conf -i "$IFACE"
        dhclient "$IFACE"
        ;;
    *)
        echo "Неверный выбор!"
        exit 1
        ;;
esac

echo "Проверка соединения..."
ping -c 3 mirrors.sjtug.sjtu.edu.cn
