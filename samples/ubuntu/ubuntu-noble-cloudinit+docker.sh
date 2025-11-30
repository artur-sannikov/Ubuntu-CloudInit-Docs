#! /bin/bash
# See https://github.com/UntouchedWagons/Ubuntu-CloudInit-Docs/blob/main/samples/ubuntu/ubuntu-noble-cloudinit.sh
# Script runs regularly with cron. I set up VMID individually for each
# Proxmox machine
# VMID=8300
STORAGE=local-zfs
USER=artur
# Required for cron job
PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin"

set -x
rm -f noble-server-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qemu-img resize noble-server-cloudimg-amd64.img 8G
qm destroy $VMID
qm create $VMID --name "ubuntu-noble-docker-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket \
    --net0 virtio,bridge=vmbr0
qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=virtio0
qm set $VMID --scsi1 $STORAGE:cloudinit

cat <<EOF | tee /var/lib/vz/snippets/ubuntu-docker.yaml
#cloud-config
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent gnupg
    - apt-get install -y ca-certificates curl
    - apt-get install -y uidmap
    - install -m 0755 -d /etc/apt/keyrings
    - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    - chmod a+r /etc/apt/keyrings/docker.asc
    - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    - apt-get update
    - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

qm set $VMID --cicustom "vendor=local:snippets/ubuntu-docker.yaml"
qm set $VMID --tags ubuntu-template,noble,cloudinit
qm set $VMID --ciuser $USER

qm set $VMID --sshkeys ./servers-authorized-keys
qm set $VMID --ipconfig0 ip=dhcp
qm template $VMID
