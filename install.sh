#!/bin/bash

# 1. Проверка прав суперпользователя (root)
if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Этот скрипт нужно запускать от имени root." 
   exit 1
fi

echo "=== 1/5 Установка зависимостей ==="
apt update -y && apt install -y curl openssl sqlite3

echo "=== 2/5 Установка официальной панели 3x-ui ==="
# Флаг -y автоматически соглашается на базовые настройки при установке
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) -y

echo "=== 3/5 Создание самоподписанного сертификата ==="
CERT_DIR="/etc/x-ui/certs"
mkdir -p "$CERT_DIR"

# Получаем внешний IP сервера
SERVER_IP=$(curl -s https://api.ipify.org || curl -s ifconfig.me)

echo "Генерация сертификата на 10 лет для IP: $SERVER_IP"
openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 3650 \
  -keyout "$CERT_DIR/private.key" \
  -out "$CERT_DIR/cert.crt" \
  -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=$SERVER_IP"

# Назначаем правильные права на файлы сертификатов
chmod 644 "$CERT_DIR/cert.crt"
chmod 600 "$CERT_DIR/private.key"

echo "=== 4/5 Применение сертификата в настройки 3x-ui ==="
DB_PATH="/etc/x-ui/x-ui.db"

if [ -f "$DB_PATH" ]; then
    # Записываем пути к сертификатам напрямую в базу данных SQLite
    sqlite3 "$DB_PATH" "UPDATE settings SET value='$CERT_DIR/cert.crt' WHERE key='webCertFile';"
    sqlite3 "$DB_PATH" "UPDATE settings SET value='$CERT_DIR/private.key' WHERE key='webKeyFile';"
    echo "Настройки базы данных успешно обновлены."
    
    echo "=== 5/5 Перезапуск панели ==="
    systemctl restart x-ui
else
    echo "Внимание: База данных $DB_PATH не найдена! Пропишите пути в панели вручную."
fi

echo "=========================================================="
echo "Установка полностью завершена!"
echo "Ваша панель 3x-ui доступна по адресу: https://$SERVER_IP:2053"
echo ""
echo "Логин и пароль по умолчанию (если это новая установка): admin / admin"
echo ""
echo "Так как сертификат самоподписанный, браузер напишет, что подключение не защищено."
echo "Нажмите 'Дополнительно' -> 'Перейти на сайт' (в Chrome можно нажать в пустое место и ввести thisisunsafe)."
echo "=========================================================="
