# tmpfs-mysql

### Speed up your unit tests using mysql server with tmpfs datadir :runner::zap:

### This repository contains two key parts
- Bash script instantiating a mysql server with datadir set to a tmpfs mounted filesystem
- Vagrantfile which can be used to fire up Ubuntu instance where the script can be used


#### The bash file
The Bash script can be used to fire up a mysql server instance whose datadir is located
in a tmpfs(in memory/RAM) filesystem mounted in the /tmp/mysqldtmpfsdatadir folder.

The 'normal' mysql server is kept intact, besides the fact that it's being restarted.


#### The Vagrantfile
If you don't like the idea of having secondary mysql server instance running on your machine, there is a Vagrantfile
which could be used to fire up a vagrant Ubuntu server instance.
The Vagrant file has provisioning script which installs the *mysql-server* and removes *chef* and *puppet*
as we won't need them and they just use memory.

### Why would i need this
Having a mysql server instance with datadir in the memory, makes executing queries very... very fast.

This is usefull when running unit tests using PHPUnit, Codeception, etc. As the fixtures are being reloaded into the
database on every test method, that unloading/loading of fixtures becomes slower and slower with the rising of the number of fixtures.

With mysql server having its datadir in memory, the fixtures loading/unloading is no longer a time waster.

It is **IMPORTANT** to note that the tmpfs in **NOT A PERMANENT** storage, so don't use it for data which needs to persist.
Test fixtures are disposable so we don't care about persistence.


### How to use it

##### Compatability
This script works with **Ubuntu** based Linux distributions and **MySQL server 5.6** versions.
Future verions could address those limitations.

##### Before we begin
You should know that the script has two variables called <code>DBNAME</code> and <code>DUMPFILE</code> which can be used to automatically create a database and import an sql dump file in it.

##### In order to use the script, just follow these steps
- have a look at the script, check out the configuration options at the beginning of the file and adjust them for your needs
- make the script executable <code>chmod u+x tmpfsmysql.sh</code>
- run the script <code>./tmpfsmysql.sh</code>
- it'll ask for your password so it can <code>sudo</code>

You can now connect to the tmpfs mysql instance using the following command (given that you haven't changed the settings in the script)

<code>mysql -u root --host=0.0.0.0 --port=3344 --password=drowssap</code>

##### If you want to use the script with the vagrant Ubuntu instance just execute the following commands from within the folder containing the Vagrantfile
- <code>vagrant up</code>
- <code>vagrant ssh</code>
- <code>cd /vagrant</code>
- <code>chmod u+x tmpfsmysql.sh</code>
- <code>./tmpfsmysql.sh</code>
- <code>ifconfig</code>

The last command is just so you can see what network address has been given to the virtual machine.

You can now connect to the tmpfs mysql instance using the following command (given that you haven't changed the settings in the script)

<code>mysql -u root --host=192.168.33.10 --port=3344 -p</code>

The IP address 192.168.33.10 is the *host-only* address of the virtual machine, you can also use the *bridged* network address to access the mysql server locally or from another machine in your network.


##### What's next
Now simply configure your tests to use that mysql instance as database server and enjoy *the fastest tests alive* :runner::zap:


##### How to stop the tmpfs mysql server instance
Just issue the following command <code>./tmpfsmysql.sh stop</code>


### Looking forward :construction:
- Automatic execution of the tmpfsmysql.sh should be implemented on vagrant up.
- The 'normal' mysql server instance being restarted should be fixed.
- Detect the Linux distribution and use the relevant commands
- Detect MySQL server version and use the specific parameters



