#!/bin/bash
# what's needed before you start:
# 1) linux shell with generated ssh keys
# 2) have your subscription enabled to use availability zone for D and E series VMs in your chosen region (pick a region with zones, duh)
# 3) az cli installed in your linux shell (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-yum?view=azure-cli-latest)       
#    you can also use Azure CloudShell for this step (https://azure.microsoft.com/en-us/features/cloud-shell)
# 4) you should have filled parameters.txt file as well, correctly and in correct lower/upper case for all parameters

source $(dirname $0)/parameters.txt
LOGFILE=$(dirname $0)/1_create_jumpbox.log
starttime=`date +%s`

az account set --subscription $AZSUB
RGNAME=RG-${AZLOCTLA}-${RESOURCEGROUP}
printf '%s\n'
echo Creating resource group $RGNAME in $AZLOC
az group create --location $AZLOC --name $RGNAME --tags Deployment=SAP Importance=Sandbox >$LOGFILE 2>&1

# create VNET and subnets
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-hub
printf '%s\n'
echo "###-------------------------------------###"
echo Creating Vnet $VNETNAME
az network vnet create --name $VNETNAME --address-prefixes $HUBIP --subnet-name ${VNETNAME}-ssh --subnet-prefixes ${HUBIP} --location $AZLOC --resource-group $RGNAME >>$LOGFILE 2>&1       
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-sap
APPLSUBNET=`echo ${SAPIP}| awk -F / '{print $1}'`
echo "###-------------------------------------###"
echo Creating Vnet $VNETNAME
az network vnet create --name $VNETNAME --address-prefixes $SAPIP --subnet-name ${VNETNAME}-appl --subnet-prefixes ${APPLSUBNET}/25 --location $AZLOC --resource-group $RGNAME >>$LOGFILE 2>&1   
DBSUBNET=`echo $SAPIP|sed 's/.\{5\}$//'`
az network vnet subnet create --name ${VNETNAME}-db --resource-group $RGNAME --vnet-name $VNETNAME --address-prefixes ${DBSUBNET}.128/26 >>$LOGFILE 2>&1   
printf '%s\n'
echo "###-------------------------------------###"
echo Here is the Vnet information
az network vnet list --resource-group $RGNAME --output table
az network vnet subnet list --resource-group $RGNAME --vnet-name $VNETNAME --output table

# create NSGs for subnets
printf '%s\n'
echo "###-------------------------------------###"
echo Creating NSGs for SAP subnets
SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
az network nsg create --resource-group $RGNAME --name NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl >>$LOGFILE 2>&1   
az network nsg create --resource-group $RGNAME --name NSG-${AZLOCTLA}-sap-${SIDLOWER}-db >>$LOGFILE 2>&1   
az network nsg list --resource-group $RGNAME 

# peer the hub and sap networks
printf '%s\n'
echo "###-------------------------------------###"
echo Peering SAP and Hub vnets
VNETPEER=VNET-${AZLOCTLA}-${RESOURCEGROUP}
az network vnet peering create --resource-group $RGNAME --remote-vnet ${VNETPEER}-hub --vnet-name ${VNETPEER}-sap --name VNETPEER-${AZLOCTLA}-hub-to-sap --allow-vnet-access  >>$LOGFILE 2>&1   
az network vnet peering create --resource-group $RGNAME --remote-vnet ${VNETPEER}-sap --vnet-name ${VNETPEER}-hub --name VNETPEER-${AZLOCTLA}-sap-to-hub --allow-vnet-access  >>$LOGFILE 2>&1   


# create jumpbox VM
printf '%s\n'
echo "###-------------------------------------###"
echo Creating linux jumpbox VM
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-hub
VMNAME=VM-${AZLOCTLA}-sap-jumpbox-lin
VMTYPE=Standard_D4s_v3
VMIMAGE=OpenLogic:CentOS:7.7:latest
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 127 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address-dns-name $JUMPFQDN --public-ip-address-allocation dynamic --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-ssh >>$LOGFILE 2>&1   

JUMPBOXFQDN=`az network public-ip list --resource-group $RGNAME|grep fqdn | awk '{print $2}'|sed 's/.\{2\}$//'|cut -c2-`

# inside the VM
printf '%s\n'
echo "###-------------------------------------###"
echo "Doing some actions inside the deployed jumpbox VM (install az cli, update packages etc)"
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${JUMPBOXFQDN} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo yum update -y
sudo yum install -y jre xclock xauth screen
sudo su -
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo
yum install azure-cli -y
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/sockperf?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/sockperf && sudo chmod ugo+x ~/sockperf
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/DLManager.jar?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/DLManager.jar 


reboot
EOF

# jumpbox is deployed, some optional files being copied
printf '%s\n'
echo "###-------------------------------------###"
echo "Waiting 45seconds for reboot of jumpbox VM"
sleep 45
scp -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p  $ADMINUSRSSH ${ADMINUSR}@${JUMPBOXFQDN}:~/.ssh
scp -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p  `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` ${ADMINUSR}@${JUMPBOXFQDN}:~/.ssh

endtime=`date +%s`
runtime=$( echo "$endtime - $starttime" | bc -l )
printf '%s\n'
echo "###-------------------------------------###"
echo Jumpbox deployement complete (hopefully successfully), took $runtime seconds
echo Check $LOGFILE for any errors running az cli, also check in Portal
echo To logon, ssh ${ADMINUSR}@${JUMPBOXFQDN} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'`
echo "###-------------------------------------###"
printf '%s\n'