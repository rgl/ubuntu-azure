#!/bin/bash
set -euxo pipefail

# clean the ssh host keys.
rm -f /etc/ssh/ssh_host_*_key*

# clean packages.
apt-get -y autoremove --purge
apt-get -y clean

# reset cloud-init.
cloud-init clean --logs --seed

# generalize.
# see https://learn.microsoft.com/en-us/azure/virtual-machines/linux/disable-provisioning#deprovision-and-create-an-image
# see https://developer.hashicorp.com/packer/integrations/hashicorp/azure/latest/components/builder/arm#deprovision
# see UbuntuDeprovisionHandler at https://github.com/Azure/WALinuxAgent/blob/v2.11.1.12/azurelinuxagent/pa/deprovision/ubuntu.py#L26
waagent -force -deprovision+user

# zero the free disk space -- for better compression of the image file.
# NB prefer discard/trim (safer; faster) over creating a big zero filled file
#    (somewhat unsafe as it has to fill the entire disk, which might trigger
#    a disk (near) full alarm; slower; slightly better compression).
if [ "$(lsblk -no DISC-GRAN $(findmnt -no SOURCE /) | awk '{print $1}')" != '0B' ]; then
    while true; do
        output="$(fstrim -v /)"
        cat <<<"$output"
        sync && sync && sleep 15
        bytes_trimmed="$(echo "$output" | perl -n -e '/\((\d+) bytes\)/ && print $1')"
        # NB if this never reaches zero, it might be because there is not
        #    enough free space for completing the trim.
        if (( bytes_trimmed < $((200*1024*1024)) )); then # < 200 MiB is good enough.
            break
        fi
    done
else
    dd if=/dev/zero of=/EMPTY bs=1M || true && sync && rm -f /EMPTY
fi
