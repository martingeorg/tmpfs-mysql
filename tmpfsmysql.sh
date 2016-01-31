#!/bin/bash
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
#
# TODO: Check MySQL version and use specific commands/parameters.
# TODO: Find out how to get the specific process ids for the tmpfs mysql server instance
#       and kill only them instead of using killall. Thus, avoiding the restart of
#		the 'normal' mysql service.
#


# Configuration
# If both, DBNAME and DUMPFILE are given, then the script will create the database and import the dump file in it
DBNAME=''
DUMPFILE=''
PORT=3344
PASSWORD='drowssap'
# the tmpfs filesystem in megabytes
TMPFS_SIZE=256


echo "Script for initializing tmpfs mysql server"
echo "This script works for MySQL server 5.6 versions running on Ubuntu based distributions for now..."
echo "Pass the 'stop' parameter to the script in order to stop the tmpfs mysql server instance"
echo "The following commands require root access using sudo"
sudo whoami >/dev/null # dummy command to cache the sudo credentials for the commands below

echo ""
echo "...stopping the normal mysql server and killing any other mysqld process..."
sudo service mysql stop >/dev/null 2>/dev/null
sleep 1
sudo killall mysqld >/dev/null 2>/dev/null
sleep 1

#echo "...look if any mysqld instances are still running..."
#sudo ps -aux | grep -i mysqld
#sleep 5

echo "...delete old temporary file system in RAM..."
#sudo umount -f /tmp/mysqldtmpfsdatadir #>/dev/null 2>/dev/null
#sudo fuser -km /tmp/mysqldtmpfsdatadir #>/dev/null 2>/dev/null
sudo umount -l /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
sleep 1

sudo rm -rf /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
sleep 1


if [ "$1" == "stop" ]
then
	echo "...starting the normal mysql server..."
	sudo service mysql restart >/dev/null 2>/dev/null #&
	sleep 1
	echo "...the tmpfs mysql server instance has been stopped."
	#echo "...check if any tmpfs mysqld instances are still running..."
	#sudo ps -aux | grep -i mysqld
	exit 0
fi


echo "...creating temporary file system in RAM..."
sudo mkdir /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
sudo mount -t tmpfs -o size="$TMPFS_SIZE"M tmpfs /tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null

echo "...installing the new mysql database in the tmpfs directory..."
sudo mysql_install_db --no-defaults --random-password --user=mysql --datadir=/tmp/mysqldtmpfsdatadir >/dev/null 2>/dev/null
sleep 2

echo "...starting the tmpfs mysql server with specific parameters in order to use the tmpfs datadir..."
sudo -u mysql mysqld --basedir=/usr --datadir=/tmp/mysqldtmpfsdatadir/ --plugin-dir=/usr/lib/mysql/plugin --pid-file=/tmp/mysqldtmpfs.pid --socket=/tmp/mysqldtmpfs.sock --port=$PORT --log-error=/tmp/mysqldtmpfserror.log --bind-address=0.0.0.0 --verbose >/dev/null 2>/dev/null &
echo "...waiting for the new mysql server instance to fire up before we continue..."
sleep 2

echo "...setting default password..."
mysqladmin -u root --host=0.0.0.0 --port=$PORT --password=`sudo awk 'BEGIN {thepass = ""} /password/ { thepass = $18 } END { print thepass }' ~/.mysql_secret` password $PASSWORD >/dev/null 2>/dev/null
echo "...allow remote access from any host..."
mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$PASSWORD';" >/dev/null 2>/dev/null
mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e 'FLUSH PRIVILEGES;' >/dev/null 2>/dev/null
sleep 1

if [ "$DBNAME" != "" ] && [ "$DUMPFILE" != "" ]
then
	echo "...creating database and importing the sql dump file..."
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e "create database $DBNAME;" >/dev/null 2>/dev/null
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD "$DBNAME" < "$DUMPFILE" >/dev/null 2>/dev/null
fi

echo "...restarting the normal mysql server..."
sudo service mysql restart >/dev/null 2>/dev/null #&
sleep 1
#echo "...check again the running mysqld instances..."
#sudo ps -aux | grep -i mysqld

echo "...done initializing tmpfs mysql server, now you have the normal mysql server as well as one having its datadir in the RAM."
echo "The password for the tmpfs mysql server is '$PASSWORD' and the port is $PORT."
echo ""

#mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e 'show databases' 2>/dev/null
#echo "...logging you into the new mysql server..."
#mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD
