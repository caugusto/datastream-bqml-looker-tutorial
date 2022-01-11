#!/bin/bash

help_me () {
#echo "Number of arguments= $1"

    echo ""
    echo "Error. Please check syntax/example below."
    echo ""
    echo "Example: $0 -p generic-demos -z us-central1-a -n default -s default -f Y -d Y"
    echo "where:"
    echo "-p = Google Cloud Project ID"
    echo "-z = Zone where the Oracle compute instance will be created"
    echo "-n = Network where VM and firewall entries will be created"
    echo "-s = Subnet within the network where VM and firewall entries will be created"
    echo "-f = Load FastFresh schema (Y or N)"
    echo "-d = Configure the Oracle database for Datastream usage (Y or N)"
    echo ""

    exit 2
}

check_last_command () {

if [ $? -eq 0 ]; then
    echo ""
else
    echo "Last command block failed. Exiting ..."
    exit 1
fi	
}

#echo "Number of arguments= $#"


while getopts p:z:n:s:f:d:h: flag
do
    case "${flag}" in
        p) PROJECT_ID=${OPTARG};;
        z) ZONE=${OPTARG};;
        n) NETWORK=${OPTARG};;
        s) SUBNET=${OPTARG};;
        f) FASTFRESH=${OPTARG};;
        d) DATASTREAM=${OPTARG};;
        w|*) help_me ;;        
    esac
done

IMAGE_FAMILY="debian-11"
GCE_INSTANCE_NAME="tutorial-orcl-vm"
NETWORK_TAG="tutorial-datastream"


echo ""

case ${PROJECT_ID} in
 "") PROJECT_ID=$(gcloud config get-value project 2>/dev/null); echo "Assuming project ${PROJECT_ID}. You can change with parameter -p" ;;
esac

case ${ZONE} in
 "") ZONE="us-central1-a"; echo "Assuming zone ${ZONE}. You can change with parameter -z" ;;
esac

case ${NETWORK} in
 "") NETWORK="default"; echo "Assuming network ${NETWORK}. You can change with parameter -n" ;;
esac

case ${SUBNET} in
 "") 
	 if [ ${NETWORK} != "default" ]; then
		 echo "Since -n parameter was passed, -s needs to be provided. Exiting ..."
		 help_me
	 else
	   SUBNET="default"; 
	   echo "Assuming subnet ${SUBNET}. You can change with parameter -s"

	fi
       ;;
esac

case ${FASTFRESH} in
 "") FASTFRESH="Y"; echo "Assuming FASTFRESH=Y. You can change with parameter -f" ;;
esac

case ${DATASTREAM} in
 "") DATASTREAM="Y"; echo "Assuming DATASTREAM=Y. You can change with parameter -d" ;;
esac


case ${PROJECT_ID} in
 "") echo ""; echo "PROJECT_ID parameter is required. Please use -p parameter"; help_me ;;
esac

case ${FASTFRESH} in
 Y|y) FF_BUILD="Y";; 
 N|n) FF_BUILD="N";;
 *) help_me;;
esac

case ${DATASTREAM} in
 Y|y) DS_BUILD="Y";; 
 N|n) DS_BUILD="N";;
 *) help_me;;
esac


echo ""
echo "Starting execution using the following parameters ..."
echo "PROJECT_ID = ${PROJECT_ID}"
echo "NETWORK = ${NETWORK}"
echo "ZONE = ${ZONE}"
echo "SUBNET = ${SUBNET}"
echo "FASTFRESH = ${FASTFRESH}"
echo "DATASTREAM = ${DATASTREAM}"
echo ""

echo "Cleaning up old runs ..."
gcloud compute instances delete ${GCE_INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID} --quiet
gcloud compute firewall-rules delete allow-ssh-tutorial-datastream  --project=${PROJECT_ID} --quiet
gcloud compute firewall-rules delete allow-orcl-tutorial-datastream  --project=${PROJECT_ID} --quiet

echo ""
echo "Creating the $GCE_INSTANCE_NAME VM ..."
gcloud compute instances create ${GCE_INSTANCE_NAME} --image-family=debian-11 --image-project=debian-cloud --zone=${ZONE} --project=${PROJECT_ID} --tags=${NETWORK_TAG} --network=${NETWORK} --subnet=${SUBNET}
check_last_command

echo ""
echo "Creating a firewall rule allowing SSH to $GCE_INSTANCE_NAME VM ..."
gcloud compute firewall-rules create "allow-ssh-tutorial-datastream" --allow=tcp:22 --source-ranges="0.0.0.0/0" --project=${PROJECT_ID} --target-tags=${NETWORK_TAG} --network=${NETWORK}
check_last_command

sleep 30

gcloud compute ssh ${GCE_INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID} --quiet << EOF
echo ""
echo "Installing OS dependencies" 
sudo apt-get update -y

sudo apt-get install \
    wget unzip apt-transport-https \
    ca-certificates curl gnupg \
    lsb-release -y

echo ""
echo "Installing the required Docker packages (https://docs.docker.com/engine/install/debian/)"
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

echo ""
echo "Creating Docker group and assigning the group to $USER"
sudo groupadd -f docker
sudo usermod -aG docker \$USER
newgrp docker

echo ""
echo "Pull and Run Image (https://hub.docker.com/r/wnameless/oracle-xe-11g-r2)"
docker pull wnameless/oracle-xe-11g-r2

echo ""
echo "Starting the Oracle Docker container with port 1521 being mapped to port 1521 on host"
docker run -d -p 0.0.0.0:1521:1521 -e ORACLE_ALLOW_REMOTE=true wnameless/oracle-xe-11g-r2
EOF
check_last_command

echo ""
echo "Creating a firewall rule allowing TCP connections to port 1521 on $GCE_INSTANCE_NAME VM ..."
gcloud compute firewall-rules create "allow-orcl-tutorial-datastream" --allow=tcp:1521 --source-ranges="0.0.0.0/0" --project=${PROJECT_ID} --target-tags=${NETWORK_TAG} --network=${NETWORK}
check_last_command
sleep 20



echo ""
echo "High Level DB checks"
gcloud compute ssh ${GCE_INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID} --quiet << 'EOF'
DOCKER_ID=`docker ps -a|grep wnameless|grep Up| awk '{print $1}'`
echo "DOCKER_ID=$DOCKER_ID"
docker exec -i -e USER=oracle -u oracle ${DOCKER_ID} bash << 'EOF2'
ps -ef|grep pmon
ps -ef|grep LISTENER
echo "USER=\$USER"
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE
lsnrctl status LISTENER

sqlplus / as sysdba << 'EOF3'
SET ECHO ON
SET FEEDBACK ON
SELECT INSTANCE_NAME, STATUS, DATABASE_STATUS FROM V$INSTANCE;
select log_mode from v$database;
alter user HR identified by tutorial_hr account unlock;
exit;
EOF3
EOF2
EOF
check_last_command


## Only load FASTFRESH schema if parameter -f = Y or = y
if [ "${FF_BUILD}" = "Y" -o "${FF_BUILD}" = "y" ]; then
gcloud compute scp --recurse ~/datastream-bqml-looker-tutorial ${GCE_INSTANCE_NAME}:~/ --zone=${ZONE} --project=${PROJECT_ID}
check_last_command

gcloud compute ssh ${GCE_INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID} --quiet << 'EOF'
DOCKER_ID=`docker ps -a|grep wnameless|grep Up| awk '{print $1}'`
echo "DOCKER_ID=$DOCKER_ID"

# Copy github files to docker
docker cp ~/datastream-bqml-looker-tutorial ${DOCKER_ID}:/u01/app/oracle

docker exec -i ${DOCKER_ID} bash << 'EOF1'
chown -R oracle:dba /u01/app/oracle/datastream-bqml-looker-tutorial 
EOF1

docker exec -i -e USER=oracle -u oracle ${DOCKER_ID} bash << 'EOF2'

echo "USER=$USER"
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE

# Create FASTFRESH SCHEMA and ORDERS TABLE
sqlplus / as sysdba << 'EOF3'
SET ECHO ON
SET FEEDBACK ON
CREATE USER "FASTFRESH" IDENTIFIED BY tutorial_fastfresh
      DEFAULT TABLESPACE "USERS"
      TEMPORARY TABLESPACE "TEMP";

GRANT "CONNECT" TO "FASTFRESH";
GRANT "RESOURCE" TO "FASTFRESH";
GRANT UNLIMITED TABLESPACE TO "FASTFRESH";
ALTER USER FASTFRESH DEFAULT TABLESPACE USERS;

CREATE TABLE FASTFRESH.ORDERS ( 
time_of_sale TIMESTAMP WITH TIME ZONE,  
order_id NUMBER(38),  
product_name VARCHAR2(128),  
price NUMBER(38, 20),  
quantity NUMBER(38),  
payment_method VARCHAR2(26),  
store_id NUMBER(38),  
user_id NUMBER(38)
)
TABLESPACE USERS
;
exit;
EOF3
EOF2
EOF
check_last_command
fi
################



## Only configure for Datastream if parameter -d = Y or = y
if [ "${DS_BUILD}" = "Y" -o "${DS_BUILD}" = "y" ]; then
echo ""
echo "Starting to configure for Datastream"
gcloud compute ssh ${GCE_INSTANCE_NAME} --zone=${ZONE} --project=${PROJECT_ID} --quiet << 'EOF'
DOCKER_ID=`docker ps -a|grep wnameless|grep Up| awk '{print $1}'`
echo "DOCKER_ID=$DOCKER_ID"
docker exec -i -e USER=oracle -u oracle ${DOCKER_ID} bash << 'EOF2'
echo "USER=\$USER"
export ORACLE_HOME=/u01/app/oracle/product/11.2.0/xe
export PATH=$ORACLE_HOME/bin:$PATH
export ORACLE_SID=XE

# Create datastream user
sqlplus / as sysdba << 'EOF3'
SET ECHO ON
SET FEEDBACK ON
create user datastream identified by tutorial_datastream;
GRANT EXECUTE_CATALOG_ROLE TO datastream;
GRANT CONNECT TO datastream;
GRANT CREATE SESSION TO datastream;
GRANT SELECT ON SYS.V_$DATABASE TO datastream;
GRANT SELECT ON SYS.V_$ARCHIVED_LOG TO datastream;
GRANT SELECT ON SYS.V_$LOGMNR_CONTENTS TO datastream;
GRANT SELECT ON SYS.V_$LOGMNR_LOGS TO datastream;
GRANT EXECUTE ON DBMS_LOGMNR TO datastream;
GRANT EXECUTE ON DBMS_LOGMNR_D TO datastream;
GRANT SELECT ANY TRANSACTION TO datastream;
GRANT SELECT ANY TABLE TO datastream;
exit;
EOF3

# Enable archivelog ... Required by Datastream
sqlplus / as sysdba << 'EOF3'
SET ECHO ON
SET FEEDBACK ON
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
ALTER DATABASE ADD SUPPLEMENTAL LOG DATA (all) COLUMNS;
ALTER SYSTEM SET ARCHIVE_LAG_TARGET = 60 scope=both;
exit;
EOF3

# Change RMAN retention to 4 days
rman target / << 'EOF3'
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 4 DAYS;
exit;
EOF3
EOF2
EOF
check_last_command
fi
########

DB_HOST=`gcloud compute instances list --filter="name=('${GCE_INSTANCE_NAME}')" --zones=${ZONE} --project=${PROJECT_ID} |grep EXTERNAL_IP|awk '{print $2}'`

echo ""
echo "Instance XE created successfully. Summary below:"
echo ""
echo "DB EXTERNAL IP: ${DB_HOST}"
echo "DB IP PORT: 1521"
echo "DB SID: XE"
echo "DB SYS/SYSTEM USER PASSWD: oracle "
echo "HR SCHEMA AUTHENTICATION: hr/tutorial_hr"
if [ "${DS_BUILD}" = "Y" -o "${DS_BUILD}" = "y" ]; then
    echo "DATASTREAM SCHEMA AUTHENTICATION: datastream/tutorial_datastream"
fi

if [ "${FF_BUILD}" = "Y" -o "${FF_BUILD}" = "y" ]; then
    echo "FASTFRESH SCHEMA AUTHENTICATION: fastfresh/tutorial_fastfresh"
fi
echo ""

echo "Script ended successfully"
echo ""
