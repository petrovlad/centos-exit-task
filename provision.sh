#!/bin/bash

set -e

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

# parameters: login src_path dest_path
function extract_tar_silently() {
	echo "Extracting '$2' to $3"
	sudo -u "$1" tar -xzf "$2" -C "$3"
	if [ $? -eq 0 ]
	then
		echo "'$2' has been extracted to '$3'"
	else
		echo "some errors occurs while extracting"
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
chmod 750 /apps/mongo
chown $MONGO_UID:$MONGO_GID /apps/mongo

# 4.	(as root) Create folders /apps/mongodb/, give 750 permissions, set owner mongo:staff

[ -e /apps/mongodb ] && rm -r /apps/mongodb

mkdir --parents /apps/mongodb
chmod 750 /apps/mongodb
chown $MONGO_UID:$MONGO_GID /apps/mongodb

#idk should i set perms and ownership on /apps & /logs dirs, so i let it here
#chmod --recursive 750 /apps
#chown --recursive $MONGO_UID:$MONGO_GID /apps

# 5.	(as root) Create folders /logs/mongo/, give 740 permissions, set owner mongo:staff

[ -e /logs/mongo ] && rm -r /logs/mongo

mkdir --parents /logs/mongo
chmod 740 /logs/mongo
chown $MONGO_UID:$MONGO_GID /logs/mongo

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

# because of wget can't overwrite existing files, we need to specify filename with -O
LINUX_TAR_FILENAME="mongodb-linux-x86_64-3.6.5.tgz"
DOWNLOAD_DIR="/tmp"
echo "Downloading file '$LINUX_TAR_FILENAME'..."
sudo -u "$MONGO_LOGIN" wget --quiet https://fastdl.mongodb.org/linux/"$LINUX_TAR_FILENAME" -O "$DOWNLOAD_DIR/$LINUX_TAR_FILENAME"
if [ $? -eq 0 ] 
then
	echo "'$LINUX_TAR_FILENAME' has been downloaded"
else
	echo "some errors occurs while downloading with wget"
fi


# 7.	(as mongo) Download with curl https://fastdl.mongodb.org/src/mongodb-src-r3.6.5.tar.gz
SRC_TAR_FILENAME="mongodb-src-r3.6.5.tar.gz"
echo "Downloading file '$SRC_TAR_FILENAME'"
sudo -u "$MONGO_LOGIN" curl --silent -o "$DOWNLOAD_DIR/$SRC_TAR_FILENAME" https://fastdl.mongodb.org/src/"$SRC_TAR_FILENAME"
if [ $? -eq 0 ]
then
	echo "'$SRC_TAR_FILENAME' has been downloaded"
else
	echo "some errors occurs while downloading with curl"
fi

# 8.	(as mongo) Unpack mongodb-linux-x86_64-3.6.5.tgz to /tmp/

extract_tar_silently "$MONGO_LOGIN" "$DOWNLOAD_DIR/$LINUX_TAR_FILENAME" "/tmp"

# i think i should extract 2nd archive too

extract_tar_silently "$MONGO_LOGIN" "$DOWNLOAD_DIR/$SRC_TAR_FILENAME" "/tmp"

LINUX_FILENAME=${LINUX_TAR_FILENAME%%.tgz}
SRC_FILENAME=${SRC_TAR_FILENAME%%.tar.gz}

# 9.	(as mongo) Copy ./mongodb-linux-x86_64-3.6.5/* to /apps/mongo/

echo "Copying '/tmp/$LINUX_FILENAME/' to /apps/mongo"
sudo -u "$MONGO_LOGIN" cp -RT "/tmp/$LINUX_FILENAME/" /apps/mongo
if [ $? -eq 0 ]
then
	echo "'/tmp/$LINUX_FILENAME/*' has been copied"
else
	echo "some errors occurs while copying"
fi

# 10.	(as mongo) Update PATH on runtime by setting it to PATH=<mongodb-install-directory>/bin:$PATH

# 	WTFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
export PATH="/apps/mongo/bin${PATH:+:${PATH}}"

# 11.	(as mongo) Update PATH in .bash_profile and .bashrc with the same

# get mongo home directory because sudo will overwrite it with root home dir
MONGO_HOME=$( awk -v regex="^$MONGO_LOGIN$" -F: '$1 ~ regex { print $6 }' /etc/passwd )
# MONGO_HOME=$( sudo --user mongo env | awk -F= '$1 ~ /^HOME$/ { print $2 }' )

# MONGODB_INSTALL_PATH="/apps/mongo"
sudo -u "$MONGO_LOGIN" echo -e "# Path to mongo according to the task\nexport PATH="apps/mongo/bin${PATH:+:${PATH}}"\n" >> "$MONGO_HOME"/.bashprofile
sudo -u "$MONGO_LOGIN" echo -e "# Path to mongo according to the task\nexport PATH="apps/mongo/bin${PATH:+:${PATH}}"\n" >> "$MONGO_HOME"/.bashrc

# 12.	(as root) Setup number of allowed processes for mongo user: soft and hard = 32000

LIMITS_PATH="/etc/security/limits.conf"
sed -i '/End of file/d' "$LIMITS_PATH"
# delete all records about $MONGO_LOGIN
sed -i "/$MONGO_LOGIN/d" "$LIMITS_PATH"
echo "$MONGO_LOGIN\tsoft\tproc\t32000" >> "$LIMITS_PATH"
echo "$MONGO_LOGIN\thard\tproc\t32000" >> "$LIMITS_PATH"
echo "# End of file" >> "$LIMITS_PATH"

# 13.	(as root) Give sudo rights for Name_Surname to run only mongod as mongo user

echo -e "$NAME_SURNAME_LOGIN\tALL=(ALL)\tNOPASSWD:/apps/mongo/bin/mongod" >> /etc/sudoers.d/$NAME_SURNAME_LOGIN

# 14.	(as root) Create mongo.conf from sample config file from archive 7.

# because of cp='cp -i' alias in .bashrc
\cp /tmp/$SRC_FILENAME/rpm/mongod.conf /etc/

# 15.	(as root) Replace systemLog.path and storage.dbPath with /logs/mongo/ and /apps/mongodb/ accordingly in mongo.conf using sed or AWK

sed -i "s,\(^[[:blank:]]*path: \).*,\\1/logs/mongo/mongod.log," /etc/mongod.conf
sed -i "s,\(^[[:blank:]]*dbPath: \).*,\\1/apps/mongo," /etc/mongod.conf
sed -i "s,\(^[[:blank:]]*pidFilePath: \).*\( \#.*\),\\1/apps/mongo/mongod.pid\\2," /etc/mongod.conf

exit

# 16.	(as root) Create SystemD unit file called mongo.service. Unit file requirenments:
# 	a.	Pre-Start: Check if file /apps/mongo/bin/mongod and folders (/apps/mongodb/ and /logs/mongo/) exist, check if permissions and ownership are set correctly.


systemctl daemon-reload

# 17.	(as root) Add mongo.service to autostart

systemctl enable mongo.service

# Check
# 1.	Run mongod from Name_Surname
# 2.	Prove that process is running
# 	a.	PID exists
# 	b.	Corresponding [init and listen] message in mongo log 
# 	c.	Port is really listening
# 3.	Stop the process
# 4.	Verify that systemd unit is working (start, status, stop, status).



