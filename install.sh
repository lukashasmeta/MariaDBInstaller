#!/bin/bash

set -e  # Stop script on error

# Update and upgrade system
apt update && apt upgrade -y

# Install necessary packages
apt install -y ca-certificates apt-transport-https lsb-release gnupg curl nano unzip

# Determine OS
OS=$(lsb_release -is)
VERSION=$(lsb_release -sc)

# Add PHP repository
if [ "$OS" == "Debian" ]; then
    curl -fsSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/php-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/php-archive-keyring.gpg] https://packages.sury.org/php/ $VERSION main" > /etc/apt/sources.list.d/php.list
elif [ "$OS" == "Ubuntu" ]; then
    apt install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Update package lists again
apt update

# Install Apache and PHP 8.2
apt install -y apache2 php8.2 php8.2-cli php8.2-common php8.2-curl php8.2-gd php8.2-intl php8.2-mbstring php8.2-mysql php8.2-opcache php8.2-readline php8.2-xml php8.2-xsl php8.2-zip php8.2-bz2 libapache2-mod-php8.2

# Install MariaDB
apt install -y mariadb-server mariadb-client

# Secure MariaDB installation
echo "Securing MariaDB..."
mysql_secure_installation <<EOF

n
y
y
y
y
EOF

# Install phpMyAdmin
cd /usr/share
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O phpmyadmin.zip
unzip phpmyadmin.zip
rm phpmyadmin.zip
mv phpMyAdmin-*-all-languages phpmyadmin
chmod -R 0755 phpmyadmin

# Configure Apache for phpMyAdmin
cat <<EOL > /etc/apache2/conf-available/phpmyadmin.conf
Alias /phpmyadmin /usr/share/phpmyadmin

<Directory /usr/share/phpmyadmin>
    Options SymLinksIfOwnerMatch
    DirectoryIndex index.php
</Directory>

<Directory /usr/share/phpmyadmin/templates>
    Require all denied
</Directory>
<Directory /usr/share/phpmyadmin/libraries>
    Require all denied
</Directory>
<Directory /usr/share/phpmyadmin/setup/lib>
    Require all denied
</Directory>
EOL

a2enconf phpmyadmin
systemctl reload apache2

# Set permissions for phpMyAdmin tmp directory
mkdir -p /usr/share/phpmyadmin/tmp/
chown -R www-data:www-data /usr/share/phpmyadmin/tmp/

# Enable password authentication for MariaDB (if not Debian 11)
if [ "$OS" == "Debian" ] && [ "$VERSION" != "bullseye" ]; then
    echo "Updating MariaDB authentication..."
    mysql -u root <<EOF
    UPDATE mysql.user SET plugin = 'mysql_native_password' WHERE user = 'root' AND plugin = 'unix_socket';
    FLUSH PRIVILEGES;
    EXIT;
EOF
fi

echo "Installation complete!"
