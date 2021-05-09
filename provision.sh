#!/bin/bash

# parameter - username
# if user exists, then exit code = 0, otherwise not 0
function user_exists() {
	id "$1" &> /dev/null 
#	grep -q "$1" /etc/passwd
}

# parameter - groupname
# if group exists, then exit code = 0, otherwise not 0
function group_exists() {
	grep -q "$1" /etc/group
}

function delete_user_if_exists() {
	if ( user_exists "$1" )
	then
		echo -e "User '$1' already exists. Deleting him..."
		userdel --remove "$1"	
	fi 
}

# parameters: groupname gid
function create_or_change_group() {
	if ( group_exists "$1" ) 
	then
		echo -e "Group '$1' exists. Editing its gid..."
		# change gid or delete???
		groupmod -g "$2" $1
	else
		groupadd --gid $2 "$1"
	fi
}

# You are to develop a bash script provision.sh that being invoked as root performs the following:

# 1.	(as root) Create user Name_Surname with primary group, UID = 505, GID=505

NAME_SURNAME_LOGIN="Uladzislau_Petravets"
NAME_SURNAME_GID=505
NAME_SURNAME_UID=505

# should we delete all the users processes if user is logged in???
# who | grep -i -m 1 "$NAME_SURNAME_LOGIN" | awk '{ print $1} '
delete_user_if_exists "$NAME_SURNAME_LOGIN"

create_or_change_group "$NAME_SURNAME_LOGIN" $NAME_SURNAME_GID

adduser --gid $NAME_SURNAME_GID --uid $NAME_SURNAME_UID "$NAME_SURNAME_LOGIN"

# 2.	(as root) Create user mongo with primary group staff, UID=600, GID=600

MONGO_LOGIN="mongo"
MONGO_GROUPNAME="staff"
MONGO_UID=600
MONGO_GID=600

delete_user_if_exists $MONGO_LOGIN

create_or_change_group "$MONGO_GROUPNAME" $MONGO_GID

adduser --gid $MONGO_GID --uid $MONGO_UID "$MONGO_LOGIN"

# 3.	(as root) Create folders /apps/mongo/, give 750 permissions, set owner mongo:staff

[ -e /apps/mongo ] && rm -r /apps/mongo
#[ -e /apps ] && rm -r /apps

mkdir --parents /apps/mongo
chmod --recursive 750 /apps
chown --recursive $MONGO_UID:$MONGO_GID /apps

# 4.	(as root) Create folders /apps/mongodb/, give 750 permissions, set owner mongo:staff

[ -e /apps/mongodb ] && rm -r /apps/mongodb
#[ -e /apps ] && rm -r /apps

mkdir --parents /apps/mongodb
#chmod --recursive 750 /apps
#chown --recursive $MONGO_UID:$MONGO_GID

# 5.	(as root) Create folders /logs/mongo/, give 740 permissions, set owner mongo:staff

[ -e /logs/mongo ] && rm -r /logs/mongo
#[ -e /apps ] && rm -r /apps

mkdir --parents /logs/mongo
chmod --recursive 740 /logs
chown --recursive $MONGO_UID:$MONGO_GID /logs

# 6.	(as mongo) Download with wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-3.6.5.tgz

# check if wget is installed

rpm -aq | grep -q wget
if [ $? -ne 0 ]
then
	echo "Installing wget..."
	# install wget
	# should i keep errors?
	yum install --quiet --assumeyes wget
	echo "wget has been installed"
fi

echo "Downloading file 'mongodb-linux-x86_64-3.6.5.tgz'..."
wget --quiet https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-3.6.5.tgz
if [ $? -eq 0 ] 
then
	echo "'mongodb-linux-x86_64-3.6.5.tgz' has been downloaded"
else
	echo "some errors occurs while downloading with wget"
fi


# 7.	(as mongo) Download with curl https://fastdl.mongodb.org/src/mongodb-src-r3.6.5.tar.gz

echo "Downloading file 'mongodb-src-r3.6.5.tar.gz'"
curl --silent --remote-name https://fastdl.mongodb.org/src/mongodb-src-r3.6.5.tar.gz
if [ $? -eq 0 ]
then
	echo "'mongodb-src-r3.6.5.tar.gz' has been downloaded"
else
	echo "some errors occurs while downloading with curl"
fi

# 8.	(as mongo) Unpack mongodb-linux-x86_64-3.6.5.tgz to /tmp/

echo "Extracting 'mongodb-linux-x86_64-3.6.5.tgz' to /tmp"
sudo --user=mongo tar -xzf mongodb-linux-x86_64-3.6.5.tgz -C /tmp
if [ $? -eq 0 ]
then
	echo "'mongodb-linux-x86_64-3.6.5/' has been extracted to /tmp"
else
	echo "some errors occurs while extracting"
fi

# 9.	(as mongo) Copy ./mongodb-linux-x86_64-3.6.5/* to /apps/mongo/

echo "Copying '/tmp/mongodb-linux-x86_64-3.6.5/' to /apps/mongo"
sudo --user=mongo cp --recursive /tmp/mongodb-linux-x86_64-3.6.5/ /apps/mongo
if [ $? -eq 0 ]
then
	echo "'mongodb-linux-x86_64-3.6.5/' has been copied"
else
	echo "some errors occurs while copying"
fi

# 10.	(as mongo) Update PATH on runtime by setting it to PATH=<mongodb-install-directory>/bin:$PATH

export PATH="/apps/mongo/mongodb-linux-x86_64-3.6.5/bin${PATH:+:${PATH}}"

# 11.	(as mongo) Update PATH in .bash_profile and .bashrc with the same

sudo --user mongo echo -e "# Path to mongo according to the task\nexport PATH="/apps/mongo/mongodb-linux-x86_64-3.6.5/bin${PATH:+:${PATH}}"\n" >> ~/.bashrc

# 12.	(as root) Setup number of allowed processes for mongo user: soft and hard = 32000

# 13.	(as root) Give sudo rights for Name_Surname to run only mongod as mongo user

# 14.	(as root) Create mongo.conf from sample config file from archive 7.

# 15.	(as root) Replace systemLog.path and storage.dbPath with /logs/mongo/ and /apps/mongodb/ accordingly in mongo.conf using sed or AWK

# 16.	(as root) Create SystemD unit file called mongo.service. Unit file requirenments:

# 	a.	Pre-Start: Check if file /apps/mongo/bin/mongod and folders (/apps/mongodb/ and /logs/mongo/) exist, check if permissions and ownership are set correctly.

# 17.	(as root) Add mongo.service to autostart


# Check

# 1.	Run mongod from Name_Surname

# 2.	Prove that process is running

# 	a.	PID exists

# 	b.	Corresponding [initandlisten] message in mongo log 

# 	c.	Port is really listening

# 3.	Stop the process

# 4.	Verify that systemd unit is working (start, status, stop, status).



