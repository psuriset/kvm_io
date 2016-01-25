# System authorization information
auth --enableshadow --passalgo=sha512
# Use network installation
url --url="https://dl.fedoraproject.org/pub/fedora/linux/releases/22/Server/x86_64/os/"
# Use text mode install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'
# System language
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp --device=eth0 --ipv6=auto --activate
# Root password
rootpw --iscrypted <your password hash>
# Do not configure the X Window System
skipx
# System timezone
timezone US/Eastern --isUtc --ntpservers=<ntp server urls>
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
autopart --type=plain
# Partition clearing information
clearpart --all --initlabel --drives=vda

%packages
kernel-devel
%end
#network-tools
#systemtap
#@additional-devel
#@development
#@network-file-system-client
#@virtualization-client

%post
yum groupinstall -y "Development Tools" "RPM Development Tools" "Text-based Internet" "System Tools"
yum install -y kernel-debuginfo kernel-tools
yum update -y

yum install -y net-tools
yum install -y dnf-plugins-core
dnf copr enable -y ndokos/configtools
dnf copr enable -y ndokos/pbench
yum install -y pbench-agent
yum install -y pbench-fio

mkdir /root/.ssh
chmod 700 /root/.ssh
wget -O /root/.ssh/id_dsa.pub <URL to import your id_dsa.pub from>
wget -O /root/.ssh/id_dsa  <URL to import your id_dsa from>
wget -O /root/.ssh/authorized_keys <URL to import your authorized_keys from>
chmod 600 /root/.ssh/id_dsa /root/.ssh/id_dsa.pub /root/.ssh/authorized_keys
wget -O "/etc/systemd/system/serial-getty@ttyS1.service" "http://<URL>/serial-getty@ttyS1.service"
ln -s /etc/systemd/system/serial-getty@ttyS1.service /etc/systemd/system/getty.target.wants/
sed -i -e s/^HWADDR.*// /etc/sysconfig/network-scripts/ifcfg-eth0
/bin/rm -f /etc/hostname
%end

shutdown
