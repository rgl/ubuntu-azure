# About

This builds an Azure Ubuntu Image.

This is based on [Ubuntu 22.04 (Jammy Jellyfish)](https://wiki.ubuntu.com/JammyJellyfish/ReleaseNotes).

# Usage

Install Packer and the Azure CLI.

Login into azure:

```bash
az login
```

List the subscriptions:

```bash
az account list --all
az account show
```

Set the subscription:

```bash
export ARM_SUBSCRIPTION_ID="<YOUR-SUBSCRIPTION-ID>"
az account set --subscription "$ARM_SUBSCRIPTION_ID"
```

Set the secrets:

```bash
cat >secrets.sh <<EOF
export CHECKPOINT_DISABLE='1'
export ARM_SUBSCRIPTION_ID='$ARM_SUBSCRIPTION_ID'
export PKR_VAR_location='northeurope'
export PKR_VAR_resource_group_name='rgl-ubuntu'
export PKR_VAR_image_name='rgl-ubuntu'
export TF_VAR_location="\$PKR_VAR_location"
export TF_VAR_resource_group_name="\$PKR_VAR_resource_group_name"
export TF_VAR_image_name="\$PKR_VAR_image_name"
export TF_VAR_admin_ssh_key_data="\$(cat ~/.ssh/id_rsa.pub)"
export TF_LOG='TRACE'
export TF_LOG_PATH='terraform.log'
EOF
```

Create the resource group:

```bash
source secrets.sh
az group create \
    --name "$PKR_VAR_resource_group_name" \
    --location "$PKR_VAR_location"
```

Build the image:

```bash
source secrets.sh
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=ubuntu.init.log \
    packer init ubuntu.pkr.hcl
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=ubuntu.log \
    packer build -only=azure-arm.ubuntu -on-error=abort -timestamp-ui ubuntu.pkr.hcl
```

Create the example terraform environment that uses the created image:

```bash
pushd example
terraform init
terraform apply
```

At VM initialization time [cloud-init](https://cloudinit.readthedocs.io/en/latest/index.html) will run the `example/provision-app.sh` script to launch the example application.

After VM initialization is done (check the boot diagnostics serial log for cloud-init entries), test the `app` endpoint:

```bash
wget -qO- "http://$(terraform output --raw app_ip_address)/test"
```

And open a shell inside the VM:

```bash
ssh "rgl@$(terraform output --raw app_ip_address)"
id
df -h
sudo docker info
sudo docker ps
sudo docker run --rm hello-world
exit
```

Destroy the example terraform environment:

```bash
terraform destroy
popd
```

Destroy the remaining resources (e.g. the image):

```bash
az group delete --name "$PKR_VAR_resource_group_name"
```
