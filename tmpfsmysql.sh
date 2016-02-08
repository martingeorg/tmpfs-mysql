#!/bin/bash

LOGFILE='./tmpfsmysql.log'
LOGFILE_LINES=1000
CONFIG_FILE='tmpfsmysql.cfg'

function LOAD_CONFIG
{
	if test -e "$CONFIG_FILE" -a -r "$CONFIG_FILE" -a -f "$CONFIG_FILE"
	then
		source "$CONFIG_FILE"
		return 1;
	else
		touch "$CONFIG_FILE"
		printf "PORT=3344\nPASSWORD='drowssap'\nTMPFS_SIZE=256\n\nDBNAMES[0]=''\nDUMPFILES[0]=''\nIMPORTSFROM[0]='::::'\nRUNCOMMANDS[0]=''\n" > "$CONFIG_FILE"
		return 0;
	fi
}

LOAD_CONFIG


if [ "$1" == "" ]
then
	echo -n ""; echo -ne '\E[1;29;42m'; echo -n "TMPFS-MYSQL server management tool"
	tput sgr0
	echo ""
	echo ""
	echo "Available command options are:"
	echo " start     - Starts the tmpfs mysql instance. This will kill any already started tmpfs mysql server"
	echo " stop      - Stop the tmpfs mysql server instance"
	echo " kill      - Kill any other instances of the mysqld daemon besides the normal mysql server"
	echo " status    - Check whether the tmpfs mysql server is running"
	echo " client    - You will be connected to the tmpfs mysql server using the mysql client"
	echo " showdb    - Show a list of the databases on the tmpfs mysql server"
	echo " checkdump - Check if the dump file configured in DUMPFILE exists and is readable"
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
echo "The script needs sudo access in order to work"
sudo date >>$LOGFILE # dummy command to cache the sudo credentials for the commands below
echo ""

PID=`sudo cat /tmp/mysqldtmpfs.pid 2>/dev/null`

function killByPID {
	if [ "$PID" != "" ]
	then
		echo "Terminating tmpfs mysqld process with id $PID..."
		sudo kill -s term $PID >>$LOGFILE 2>>$LOGFILE
	fi
}

# to be fixed to work with parameters indexes
function checkSQLdumpFile {
	if test -e "$DUMPFILE" -a -r "$DUMPFILE" -a -f "$DUMPFILE"
	then
		echo -ne '\E[1;29;42m';
		echo -n "The SQL dump file at '$DUMPFILE' exists and is readable."
		tput sgr0
		echo ""
	else
		echo -ne '\E[1;29;41m';
		echo -n "The SQL dump file at '$DUMPFILE' either does not exists or is not readable."
		tput sgr0
		echo ""
	fi
}

if [ "$1" == "status" ]
then
	if [ "$PID" != "" ]
	then
		echo -n "The tmpfs mysql server seems to be "; echo -ne '\E[1;29;42m'" running "; tput sgr0
	else
		echo -n "The tmpfs mysql server seems to be "; echo -ne '\E[1;29;41m'" down "; tput sgr0
	fi
	echo ""
	echo ""
	exit 0
fi

if [ "$1" == "client" ]
then
	echo -ne '\E[3;29;44m'"Logging into the tmpfs mysql server...                                                            "; tput sgr0
	echo ""
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD 2>>$LOGFILE
	exit 0
fi

if [ "$1" == "showdb" ]
then
	echo -ne '\E[3;29;44m'"Showing databases on the tmpfs mysql server...                                                    "; tput sgr0
	echo ""
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e 'show databases' 2>>$LOGFILE
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
	echo "The tmpfs mysql server instance has been stopped."
	echo ""
	exit 0
fi

if [ "$1" == "kill" ]
then
	killByPID
	NMPID=`sudo cat /var/run/mysqld/mysqld.pid 2>/dev/null`
	echo "You have issued the kill command, we'll now stop the normal mysql server if it is running and kill any other instances of the mysqld daemon..."
	if [ "$NMPID" != "" ]
	then
		echo "Gracefully stopping the normal mysql server and killing any other mysqld process..."
		sudo service mysql stop >>$LOGFILE 2>>$LOGFILE
		sleep 1
	fi
	sudo killall mysqld >>$LOGFILE 2>>$LOGFILE
	sleep 1
	if [ "$NMPID" != "" ]
	then
		echo "Starting up the normal mysql server..."
		sudo service mysql restart >>$LOGFILE 2>>$LOGFILE #&
	fi
	#echo "...check again the running mysqld instances..."
	#sudo ps -aux | grep -i mysqld
	exit 0
fi


if [ "$1" == "start" ]
then
	killByPID

	echo "Delete old temporary file system in RAM..."
	sudo umount -l /tmp/mysqldtmpfsdatadir >>$LOGFILE 2>>$LOGFILE
	sleep 1

	sudo rm -rf /tmp/mysqldtmpfsdatadir >>$LOGFILE 2>>$LOGFILE
	sleep 1

	echo "Creating temporary file system in RAM..."
	sudo mkdir /tmp/mysqldtmpfsdatadir >>$LOGFILE 2>>$LOGFILE
	sudo mount -t tmpfs -o size="$TMPFS_SIZE"M tmpfs /tmp/mysqldtmpfsdatadir >>$LOGFILE 2>>$LOGFILE

	echo "Installing the new mysql database in the tmpfs directory..."
	sudo mysql_install_db --no-defaults --random-password --user=mysql --datadir=/tmp/mysqldtmpfsdatadir >>$LOGFILE 2>>$LOGFILE
	sleep 1

	echo "Starting the tmpfs mysql server with specific parameters in order to use the tmpfs datadir..."
	sudo -u mysql mysqld --basedir=/usr --datadir=/tmp/mysqldtmpfsdatadir/ --plugin-dir=/usr/lib/mysql/plugin --pid-file=/tmp/mysqldtmpfs.pid \
	--socket=/tmp/mysqldtmpfs.sock --port=$PORT --log-error=/tmp/mysqldtmpfserror.log --bind-address=0.0.0.0 --innodb_flush_log_at_trx_commit=2 --verbose >>$LOGFILE 2>>$LOGFILE &
	echo "Waiting for the new mysql server instance to fire up before we continue..."
	sleep 1

	echo "Setting default password..."
	RANDOMPASS=`sudo awk 'BEGIN {thepass = ""} /password/ { thepass = $18 } END { print thepass }' ~/.mysql_secret`
	mysqladmin -u root --host=0.0.0.0 --port=$PORT --password=$RANDOMPASS password $PASSWORD >>$LOGFILE 2>>$LOGFILE
	echo "Allow remote access from any host..."
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$PASSWORD';" >>$LOGFILE 2>>$LOGFILE
	mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e 'FLUSH PRIVILEGES;' >>$LOGFILE 2>>$LOGFILE
	
	
	for DBINDEX in "${!DBNAMES[@]}"
	do
		if [ "${DBNAMES[$DBINDEX]}" != "" ]
		then
			mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD -e "create database ${DBNAMES[$DBINDEX]};" >>$LOGFILE 2>>$LOGFILE
			
			if [ "${DUMPFILES[$DBINDEX]}" != "" ]
			then
				if test -e "${DUMPFILES[$DBINDEX]}" -a -r "${DUMPFILES[$DBINDEX]}" -a -f "${DUMPFILES[$DBINDEX]}"
				then
					echo -ne '\E[1;29;42m';
					echo -n "Importing sql dump file"
					tput sgr0
					echo ""
					mysql -u root --host=0.0.0.0 --port=$PORT --password=$PASSWORD "${DBNAMES[$DBINDEX]}" < "${DUMPFILES[$DBINDEX]}" >>$LOGFILE 2>>$LOGFILE
				else
					echo -ne '\E[1;29;41m';
					echo -n "Couldn't find or read sql dump file, please check the path and try again"
					tput sgr0
					echo ""
				fi
			fi
			
			if [ "${RUNCOMMANDS[$DBINDEX]}" != "" ]
			then
				"${RUNCOMMANDS[$DBINDEX]}" >>$LOGFILE 2>>$LOGFILE
			fi
		
		fi
	done

	echo -ne '\E[1;29;42m'"tmpfs-mysql server has started"; tput sgr0
	echo ""
	echo "The password for the tmpfs mysql server is '$PASSWORD' and the port is $PORT."
	echo ""
fi

# keep the log file at reasonable size
if test -e "$LOGFILE" -a -r "$LOGFILE" -a -f "$LOGFILE"
then
	mv "$LOGFILE" "$LOGFILE".bak
	tail -n $LOGFILE_LINES "$LOGFILE".bak > "$LOGFILE"
	rm -f "$LOGFILE".bak
fi
