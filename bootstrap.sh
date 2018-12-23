set -e

if [-Z "./Fedora-Server-netinst-x86_64-29-1.2.iso" ] then
  echo "Downloading fedora image"
  curl -L https://download.fedoraproject.org/pub/fedora/linux/releases/29/Server/x86_64/iso/Fedora-Server-netinst-x86_64-29-1.2.iso -o Fedora-Server-netinst-x86_64-29-1.2.iso
  echo "Download done"
else
  echo "Used cached image. 
fi

for HOST in master1 node1 node2 node3
do
  echo $HOST
  qemu-img create -f qcow2 $HOST.qcow2 20G
  cat <<EOF > $HOST.ks
install
rootpw --plaintext fedora
auth --enableshadow --passalgo=sha512
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
timezone --isUtc Europe/London   
network --device link --activate --hostname $HOST

# Wipe all disk
zerombr
bootloader
clearpart --all --initlabel
autopart --type=plain

# Package source
# There's currently no way of using default online repos in a kickstart, see:
# https://bugzilla.redhat.com/show_bug.cgi?id=1333362
# https://bugzilla.redhat.com/show_bug.cgi?id=1333375
# So we default to fedora+updates and exclude updates-testing, which is the safer choice.
url --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-\$releasever&arch=\$basearch
repo --name=fedora
repo --name=updates
#repo --name=updates-testing

%packages
@^minimal-environment
%end
EOF

#sudo virt-install \
#  --name bucza-kube-m1 \
#  --ram 4096 \
#  --vcpus 4  \
#  --disk path=~/vms/bucza-kube/master1.qcow2 \
#  --os-variant=fedora29 \
#  --os-type=linux \
#  --network network=bucza-kube \
#  --graphics none 
#  --console pty,target_type=serial \
#  --location 'http://fedora.inode.at/releases/29/Server/x86_64/os/' \
#  --extra-args 'console=ttyS0,115200n8 serial inst.cmdline inst.sshd'
done
