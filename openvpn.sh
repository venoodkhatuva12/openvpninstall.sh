#!/bin/bash
#Script made for OpenVPN  installtion
#Author: Vinod.N K
#Usage: OpenVPN, OpenSSL, Gcc for portal installation
#Distro : Linux -Centos, Rhel, and any fedora
#Check whether root user is running the script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Bash guard to make sure we are running bash
if ! [ -n "$BASH_VERSION" ];then
    echo "This is not bash, calling self with bash....";
    SCRIPT=$(readlink -f "$0")
    /bin/bash $SCRIPT
    exit;
fi

clear
echo "
   ____           _    ___  ____     __    ____ 
  / ___|___ _ __ | |_ / _ \/ ___|   / /_  | ___|
 | |   / _ \ '_ \| __| | | \___ \  | '_ \ |___ \ 
 | |__|  __/ | | | |_| |_| |___) | | (_) | ___) |
  \____\___|_|_|_|\__|\___/|____/   \___(_)____/ 
     ___                __     __ ___  _   _ 
    / _ \ _ __   ___ ___\ \   / /  _ \| \ | |
   | | | | '_ \ / _ \  _ \ \ / /| |_) |  \| |
   | |_| | |_) |  __/ | | \ V / |  __/| |\  |
    \___/| .__/ \___|_| |_|\_/  |_|   |_| \_|
        ___           _        _ _
       |_ _|_ __  ___| |_ __ _| | | ___ _ __ 
        | || '_ \/ __| __/ _' | | |/ _ \ '__|
        | || | | \__ \ || (_| | | |  __/ |
       |___|_| |_|___/\__\__,_|_|_|\___|_|

   [ courtesy of www.programster.blogspot.com ]
"


# Ask the user where they want to store the client configs on their local machine.
# This will be used for updating the client.conf file with the relevant paths.
read -e -p "Path where you will store client configs (your local machine): 
" \
-i "/home/USER/my-vpn" CONFIG_FILE_PATH

# Include the epel repository that has openvpn. We may not have wget yet.
echo "Adding the EPEL repository"
yum install wget -y
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -Uvh epel-*
rm epel-release-6-8.noarch.rpm -f

# Update the OS
echo "Updating the system"
yum update -y

echo "Installing openvpn"
yum install openvpn easy-rsa openssl -y


mkdir -p /etc/openvpn/easy-rsa/keys

# resolving random issues with openssl 
# http://www.linuxquestions.org/questions/linux-software-2/issue-with-generating-certs-with-openssl-887207/
touch    /etc/openvpn/easy-rsa/keys/index.txt
echo '01
' > /etc/openvpn/easy-rsa//keys/serial

cp -rf /usr/share/easy-rsa/2.0/* /etc/openvpn/easy-rsa/

# Fix issue with openssl
sed -i 's;cnf="$1/openssl.cnf";cnf="$1/openssl-1.0.0.cnf";' /etc/openvpn/easy-rsa/whichopensslcnf

cd /etc/openvpn

# Clear out any keys that are already set. 
. /etc/openvpn/easy-rsa/clean-all


# Rather than execute the vars dir, lets just define them here:
export EASY_RSA="/etc/openvpn/easy-rsa/"
export OPENSSL="openssl"
export PKCS11TOOL="pkcs11-tool"
export GREP="grep"
export KEY_CONFIG=`$EASY_RSA/whichopensslcnf $EASY_RSA`
export KEY_DIR="$EASY_RSA/keys"
export PKCS11_MODULE_PATH="dummy"
export PKCS11_PIN="dummy"
export KEY_SIZE=1024
export CA_EXPIRE=3650
export KEY_EXPIRE=3650

# These are the fields which will be placed in the certificate.
# Don't leave any of these fields blank. Update if you want
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="Fort-Funston"
export KEY_EMAIL="noreply@getlost.com"
export KEY_CN=changeme
export KEY_NAME=changeme
export KEY_OU=changeme
export PKCS11_MODULE_PATH=changeme
export PKCS11_PIN=1234
. /etc/openvpn/easy-rsa/build-ca
. /etc/openvpn/easy-rsa/build-key-server server


# Create the client key. Change any of the settings below as you like
export KEY_COUNTRY="US"
export KEY_PROVINCE="TX"
export KEY_CITY="Austin"
export KEY_ORG="The Alamo"
export KEY_EMAIL="noreply@getlost2.com"
export KEY_CN=changeme
export KEY_NAME=keyname
export KEY_OU=noidea
export PKCS11_MODULE_PATH=changeme
export PKCS11_PIN=1234
. /etc/openvpn/easy-rsa/build-key client1

# generate Deffie Hellman Parameters which will be governing 
# the key exchanges between the client and the server of Ubuntu OpenVPN
. /etc/openvpn/easy-rsa/build-dh


# Copy the files you just generated to the directory that actually runs the openvpn service.
cp /etc/openvpn/easy-rsa/keys/* /etc/openvpn/.



# make a duplicate of the example config files which we will use.
cd /usr/share/doc/openvpn-2.3.6/sample/sample-config-files/
cp client.conf  /etc/openvpn/.
cp server.conf  /etc/openvpn/.

# now edit the files we just copied.
cd /etc/openvpn/


# Update the client.conf
SERVER_IP=`/sbin/ifconfig venet0:0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
sed -i "s;remote my-server-1 1194;remote $SERVER_IP 1194;" /etc/openvpn/client.conf
sed -i "s;ca ca.crt;ca $CONFIG_FILE_PATH/ca.crt;" /etc/openvpn/client.conf
sed -i "s;cert client.crt;cert $CONFIG_FILE_PATH/client1.crt;" /etc/openvpn/client.conf
sed -i "s;key client.key;key $CONFIG_FILE_PATH/client1.key;" /etc/openvpn/client.conf


# Update the server.conf by uncommenting the redirect of gateway
sed -i 's:;push "redirect-gateway def1 bypass-dhcp":push "redirect-gateway def1 bypass-dhcp":' \
/etc/openvpn/server.conf

# Update the dhcp-option to push google as the DNS
sed -i 's:;push "dhcp-option DNS 208.67.220.220":push "dhcp-option DNS 8.8.8.8":' /etc/openvpn/server.conf
sed -i 's:;push "dhcp-option DNS 208.67.220.220":push "dhcp-option DNS 10.8.0.1":' /etc/openvpn/server.conf


# Configuring system to allow ip forwarding
echo "configuring system to allow ip forwarding..."
# This is a version I have seen in the past
sed -i "s;#net.ipv4.ip_forward=1;net.ipv4.ip_forward=1;" /etc/sysctl.conf
# This is the latest way I have seen it disabled
sed -i "s;net.ipv4.ip_forward = 0;net.ipv4.ip_forward = 1;" /etc/sysctl.conf
echo 1 > /proc/sys/net/ipv4/ip_forward


# Set up iptables to forward packets for vpn and do this upon startup.
echo "configuring iptables to forward packets..."
echo 'iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -A FORWARD -j REJECT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o venet0 -j MASQUERADE
exit 0' > /etc/rc.local

# Call the startup script immediately so user does not have to reboot to get going.
sudo bash /etc/rc.local


# package up the files that the user needs to copy to their local machine
echo "packaging up files that you will need to send yourself..."
mkdir /etc/openvpn/vpn-details

cp /etc/openvpn/client.conf \
/etc/openvpn/ca.crt \
/etc/openvpn/client1.crt \
/etc/openvpn/client1.key \
/etc/openvpn/vpn-details/.

cd /etc/openvpn/
tar --create --gzip --file ~/vpn-details.tar.gz vpn-details


# clean up
echo "cleaning up..."
sudo rm -rf /etc/openvpn/vpn-details
sudo rm /etc/openvpn/client.conf
#
# These steps I did manually to get working
cd /etc/openvpn
sudo rm client*

# Restart the openvpn service
echo "restarting the openvpn service..."
service openvpn restart

# set openvpn to start on boot
chkconfig openvpn on


# Finish up by telling the user the one manual step they need to perform
echo "Copy the vpn-details.tar.gz file to your local machine (SCP) 
and then run this command in your cli:
openvpn --config /location/of/your/copied/files/client.conf"
