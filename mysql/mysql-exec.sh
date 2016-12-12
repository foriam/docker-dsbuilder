#!/bin/bash

#
# Based on 
# https://github.com/docker-library/docker-mysql
# https://github.com/kaiwinter/wildfly10-mariadb/tree/master/container-files/mariadb
#

set -e

# User-provided env variables
MYSQL_USER=${MYSQL_USER:="admin"}
MYSQL_USER_PASS=${MYSQL_USER_PASS:-$(pwgen -s 12 1)}

# Other variables
VOLUME_HOME="/var/lib/mysql"
ERROR_LOG="/var/log/mysqld.log"
MYSQLD_PID_FILE="/var/run/mysqld/mysqld.pid"
EXISTING_MYSQL=false

#########################################################
# Check in the loop (every 1s) if the database backend
# service is already available for connections.
#########################################################
function wait_for_db() {
	set +e
  
	echo "Waiting for DB service..."
	while true; do
		if netstat -an | grep "$VOLUME_HOME"; then
			break;
		else
			echo "Still waiting for DB service..." && sleep 1
		fi
	done
  
	set -e
}

#########################################################
# Cals `mysql_install_db` if empty volume is detected.
# Globals:
#   $VOLUME_HOME
#   $ERROR_LOG
#########################################################
function install_db() {
    if [ ! -d $VOLUME_HOME/mysql ]; then
		echo "=> An empty/uninitialized mysql volume is detected in $VOLUME_HOME"
		echo "=> Installing mysql..."
		mysql_install_db --user=mysql > /dev/null 2>&1
		echo "=> Installing mysql... Done!"

        # Move previous error log (which might be there) from previously running container
        # to different location. We do that to have error log from the currently running
        # container only.
        if [ -f $ERROR_LOG ]; then
            echo "----------------- Previous error log -----------------"
            tail -n 20 $ERROR_LOG
            echo "----------------- Previous error log ends -----------------" && echo
            mv -f $ERROR_LOG "${ERROR_LOG}.old";
        fi

        touch $ERROR_LOG && chown mysql $ERROR_LOG
	else
		echo "=> Using an existing volume of mysql."
		EXISTING_MYSQL=true
	fi
}

#########################################################
# Check in the loop (every 1s) if the database backend
# service is already available for connections.
# Globals:
#   $MYSQL_USER
#   $MYSQL_USER_PASS
#########################################################
function create_admin_user() {
	if [ "$EXISTING_MYSQL" = true ]; then
		return
	fi

	echo "Creating DB admin user..." && echo
	local users=$(mysql -s -e "SELECT count(User) FROM mysql.user WHERE User='$MYSQL_USER'")
	if [[ $users == 0 ]]; then
		echo "=> Creating mysql user '$MYSQL_USER' with '$MYSQL_USER_PASS' password."
		mysql -uroot -e "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_USER_PASS'"
	else
		echo "=> User '$MYSQL_USER' exists, updating its password to '$MYSQL_USER_PASS'"
		mysql -uroot -e "SET PASSWORD FOR '$MYSQL_USER'@'%' = PASSWORD('$MYSQL_USER_PASS')"
	fi;
  
	mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' WITH GRANT OPTION"

	echo "========================================================================"
	echo "    You can now connect to this mysql server using:                     "
	echo "    mysql -u$MYSQL_USER -p$MYSQL_USER_PASS -h<host>                          "
	echo "                                                                        "
	echo "    For security reasons, you might want to change the above password.  "
	echo "    The 'root' user has password '$MYSQL_ROOT_PASS' but is localhost log-in only  "
	echo "========================================================================"
}

function show_db_status() {
	if [ "$EXISTING_MYSQL" = true ]; then
		return
	fi

	echo "Showing DB status..." && echo
	mysql -uroot -e "status"
}

function secure_and_tidy_db() {
	if [ "$EXISTING_MYSQL" = true ]; then
		return
	fi

	echo "Securing and tidying DB..."

	echo "Dropping test db"
	mysql -uroot -e "DROP DATABASE IF EXISTS test"
	echo "Deleting user where User is blank"
	mysql -uroot -e "DELETE FROM mysql.user where User = ''"

	# Remove warning about users with hostnames (as DB is configured with skip_name_resolve)
	echo "Delete root bits n pieces"
	mysql -uroot -e "DELETE FROM mysql.user where User = 'root' AND Host NOT IN ('localhost','127.0.0.1','::1')"
	mysql -uroot -e "DELETE FROM mysql.proxies_priv where User = 'root' AND Host NOT IN ('localhost','127.0.0.1','::1')"

	echo "Set root password"

	mysql -uroot -e "FLUSH PRIVILEGES"
	mysql -uroot -e "SET PASSWORD FOR 'root'@'::1' = PASSWORD('$MYSQL_ROOT_PASS')"
	mysql -uroot -e "SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('$MYSQL_ROOT_PASS')"
	mysql -uroot -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASS')"
	echo "Securing and tidying DB... Done!"
}

install_db

tail -F $ERROR_LOG & # tail all db logs to stdout 

chown -R mysql:mysql $VOLUME_HOME

if ps ax -ocomm | grep mysqld_safe | grep -v grep; then
	echo "mysql daemon already running"
	exit 0;
fi

/usr/bin/mysqld_safe & # Launch DB server in the background
MYSQLD_SAFE_PID=$!

wait_for_db
show_db_status
create_admin_user
secure_and_tidy_db
