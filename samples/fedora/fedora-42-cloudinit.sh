#!/bin/bash
VMID=8400
STORAGE=local-zfs
USER=artur
# Required for cron job
PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin"

set -x

rm Fedora-Cloud-Base-AmazonEC2-42-1.1.x86_64.raw.xz
rm Fedora-Cloud-Base-AmazonEC2-42-1.1.x86_64.raw
wget -q https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-AmazonEC2-42-1.1.x86_64.raw.xz
xz -d Fedora-Cloud-Base-AmazonEC2-42-1.1.x86_64.raw.xz

qm destroy $VMID
qm create $VMID --name "fedora-42-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket \
    --net0 virtio,bridge=vmbr0

qm importdisk $VMID Fedora-Cloud-Base-AmazonEC2-42-1.1.x86_64.raw $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=virtio0
qm set $VMID --scsi1 $STORAGE:cloudinit

cat <<EOF | tee /var/lib/vz/snippets/fedora-42.yaml
#cloud-config
runcmd:
    - dnf update 
    - dnf install qemu-guest-agent -y
    - systemctl enable sshd
    - reboot
EOF

qm set $VMID --cicustom "vendor=local:snippets/fedora-42.yaml"
qm set $VMID --tags fedora-template,cloudinit
qm set $VMID --ciuser $USER
qm set $VMID --sshkeys ~/.ssh/authorized_keys
qm set $VMID --ipconfig0 ip=dhcp
qm template $VMID
