#!/bin/bash
#
# The MIT License (MIT)
#
# Copyright (c) 2016 Martin Georgiev
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# Version: 0.2
# Author: https://github.com/martingeorg
#
# This bash script is used to initialize and start a separate instance of the MySQL server
# having its datadir into a tmpfs(in memory) mountpoint located in the /tmp folder.
#
# This is usefull when someone wants to run tests(PHPUnit, Codeception, etc.) faster than
# they would run in a "normal" mysql instance with its datadir on the hard drive.
# As the fixtures are loaded/unloaded on every test method, in time, this operation
# becomes quite slow, even with optimized mysql server parameters.
#
# NOTE that using the RAM as mysql data storage means that this data IS NOT PERMANENT!
# As we are using it for running tests we don't really care about that.
#
# We are using the /tmp folder to mount our 'mysqldtmpfsdatadir' datadir as it doesn't
# require any special privileges and it doesn't have problems with apparmor.


# Configuration
# If both, DBNAME and DUMPFILE are given, then the script will create the database and import the dump file in it
DBNAME=''
DUMPFILE=''
PORT=3344
PASSWORD='drowssap'
# the tmpfs filesystem in megabytes
TMPFS_SIZE=256

if [ "$1" == "" ]
then
	echo -ne '\E[3;38;44m'
	echo -n "                                                                                                          "
	tput sgr0
	echo ""
	echo ""
	echo -n "                             "; echo -ne '\E[1;29;46m'; echo -n "  TMPFS-MYSQL server management tool  "
	tput sgr0
	echo ""
	echo ""
	echo " For the moment this script only works for MySQL server 5.6 versions running on Ubuntu based distributions"
	echo ""
	echo " Available command options are:"
	echo "  start     - Starts the tmpfs mysql instance. This will kill any already started tmpfs mysql server"
	echo "  stop      - Stop the tmpfs mysql server instance"
	echo "  kill      - Kill any other instances of the mysqld daemon besides the normal mysql server"
	echo "  status    - Check whether the tmpfs mysql server is running"
	echo "  client    - You will be connected to the tmpfs mysql server using the mysql client"
	echo "  showdb    - Show a list of the databases on the tmpfs mysql server"
	echo "  checkdump - Check if the dump file configured in DUMPFILE exists and is readable"
	echo ""
	#echo "##########################################################################################################"
	echo ""
	exit 0
fi

function checkForMySQL {
	MYSQLDINSTALLED=`which mysqld`
	if [ "$MYSQLDINSTALLED" == "" ]
	then
		echo ""
		echo "YOU DON'T HAVE MYSQL SERVER INSTALLED, PLEASE INSTALL IT BEFORE TRYING TO USE THIS SCRIPT"
		echo ""
		exit 0
	fi
}
checkForMySQL

echo ""
echo " The script needs sudo access in order to work"
sudo date >/dev/null # dummy command to cache the sudo credentials for the commands below
echo ""

PID=`sudo cat /tmp/mysqldtmpfs.pid 2>/dev/null`

function killByPID {
	if [ "$PID" != "" ]
	then
		echo " Terminating tmpfs mysqld process with id $PID..."
		sudo kill -s term $PID
	fi
}

function checkSQLdumpFile {
	if test -e "$DUMPFILE" -a -r "$DUMPFILE" -a -f "$DUMPFILE"
	then
		echo -ne '\E[1;29;42m';
		echo -n " The SQL dump file at '$DUMPFILE' exists and is readable."
		tput sgr0
		echo ""
	else
		echo -ne '\E[1;29;41m';
		echo -n " The SQL dump file at '$DUMPFILE' either does not exists or is not readable."
		tput sgr0
		echo ""
	fi
}

if [ "$1" == "status" ]
then
	if [ "$PID" != "" ]
	then
		echo -n " The tmpfs mysql server seems to be "; echo -ne '\E[1;29;42m'" running "; tput sgr0
	else
		echo -n " The tmpfs mysql server seems to be "; echo -ne '\E[1;29;41m'" down "; tput sgr0
	fi
	echo ""
	echo ""
	exit 0
fi

if [ "$1" == "client" ]
then
	echo -ne '\E[3;29;44m'" Logging into the tmpfs mysql server...                                                            "; tput sgr0
	echo ""
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD 2>/dev/null
	exit 0
fi

if [ "$1" == "showdb" ]
then
	echo -ne '\E[3;29;44m'" Showing databases on the tmpfs mysql server...                                                    "; tput sgr0
	echo ""
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e 'show databases' 2>/dev/null
	echo ""
	exit 0
fi

if [ "$1" == "checkdump" ]
then
	checkSQLdumpFile
	echo ""
	exit 0
fi

if [ "$1" == "stop" ]
then
	killByPID
	echo " The tmpfs mysql server instance has been stopped."
	echo ""
	exit 0
fi

if [ "$1" == "kill" ]
then
	killByPID
	NMPID=`sudo cat /var/run/mysqld/mysqld.pid 2>/dev/null`
	echo " You have issued the kill command, we'll now stop the normal mysql server if it is running and kill any other instances of the mysqld daemon..."
	if [ "$NMPID" != "" ]
	then
		echo " Gracefully stopping the normal mysql server and killing any other mysqld process..."
		sudo service mysql stop >/dev/null 2>/dev/null
		sleep 1
	fi
	sudo killall mysqld >/dev/null 2>/dev/null
	sleep 1
	if [ "$NMPID" != "" ]
	then
		echo " Starting up the normal mysql server..."
		sudo service mysql restart >/dev/null 2>/dev/null #&
	fi
	#echo "...check again the running mysqld instances..."
	#sudo ps -aux | grep -i mysqld
	exit 0
fi


if [ "$1" == "start" ]
then
	killByPID

	echo " Delete old temporary file system in RAM..."
	sudo umount -l /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
	sleep 1

	sudo rm -rf /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
	sleep 1

	echo " Creating temporary file system in RAM..."
	sudo mkdir /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
	sudo mount -t tmpfs -o size="$TMPFS_SIZE"M tmpfs /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null

	echo " Installing the new mysql database in the tmpfs directory..."
	sudo mysql_install_db --no-defaults --random-password --user=mysql --datadir=/tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
	sleep 1

	echo " Starting the tmpfs mysql server with specific parameters in order to use the tmpfs datadir..."
	sudo -u mysql mysqld --basedir=/usr --datadir=/tmp/mysqldtmpfsdatadir/ --plugin-dir=/usr/lib/mysql/plugin --pid-file=/tmp/mysqldtmpfs.pid \
	--socket=/tmp/mysqldtmpfs.sock --port=$PORT --log-error=/tmp/mysqldtmpfserror.log --bind-address=0.0.0.0 --verbose >/dev/null 2>/dev/null &
	echo " Waiting for the new mysql server instance to fire up before we continue..."
	sleep 1

	echo " Setting default password..."
	RANDOMPASS=`sudo awk 'BEGIN {thepass = ""} /password/ { thepass = $18 } END { print thepass }' ~/.mysql_secret`
	mysqladmin -u root --host=0.0.0.0 --port=$PORT --password=$RANDOMPASS password $PASSWORD >/dev/null 2>/dev/null
	echo " Allow remote access from any host..."
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$PASSWORD';" >/dev/null 2>/dev/null
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e 'FLUSH PRIVILEGES;' >/dev/null 2>/dev/null

	if [ "$DBNAME" != "" ] && [ "$DUMPFILE" != "" ]
	then

		if test -e "$DUMPFILE" -a -r "$DUMPFILE" -a -f "$DUMPFILE"
		then
			echo -ne '\E[1;29;42m';
			echo -n " Creating database and importing the sql dump file located at '$DUMPFILE'..."
			tput sgr0
			echo ""
			mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e "create database $DBNAME;" >/dev/null 2>/dev/null
			mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD "$DBNAME" < "$DUMPFILE" >/dev/null 2>/dev/null
		else
			echo -ne '\E[1;29;41m';
			echo -n " Couldn't find/read sql dump file '$DUMPFILE', please check the path/name and try again..."
			tput sgr0
			echo ""
		fi
	fi

	echo " Done initializing the tmpfs mysql server."
	echo " The password for the tmpfs mysql server is '$PASSWORD' and the port is $PORT."
	echo -n " "; echo -ne '\E[1;29;42m'" tmpfs-mysql server has started "; tput sgr0
	echo ""
fi
