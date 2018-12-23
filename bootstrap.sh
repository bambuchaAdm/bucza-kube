set -e

HOSTS="test"
USER="bambucha"

if [ ! -f "bucza-kube" ] 
then
  ssh-keygen -f "bucza-kube" -N ''
fi

if [ -f "./Fedora-Server-netinst-x86_64-29-1.2.iso" ]
then
  echo "Used cached image."
else
  echo "Downloading fedora image"
  curl -L https://download.fedoraproject.org/pub/fedora/linux/releases/29/Server/x86_64/iso/Fedora-Server-netinst-x86_64-29-1.2.iso -o Fedora-Server-netinst-x86_64-29-1.2.iso
  echo "Download done"
fi

for HOST in $HOSTS
do
  echo $HOST
  if ! virsh dominfo $HOST
  then

    qemu-img create -f qcow2 $HOST.qcow2 20G
    cat <<EOF > $HOST.ks
install
rootpw --plaintext fedora
auth --enableshadow --passalgo=sha512
keyboard --vckeymap=us --xlayouts='us'
lang en_US.UTF-8
timezone --isUtc Europe/London
network --device link --activate --hostname $HOST
user --name bambucha --groups wheel --iscrypted --password '$6$y1FZ64mvklbpOPID$Af4FIh8JRcInr7yxjBK6ILG6mNog3cUPY3YTJwcnE4rYDkS/DhpokWeosborNMOizvwC7tu9MhPrBkSbWHf93/'

# Wipe all disk
zerombr
bootloader
clearpart --all --initlabel
autopart --type=plain
shutdown

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

%post --log=/root/ks-post.log
set -e
mkdir /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
echo "$(cat bucza-kube.pub)" >> /home/$USER/.ssh/authorized_keys
chmod 600 /home/$USER/.ssh/authorized_keys
%end
EOF

    sudo virt-install \
      --name=$HOST \
      --ram 4096 \
      --vcpus 4 \
      --disk path=$HOST.qcow2 \
      --os-variant=fedora29 \
      --os-type=linux \
      --network network=bucza-kube \
      --graphics none \
      --console pty,target_type=serial \
      --location Fedora-Server-netinst-x86_64-29-1.2.iso \
      --extra-args "console=ttyS0,115200n8 serial ks=http://10.200.0.1:8000/$HOST.ks inst.text"
      --noreboot
  fi

done
