#!/bin/bash

function help() {
	echo -e "Usage: $0 [OPTION]"
	echo -e "\t-v. --verbose\tVerbose mode (detailed output)\n\t\t\t(by default there is no output at all)"
	echo -e "\t-h, --help\tPrint help and exit\n"
}


# parameter - username
# if user exists, then exit code = 0, otherwise not 0
function user_exists() {
#	id "$1" &> /dev/null 
	grep -q "^$1" /etc/passwd
}

# parameter - groupname
# if group exists, then exit code = 0, otherwise not 0
function group_exists() {
	grep -q "^$1" /etc/group
}

# parameter - username
function delete_user_if_exists() {
	if ( user_exists "$1" )
	then
		[ $DEBUG -eq 1 ] && echo -e "Deleting user "$1"..."
		who | grep -i -m 1 "$NAME_SURNAME_LOGIN"
		# if exit code == 0 then user is logged in
		pkill -KILL -u "$1"
		userdel --remove "$1" >& /dev/null	
	fi 
}

# parameters - groupname
# deletes group and it members
function delete_group_if_exists() {
	if ( group_exists "$1" )
	then
        	GROUPNAME=$1
        	GROUPGID=$( awk -F: -v regex="^$GROUPNAME$" '$1 ~ regex { print $3 }' /etc/group )
        	MEMBERS=$( awk -F: -v regex="^$GROUPGID$" '$4 ~ regex { print $1 }' /etc/passwd )
        	for MEMBER in ${MEMBERS[@]}
        	do
			delete_user_if_exists "$MEMBER"
                	#pkill -u "$MEMBER"
                	#userdel --remove "$MEMBER"
        	done
        	groupdel $GROUPNAME
	fi
}

# parameters: groupname gid
# NOT USED BUT I AM TOO SILLY TO DELETE IT
function create_or_change_group() {
	if ( group_exists "$1" ) 
	then
		[ $DEBUG -eq 1 ] && echo -e "Group '$1' exists. Editing its gid..."
		# change gid or delete???
		groupmod -g "$2" $1
	else
		groupadd --gid $2 "$1"
	fi
}

# parameters: login src_path dest_path
function extract_tar_as_user() {
	[ $DEBUG -eq 1 ] && echo "Extracting '$2' to $3"
	sudo -u "$1" tar -xzf "$2" -C "$3"
	if [ $? -eq 0 ]
	then
		[ $DEBUG -eq 1 ] && echo "'$2' has been extracted to '$3'"
	else
		[ $DEBUG -eq 1 ] && echo "some errors occurs while extracting '$2' to '$3'"
	fi
}

DEBUG=0
# parse parameters
while [[ $# -gt 0 ]]
do
        param=$1
        case $param in
                -v|--verbose)
                        DEBUG=1
                        shift
                        ;;
                -h|--help|*)
                        help
                        exit 0
                        ;;
        esac
done


# You are to develop a bash script provision.sh that being invoked as root performs the following:

# 1.	(as root) Create user Name_Surname with primary group, UID = 505, GID=505

NAME_SURNAME_LOGIN="Uladzislau_Petravets"
NAME_SURNAME_GID=505
NAME_SURNAME_UID=505

delete_user_if_exists "$NAME_SURNAME_LOGIN"

delete_group_if_exists "$NAME_SURNAME_LOGIN"

groupadd --gid $NAME_SURNAME_GID "$NAME_SURNAME_LOGIN"
adduser --gid $NAME_SURNAME_GID --uid $NAME_SURNAME_UID "$NAME_SURNAME_LOGIN"

# 2.	(as root) Create user mongo with primary group staff, UID=600, GID=600

MONGO_LOGIN="mongo"
MONGO_GROUPNAME="staff"
MONGO_UID=600
MONGO_GID=600

delete_user_if_exists "$MONGO_LOGIN"

delete_group_if_exists "$MONGO_GROUPNAME"

groupadd --gid $MONGO_GID "$MONGO_GROUPNAME"
adduser --gid $MONGO_GID --uid $MONGO_UID "$MONGO_LOGIN"

# 3.	(as root) Create folders /apps/mongo/, give 750 permissions, set owner mongo:staff

[ -e /apps/mongo ] && rm -r -f /apps/mongo && [ $DEBUG -eq 1 ] && echo -e "Removing /apps/mongo..."

mkdir --parents /apps/mongo
chmod 750 /apps/mongo
chown $MONGO_UID:$MONGO_GID /apps/mongo

# 4.	(as root) Create folders /apps/mongodb/, give 750 permissions, set owner mongo:staff

[ -e /apps/mongodb ] && rm -r /apps/mongodb && [ $DEBUG -eq 1 ] && echo -e "Removing /apps/mongodb..."

mkdir /apps/mongodb
chmod 750 /apps/mongodb
chown $MONGO_UID:$MONGO_GID /apps/mongodb

# idk should i set perms and ownership on /apps & /logs dirs, so i leave it here
# chmod --recursive 750 /apps
# chown --recursive $MONGO_UID:$MONGO_GID /apps

# 5.	(as root) Create folders /logs/mongo/, give 740 permissions, set owner mongo:staff

[ -e /logs/mongo ] && rm -r -f /logs/mongo && [ $DEBUG -eq 1 ] && echo -e "Removing /logs/mongo..."

mkdir --parents /logs/mongo
chmod 740 /logs/mongo
chown $MONGO_UID:$MONGO_GID /logs/mongo

# 6.	(as mongo) Download with wget https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-3.6.5.tgz

# check if wget is installed
rpm -aq | grep -q wget
if [ $? -ne 0 ]
then
	[ $DEBUG -eq 1 ] && echo "Installing wget..."
	# install wget
	# should i keep errors?
	yum install --quiet --assumeyes wget
	[ $DEBUG -eq 1 ] && echo "Wget has been installed."
fi

# because of wget can't overwrite existing files, we need to specify filename with -O
LINUX_TAR_FILENAME="mongodb-linux-x86_64-3.6.5.tgz"
DOWNLOAD_DIR="/tmp"
[ $DEBUG -eq 1 ] && echo "Downloading file '$LINUX_TAR_FILENAME'..."
sudo -u "$MONGO_LOGIN" wget --quiet https://fastdl.mongodb.org/linux/"$LINUX_TAR_FILENAME" -O "$DOWNLOAD_DIR/$LINUX_TAR_FILENAME"
if [ $? -eq 0 ] 
then
	[ $DEBUG -eq 1 ] && echo "'$LINUX_TAR_FILENAME' has been downloaded"
else
	[ $DEBUG -eq 1 ] && echo "Some errors occurs while downloading with wget"
fi

# 7.	(as mongo) Download with curl https://fastdl.mongodb.org/src/mongodb-src-r3.6.5.tar.gz
SRC_TAR_FILENAME="mongodb-src-r3.6.5.tar.gz"
[ $DEBUG -eq 1 ] && echo "Downloading file '$SRC_TAR_FILENAME'"
sudo -u "$MONGO_LOGIN" curl --silent -o "$DOWNLOAD_DIR/$SRC_TAR_FILENAME" https://fastdl.mongodb.org/src/"$SRC_TAR_FILENAME"
if [ $? -eq 0 ]
then
	[ $DEBUG -eq 1 ] && echo "'$SRC_TAR_FILENAME' has been downloaded"
else
	[ $DEBUG -eq 1 ] && echo "Some errors occurs while downloading with curl"
fi

# 8.	(as mongo) Unpack mongodb-linux-x86_64-3.6.5.tgz to /tmp/

extract_tar_as_user "$MONGO_LOGIN" "$DOWNLOAD_DIR/$LINUX_TAR_FILENAME" "/tmp"

# i think i should extract 2nd archive too

extract_tar_as_user "$MONGO_LOGIN" "$DOWNLOAD_DIR/$SRC_TAR_FILENAME" "/tmp"

LINUX_FILENAME=${LINUX_TAR_FILENAME%%.tgz}
SRC_FILENAME=${SRC_TAR_FILENAME%%.tar.gz}

# 9.	(as mongo) Copy ./mongodb-linux-x86_64-3.6.5/* to /apps/mongo/

[ $DEBUG -eq 1 ] && echo "Copying '/tmp/$LINUX_FILENAME/' to /apps/mongo"
sudo -u "$MONGO_LOGIN" cp -RT "/tmp/$LINUX_FILENAME/" /apps/mongo
if [ $? -eq 0 ]
then
	[ $DEBUG -eq 1 ] && echo "'/tmp/$LINUX_FILENAME/*' has been copied to '/apps/mongo'"
else
	[ $DEBUG -eq 1 ] && echo "Some errors occurs while copying '/tmp/$LINUX_FILENAME'"
fi

# 10.	(as mongo) Update PATH on runtime by setting it to PATH=<mongodb-install-directory>/bin:$PATH

sudo -u "$MONGO_LOGIN" bash -c "export PATH=\"/apps/mongo/bin${PATH:+:${PATH}}\""

# 11.	(as mongo) Update PATH in .bash_profile and .bashrc with the same

# get mongo home directory because sudo will overwrite it with root home dir
MONGO_HOME=$( awk -v regex="^$MONGO_LOGIN$" -F: '$1 ~ regex { print $6 }' /etc/passwd )

# MONGODB_INSTALL_PATH="/apps/mongo"
[ $DEBUG -eq 1 ] && echo -e "Editing '$MONGO_HOME/.bashrc' and '$MONGO_HOME/.bash_profile'..."
sudo -u "$MONGO_LOGIN" echo -e "# Path to mongo according to the task\nexport PATH=\"/apps/mongo/bin${PATH:+:${PATH}}\"\n" >> "$MONGO_HOME"/.bash_profile
sudo -u "$MONGO_LOGIN" echo -e "# Path to mongo according to the task\nexport PATH=\"/apps/mongo/bin${PATH:+:${PATH}}\"\n" >> "$MONGO_HOME"/.bashrc

# 12.	(as root) Setup number of allowed processes for mongo user: soft and hard = 32000

LIMITS_PATH="/etc/security/limits.conf"
[ $DEBUG -eq 1 ] && echo -e "Editing '$LIMITS_PATH'..."
sed -i '/End of file/d' "$LIMITS_PATH"
# delete all records about $MONGO_LOGIN
sed -i "/$MONGO_LOGIN/d" "$LIMITS_PATH"
echo -e "$MONGO_LOGIN\tsoft\tproc\t32000" >> "$LIMITS_PATH"
echo -e "$MONGO_LOGIN\thard\tproc\t32000" >> "$LIMITS_PATH"
echo -e "# End of file" >> "$LIMITS_PATH"

# 13.	(as root) Give sudo rights for Name_Surname to run only mongod as mongo user

[ $DEBUG -eq 1 ] && echo -e "Making $NAME_SURNAME_LOGIN great again..."
echo -e "$NAME_SURNAME_LOGIN\tALL=(mongo)\tNOPASSWD:/apps/mongo/bin/mongod" > /etc/sudoers.d/$NAME_SURNAME_LOGIN
echo -e "alias mongod='sudo -u $MONGO_LOGIN /apps/mongo/bin/mongod -f /etc/mongod.conf'" >> "/home/$NAME_SURNAME_LOGIN/.bashrc"

# 14.	(as root) Create mongo.conf from sample config file from archive 7.

[ $DEBUG -eq 1 ] && echo -e "Creating '/etc/mongod.conf' file..."
# because of cp='cp -i' alias in .bashrc
\cp /tmp/$SRC_FILENAME/rpm/mongod.conf /etc/

# 15.	(as root) Replace systemLog.path and storage.dbPath with /logs/mongo/ and /apps/mongodb/ accordingly in mongo.conf using sed or AWK

sed -i "s,\(^[[:blank:]]*path: \).*,\\1/logs/mongo/mongod.log," /etc/mongod.conf
sed -i "s,\(^[[:blank:]]*dbPath: \).*,\\1/apps/mongo," /etc/mongod.conf
sed -i "s,\(^[[:blank:]]*pidFilePath: \).*\( \#.*\),\\1/apps/mongo/mongod.pid\\2," /etc/mongod.conf

# 16.	(as root) Create SystemD unit file called mongo.service. Unit file requirenments:
# 	a.	Pre-Start: Check if file /apps/mongo/bin/mongod and folders (/apps/mongodb/ and /logs/mongo/) exist, check if permissions and ownership are set correctly.

[ $DEBUG -eq 1 ] && echo -e "Creating 'mongo.service' unit file..."
cat << EOT > /etc/systemd/system/mongo.service
[Unit]
Description=High-perfomance hehe boi database
Wants=network.target
After=network.target

[Service]
Type=forking
PIDFile=/apps/mongo/mongod.pid
ExecStartPre=/usr/bin/test -d /apps/mongo
ExecStartPre=/usr/bin/test -d /apps/mongodb
ExecStartPre=/usr/bin/test -d /logs/mongo
ExecStartPre=/usr/bin/test "\$( stat -c "%u %g %a" /apps/mongo )" = "$MONGO_UID $MONGO_GID 750"
ExecStartPre=/usr/bin/test "\$( stat -c "%u %g %a" /apps/mongodb )" = "$MONGO_UID $MONGO_GID 750"
ExecStartPre=/usr/bin/test "\$( stat -c "%u %g %a" /logs/mongo )" = "$MONGO_UID $MONGO_GID 740"
ExecStartPre=/usr/bin/test -f /apps/mongo/bin/mongod
ExecStart=/apps/mongo/bin/mongod --config /etc/mongod.conf
ExecReload=/bin/kill -HUP \$MAINPID
User=mongo
Group=staff
# file size
LimitFSIZE=infinity
# cpu time
LimitCPU=infinity
# virtual memory size
LimitAS=infinity
# open files
LimitNOFILE=64000
# locked memory
LimitMEMLOCK=infinity
# total threads (user+kernel)
TasksMax=infinity
TasksAccounting=false

[Install]
WantedBy=multi-user.target

EOT

systemctl daemon-reload

# 17.	(as root) Add mongo.service to autostart

[ $DEBUG -eq 1 ] && echo -e "Adding 'mongo.service' to autostart..."
systemctl enable mongo.service

[ $DEBUG -eq 1 ] && echo -e "Ok it seems to be done i hope i didn't write all these echo's in vain"
# Check
# 1.	Run mongod from Name_Surname
# 2.	Prove that process is running
# 	a.	PID exists
# 	b.	Corresponding [init and listen] message in mongo log 
# 	c.	Port is really listening
# 3.	Stop the process
# 4.	Verify that systemd unit is working (start, status, stop, status).

