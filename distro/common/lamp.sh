#!/bin/sh

set -x

cd utils
    . ./sys_info.sh
    . ./sh-test-lib
cd -

#OUTPUT="$(pwd)/output"
#RESULT_FILE="${OUTPUT}/result.txt"
#export RESULT_FILE

install_deps() {
    pkgs="$1"
    [ -z "${pkgs}" ] && error_msg "Usage: install_deps pkgs"

        case "${distro}" in
          debian|ubuntu)
            # Use the default answers for all questions.
            DEBIAN_FRONTEND=noninteractive apt-get update -q -y
            # shellcheck disable=SC2086
            DEBIAN_FRONTEND=noninteractive apt-get install -q -y ${pkgs}
            ;;
          centos)
            # shellcheck disable=SC2086
            yum -e 0 -y install ${pkgs}
            ;;
          fedora)
            # shellcheck disable=SC2086
            dnf -e 0 -y install ${pkgs}
            ;;
          *)
            warn_msg "Unsupported distro: ${dist}! Package installation skipped."
            ;;
        esac
}

#usage() {
#    echo "Usage: $0 [-s <true|false>]" 1>&2
#    exit 1
#}

#while getopts "s:" o; do
#  case "$o" in
#    s) SKIP_INSTALL="${OPTARG}" ;;
#    *) usage ;;
#  esac
#done

#! check_root && error_msg "This script must be run as root"
#[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
#mkdir -p "${OUTPUT}"

# Install lamp and use systemctl for service management. Tested on Ubuntu 16.04,
# Debian 8, CentOS 7 and Fedora 24. systemctl should available on newer releases
# as well.
#if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
#    warn_msg "LAMP package installation skipped"
#else
    # Stop nginx server in case it is installed and running.
    systemctl stop nginx > /dev/null 2>&1 || true

#    dist_name
    # shellcheck disable=SC2154
    case "${distro}" in
      debian|ubuntu)
        if [ "${distro}" = "debian" ]; then
            pkgs="apache2 mysql-server php5-mysql php5-common libapache2-mod-php5"
        elif [ "${distro}" = "ubuntu" ]; then
            echo mysql-server mysql-server/root_password password lxmptest | sudo debconf-set-selections
			 echo mysql-server mysql-server/root_password_again password lxmptest | sudo debconf-set-selections
			pkgs="apache2 mysql-server php-mysql php-common libapache2-mod-php"
        fi
        install_deps "curl ${pkgs}"
        echo "extension=mysqli.so" >> /etc/php/7.0/apache2/php.ini
        systemctl restart apache2
        systemctl restart mysql
        ;;
      centos|fedora)
        pkgs="httpd mariadb-server mariadb php php-mysql"
        install_deps "curl ${pkgs}"
        systemctl start httpd.service
        systemctl start mariadb
        ;;
      *)
        error_msg "Unsupported distribution!"
    esac
#fi

cp ./html/* /var/www/html/

# Test Apache.
curl -o "${OUTPUT}/index.html" "http://localhost/index.html"
grep "Test Page for the Apache HTTP Server" "${OUTPUT}/index.html"
print_info $? apache2-test-page

# Test MySQL.
mysqladmin -u root password lxmptest  > /dev/null 2>&1 || true
mysql --user="root" --password="lxmptest" -e "show databases"
print_info $? mysql-show-databases

# Test PHP.
curl -o "${OUTPUT}/phpinfo.html" "http://localhost/info.php"
grep "PHP Version" "${OUTPUT}/phpinfo.html"
print_info $? phpinfo

# PHP Connect to MySQL.
curl -o "${OUTPUT}/connect-db" "http://localhost/connect-db.php"
grep "Connected successfully" "${OUTPUT}/connect-db"
#exit_on_fail "php-connect-db"
print_info $? php-connect-db

# PHP Create a MySQL Database.
curl -o "${OUTPUT}/create-db" "http://localhost/create-db.php"
grep "Database created successfully" "${OUTPUT}/create-db"
print_info $? php-create-db

# PHP Create MySQL table.
curl -o "${OUTPUT}/create-table" "http://localhost/create-table.php"
grep "Table MyGuests created successfully" "${OUTPUT}/create-table"
print_info $? php-create-table

# PHP add record to MySQL table.
curl -o "${OUTPUT}/add-record" "http://localhost/add-record.php"
grep "New record created successfully" "${OUTPUT}/add-record"
print_info $? php-add-record

# PHP select record from MySQL table.
curl -o "${OUTPUT}/select-record" "http://localhost/select-record.php"
grep "id: 1 - Name: John Doe" "${OUTPUT}/select-record"
print_info $? php-select-record

# PHP delete record from MySQL table.
curl -o "${OUTPUT}/delete-record" "http://localhost/delete-record.php"
grep "Record deleted successfully" "${OUTPUT}/delete-record"
print_info $? php-delete-record

# Delete myDB for the next run.
mysql --user='root' --password='lxmptest' -e 'DROP DATABASE myDB'
