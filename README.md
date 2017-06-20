# tmpfs-mysql

### Speed up your tests using MySQL/MariaDB server with tmpfs datadir :runner::zap:

![tmpfs mysql screenshot](http://martingeorg.github.io/tmpfsmysqlscreen-06-2017.png)

### This repository has two key parts
- Bash script instantiating a mysql server with datadir set to a tmpfs mounted filesystem
- Vagrantfile which can be used to fire up Ubuntu instance where the script can be used


#### The bash file
The Bash script can be used to fire up a MySQL/MariaDB server instance whose datadir is located
in a tmpfs(in memory/RAM) filesystem mounted in the /tmp/tmpfs-mysql/datadir folder.

The 'normal' mysql server is kept intact.


#### The Vagrantfile
If you don't like the idea of having secondary mysql server instance running on your machine, there is a Vagrantfile
which could be used to fire up a vagrant Ubuntu server instance.
The Vagrant file has provisioning script which installs the *mysql-server* and removes *chef* and *puppet*
as we won't need them and they just use memory.

### Why would i need this?
Having a mysql server instance with datadir in the memory, makes executing queries very... very fast.

This is usefull when running unit tests using PHPUnit, Codeception, etc. As the fixtures are being reloaded into the
database on every test method, that unloading/loading of fixtures becomes slower and slower with the rising amount of fixtures.

With mysql server having its datadir in memory, the fixtures loading/unloading is no longer a time waster.

It is **IMPORTANT** to note that the tmpfs is **NOT A PERMANENT** storage, so don't use it for data which needs to persist.
Test fixtures are disposable so we don't care about persistence.


### How to use it?

##### Compatability
This script currently works with **Ubuntu** based Linux distributions and Debian.

Supported MySQL server versions are
- 5.5
- 5.6
- 5.7

MariaDB is also supported. The code for MariaDB support was tested with version 10.0.27, but other versions should work as well.

Future versions will add support for other distributions.

##### Before we begin
The user for connecting to the tmpfs database is... wait for it... "tmpfs" :)

The default password set in the <code>PASSWORD</code> variable is 'drowssap'.

The port for the tmpfs mysql instance, set in the <code>PORT</code> variable is 3344.


##### In order to use the script, just follow these steps
- run the script
  <code>./tmpfsmysql.sh</code>
- it'll ask for your password so it can <code>sudo</code>
- on its first run, the script will create a configuration file "tmpfsmysql.cfg", take a look at it and adjust the configuration to your needs
- to start the tmpfs-mysql server run the script again with the start option
  <code>./tmpfsmysql.sh start</code>

You can now connect to the tmpfs mysql instance using the following command (given that you haven't changed the settings in the script)

<code>mysql -u tmpfs --host=0.0.0.0 --port=3344 --password=drowssap</code>

Instead of 0.0.0.0 you can use your computer's LAN IP address, e.g. 192.168.x.x


##### If you want to use the script with the vagrant Ubuntu instance just execute the following commands from within the folder containing the Vagrantfile
- <code>vagrant up</code>
- <code>vagrant ssh</code>
- <code>cd /vagrant</code>
- <code>./tmpfsmysql.sh</code>
- <code>ifconfig</code>
- <code>exit</code>

The *ifconfig* command is just so you can see what network address has been given to the virtual machine.

You can now connect to the tmpfs mysql instance using the following command (given that you haven't changed the settings in the script)

<code>mysql -u tmpfs --host=192.168.33.10 --port=3344 --password=drowssap</code>

The IP address 192.168.33.10 is the *host-only* address of the virtual machine, you can also use the *bridged* network address (the one you saw using *ifconfig*) to access the mysql server locally or from another machine in your network.


##### What's next?
Now simply configure your tests to use that mysql instance as database server and enjoy *the fastest tests alive* :runner::zap:


##### How to stop the tmpfs mysql server instance?
Just issue the following command <code>./tmpfsmysql.sh stop</code>


### Looking forward :construction:
- [x] Add option in config file for custom parameters to the mysqld starting command.
- [ ] Automatic execution of the tmpfsmysql.sh should be implemented on vagrant up.
- [x] The 'normal' mysql server instance being restarted should be fixed.
- [ ] Detect the Linux distribution and use the relevant commands
- [x] Detect MySQL server version and use the specific parameters
- [x] MariaDB support
