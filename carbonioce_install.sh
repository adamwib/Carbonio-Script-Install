#!/bin/bash 

# Based on the origian work published on Carbonio's Official docs available at
# https://docs.zextras.com/carbonio-ce/html/install/scenarios/single-server-scenario.html

# modified by
# Anahuac Gil (anahuac@kyasolutions.com.br) 2024-03
# Mateus Batista AKA madruga (madruga@gnu.works) 2024-04

version=v9

# Define ANSI color codes for colored output
RED='\033[0;31m'	# Failed - Red
GREEN='\033[0;32m'	# Done - Green
YELLOW='\033[0;33m'	# Pending - Yellow
LIGHT_GRAY='\033[0;37m'	# Next - Light Gray (off-white)
NC='\033[0m'		# No Color - Reset

#PRE-INSTALL STEPS

source /etc/os-release

# Hostname
read -p "Please enter server hostname: " c_hostname
if [ -z $c_hostname ] ; then echo "hostname can't be empty!" ; exit 1 ; fi
hostnamectl set-hostname $c_hostname

# Hostname
read -p "Please enter main domain to be used: " c_domain
if [ -z $c_domain ] ; then echo "domain can't be empty!" ; exit 1 ; fi

# IP address and /etc/hosts
read -p "Please enter server IP Address: " c_address
if [ -z $c_address ] ; then echo "IP Address can't be empty!" ; exit 1 ; fi
echo "127.0.0.1 localhost" > /etc/hosts
echo "$c_address $(hostname -f) $(hostname -s)" >> /etc/hosts

# Consul password
read -p "Please enter Carbonio Mesh password to be used: " c_consul_password
if [ -z $c_consul_password ] ; then echo "Carbonio Mesh password can't be empty!" ; exit 1 ; fi

# PostgreSQL  password
read -p "Please enter PostgreSQL admin password to be used: " c_postgres_password
if [ -z $c_postgres_password ] ; then echo "PostgreSQL admin password can't be empty!" ; exit 1 ; fi

# Carbonio admin password
read -p "Please enter Carbonio admin (zextras) password to be used: " c_admin_password
if [ -z $c_admin_password ] ; then echo "Carbonio admin password can't be empty!" ; exit 1 ; fi

# systemd-resolved
sed -i s/"#DNS="/"DNS=8.8.8.8"/g /etc/systemd/resolved.conf

# IPV6
echo "Disabling IPV6..."
ipv6_test=$(grep net.ipv6.conf.all.disable_ipv6 /etc/sysctl.conf)
if [ -z "$ipv6_test" ] ; then
	echo "" >> /etc/sysctl.conf
	echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
	echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
	sysctl -p > /dev/null
fi
if [ ! -f /etc/rc.local ] ; then 
	>/etc/rc.local
	echo "#! /bin/bash" >> /etc/rc.local
	chmod +x /etc/rc.local
fi
echo "sysctl -p" >> /etc/rc.local

apt install -y binutils

HOST=$c_hostname;
DOMAIN=$c_domain;
IP=$c_address;
virus_account=$(echo "virus-quarantine.$(strings /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c10)@$c_domain")
spam_account=$(echo "spam.$(strings /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c10)@$c_domain")
ham_account=$(echo "ham.$(strings /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c10)@$c_domain")


printf "Carbonio will be installed on $YELLOW${HOST}$NC, using $YELLOW${DOMAIN}$NC as default domain and $YELLOW${IP}$NC as public IP\n"
read -p "Ready to go? (press Enter to continue...)" c_continue

# Repository
wget -c  https://repo.zextras.io/inst_repo_ubuntu.sh && bash inst_repo_ubuntu.sh
echo "Public Zextras repository added for Ubuntu 22.04LTS (Jammy)..."

apt update -y

#INSTALL STEPS

package_name="carbonio-core"

if apt-cache search "$package_name" | grep -q "$package_name"; then
    echo "Start Carbonio installation"
#echo "deb http://apt.postgresql.org/pub/repos/apt focal-pgdg main" > /etc/apt/sources.list.d/pgdg.list;
#wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - ;

sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

wget -O- "https://www.postgresql.org/media/keys/ACCC4CF8.asc" | gpg --dearmor | sudo tee /usr/share/keyrings/postgres.gpg > /dev/null
chmod 644 /usr/share/keyrings/postgres.gpg
sed -i 's/deb/deb [signed-by=\/usr\/share\/keyrings\/postgres.gpg] /' /etc/apt/sources.list.d/pgdg.list

PACKAGES="postgresql-16 service-discover-server carbonio-directory-server carbonio-proxy carbonio-webui carbonio-files-ui carbonio-mta carbonio-mailbox-db carbonio-appserver carbonio-user-management carbonio-files-ce carbonio-files-public-folder-ui carbonio-files-db carbonio-tasks-ce carbonio-tasks-db carbonio-tasks-ui carbonio-storages-ce carbonio-preview-ce carbonio-docs-connector-ce carbonio-docs-connector-db carbonio-docs-editor carbonio-prometheus carbonio-message-broker  carbonio-ws-collaboration-ce carbonio-ws-collaboration-db carbonio-ws-collaboration-ui"

echo "
HOSTNAME="$c_hostname"
AVDOMAIN="$c_domain"
AVUSER="zextras@$c_domain"
CREATEADMIN="zextras@$c_domain"
CREATEDOMAIN="$c_domain"
DOCREATEADMIN="yes"
DOCREATEDOMAIN="yes"
LDAPHOST="$c_hostname"
SMTPDEST="zextras@$c_domain"
SMTPHOST="$c_hostname"
SMTPSOURCE="zextras@$c_domain"
SNMPTRAPHOST="$c_hostname"
SPELLURL="http://$c_hostname:7780/aspell.php"
VIRUSQUARANTINE="$virus_account"
TRAINSAHAM="$spam_account"
TRAINSASPAM="$ham_account"
zimbraDefaultDomainName="$c_domain"
zimbraVersionCheckNotificationEmail="zextras@$c_domain"
zimbraVersionCheckNotificationEmailFrom="zextras@$c_domain"
zimbra_server_hostname="$c_hostname"
" > config.conf
apt update -y -q
apt upgrade -y -q
apt install -y $PACKAGES 

carbonio-bootstrap -c ./config.conf

CONSUL_SECRET="$c_consul_password"
POSTGRES_SECRET="$c_postgres_password"

service-discover setup $c_address --password=$CONSUL_SECRET 

export CONSUL_HTTP_TOKEN=$(echo $CONSUL_SECRET | gpg --batch --yes --passphrase-fd 0 -qdo - /etc/zextras/service-discover/cluster-credentials.tar.gpg | tar xOf - consul-acl-secret.json | jq .SecretID -r);
export SETUP_CONSUL_TOKEN=$CONSUL_HTTP_TOKEN

pending-setups --execute-all

su - postgres -c "psql --command=\"CREATE ROLE carbonio_adm WITH LOGIN SUPERUSER encrypted password '$POSTGRES_SECRET';\""
su - postgres -c "psql --command=\"CREATE DATABASE carbonio_adm OWNER carbonio_adm;\""

PGPASSWORD=$POSTGRES_SECRET carbonio-files-db-bootstrap carbonio_adm 127.0.0.1
PGPASSWORD=$POSTGRES_SECRET carbonio-mailbox-db-bootstrap carbonio_adm 127.0.0.1
PGPASSWORD=$POSTGRES_SECRET carbonio-docs-connector-db-bootstrap carbonio_adm 127.0.0.1
PGPASSWORD=$POSTGRES_SECRET carbonio-tasks-db-bootstrap carbonio_adm 127.0.0.1
PGPASSWORD=$POSTGRES_SECRET carbonio-ws-collaboration-db-bootstrap carbonio_adm 127.0.0.1

PACKAGES="carbonio-message-dispatcher-db"
apt install -y $PACKAGES
pending-setups --execute-all
PGPASSWORD=$POSTGRES_SECRET carbonio-message-dispatcher-db-bootstrap carbonio_adm 127.0.0.1

PACKAGES="carbonio-message-dispatcher"
apt install -y $PACKAGES
pending-setups --execute-all
PGPASSWORD=$POSTGRES_SECRET carbonio-message-dispatcher-migration carbonio_adm 127.0.0.1

PACKAGES="carbonio-videoserver-ce"
DEBIAN_FRONTEND=noninteractive apt install -y $PACKAGES
sed -i '/nat_1_1_mapping/c\        nat_1_1_mapping = "'$c_address'"' /etc/janus/janus.jcfg
pending-setups --execute-all

sudo -iu zextras -- bash <<EOF
	carbonio prov mcf zimbraDefaultDomainName $DOMAIN
	carbonio prov md  $DOMAIN zimbraVirtualHostname $DOMAIN
	carbonio prov mc default carbonioFeatureChatsEnabled TRUE
	carbonio prov setpassword zextras@$DOMAIN $c_admin_password
EOF

systemctl restart carbonio-tasks && systemctl restart carbonio-ws-collaboration && systemctl restart carbonio-message-dispatcher && systemctl restart carbonio-videoserver

reset

#echo service discover and postgresql passwords
echo -e "The service-discover password is: \e[1m $CONSUL_SECRET \e[0m" 
echo -e "You can find it in file \e[3m/var/lib/service-discover/password\e[0m."
echo ""
echo -e "The PostgreSQL password (DB_ADM_PWD) is: \e[1m$POSTGRES_SECRET\e[0m"
echo "Please store it in a safe place, otherwise you will need to reset it!"
echo ""
echo -e "The zextras@$DOMAIN password is: \e[1m$c_admin_password\e[0m"
echo "Please store it in a safe place, otherwise you will need to reset it!"

else
    echo "###### Carbonio repo are not configured. ######"
fi
