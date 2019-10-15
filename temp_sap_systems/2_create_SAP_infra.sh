#!/bin/bash
# continue on your jumpbox, NOT in your shell/cloud shell
# ideally, 1_create_jumpbox.sh should have finished without problems
# this script assumes everything is executed on the newly created jumpbox
# version 0.5  
# last changes: just minor corrections

screen -dm -S sapsetup

source parameters.txt
LOGFILE=/tmp/2_create_SAP_infra.log
starttime=`date +%s`
echo "###-------------------------------------###"
echo "Need to authenticate you with az cli"
echo "Follow prompt to authenticate in browser window with device code displayed"
az login

if [ $? -ne 0 ];
    then
        echo "Some error occured with az login, check display"
        exit 1
fi

echo "###-------------------------------------###"
echo "Azure cli logged on successfully"
echo "Have started screen, you can detach with Control-a d. This means press the Ctrl key and the 'a' key together and release, and then press the 'd' key."
echo "Script continues to run in background, you can re-attach with screen -r sapsetup"
echo "###-------------------------------------###"


az account set --subscription $AZSUB >>$LOGFILE 2>&1
RGNAME=RG-${AZLOCTLA}-${RESOURCEGROUP}
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/sockperf?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/sockperf --quiet >>$LOGFILE 2>&1 && sudo chmod ugo+x ~/sockperf 
wget "https://saeunsapsoft.blob.core.windows.net/sapsoft/linux_tools/DLManager.jar?sv=2018-03-28&ss=bfqt&srt=sco&sp=r&se=2023-10-04T19:12:30Z&st=2019-10-04T11:12:30Z&spr=https&sig=l1kQEWAWMYlqm08BHzHOIBykTdrL6DlpzRBYhMkPSXw%3D" -O ~/DLManager.jar --quiet >>$LOGFILE 2>&1

SIDLOWER=`echo $SAPSID|awk '{print tolower($0)}'`
VMTYPE=Standard_D4s_v3
VNETNAME=VNET-${AZLOCTLA}-${RESOURCEGROUP}-sap
VMIMAGE=SUSE:SLES-SAP:12-sp4:latest
VMNAME=VM-${AZLOCTLA}-${SIDLOWER}ascs01

printf '%s\n'
echo "###-------------------------------------###"
echo Creating ASCS and App Server VMs in RG $RGNAME
# ideally, you'd choose two zones (logical zones, logical to physical mapping changes PER subscription)
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.11 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 1 >$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
echo "###-------------------------------------###"
echo VM ${VMNAME} deployed, moving onto next

VMNAME=VM-${AZLOCTLA}-${SIDLOWER}ascs02
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.12 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 2 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
echo "###-------------------------------------###"
echo VM ${VMNAME} deployed, moving onto next

VMNAME=VM-${AZLOCTLA}-${SIDLOWER}app01
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.21 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 1 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
echo "###-------------------------------------###"
echo VM ${VMNAME} deployed, moving onto next

VMNAME=VM-${AZLOCTLA}-${SIDLOWER}app02
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${APPLSUBNET}.22 --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-appl --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-appl --zone 2 >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
echo "###-------------------------------------###"
echo VM ${VMNAME} deployed

echo "###-------------------------------------###"
echo Creating DB VMs 
printf '%s\n'
VMTYPE=Standard_E16s_v3
DBSUBNET=`echo $SAPIP|sed 's/.\{5\}$//'`
for i in 1 2
do
VMNAME=VM-${AZLOCTLA}-${SIDLOWER}db0${i}
az vm create --name $VMNAME --resource-group $RGNAME  --os-disk-name ${VMNAME}-osdisk --os-disk-size-gb 63 --storage-sku StandardSSD_LRS --size $VMTYPE --vnet-name $VNETNAME  --location $AZLOC --accelerated-networking true --public-ip-address '' --private-ip-address ${DBSUBNET}.14${i} --image $VMIMAGE --admin-username=$ADMINUSR --ssh-key-value=$ADMINUSRSSH --subnet=${VNETNAME}-db --nsg NSG-${AZLOCTLA}-sap-${SIDLOWER}-db --zone $i >>$LOGFILE 2>&1   
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk1 --new --sku StandardSSD_LRS --size 65 >>$LOGFILE 2>&1
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk2 --new --sku Premium_LRS --size 255 >>$LOGFILE 2>&1
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk3 --new --sku Premium_LRS --size 255 >>$LOGFILE 2>&1
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk4 --new --sku Premium_LRS --size 255 >>$LOGFILE 2>&1
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk5 --new --sku StandardSSD_LRS --size 127 >>$LOGFILE 2>&1
az vm disk attach --resource-group $RGNAME --vm-name $VMNAME --name ${VMNAME}-datadisk6 --new --sku StandardSSD_LRS --size 255 >>$LOGFILE 2>&1
done
echo "###-------------------------------------###"
echo DB VMs are now deployed
echo "###-------------------------------------###"
echo List of IPs for all servers 
printf '%s\n'
az vm list-ip-addresses --resource-group $RGNAME --output table |grep $SIDLOWER| awk '{print $2,$1, substr($1,8)}' > /tmp/vm_ips.txt
cat /tmp/vm_ips.txt
sudo bash -c 'cat /tmp/vm_ips.txt >> /etc/hosts'

fs_create_on_all_sap_servers () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/vm_ips.txt ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo bash -c "cat /tmp/vm_ips.txt >> /etc/hosts"
sudo pvcreate /dev/disk/azure/scsi1/lun0
sudo vgcreate vg_SAP /dev/disk/azure/scsi1/lun0
sudo lvcreate -n lv_SAP_usrsap -l 90%VG vg_SAP
sudo lvcreate -n lv_SAP_sapmnt -l 5%VG vg_SAP
sudo bash -c "echo '/dev/mapper/vg_SAP-lv_SAP_sapmnt  /sapmnt   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_SAP-lv_SAP_usrsap  /usr/sap   xfs      defaults      0 0' >> /etc/fstab"
sudo mkfs.xfs /dev/mapper/vg_SAP-lv_SAP_usrsap
sudo mkfs.xfs /dev/mapper/vg_SAP-lv_SAP_sapmnt
sudo mkdir /usr/sap /sapmnt
sudo mount -a
sudo sed -i 's/ResourceDisk.Format=n/ResourceDisk.Format=y/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g' /etc/waagent.conf
sudo sed -i 's/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=20480/g' /etc/waagent.conf
sudo systemctl restart waagent
sudo swapon -s
exit
EOF
}

fs_create_on_db_servers () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/vm_ips.txt ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo pvcreate /dev/disk/azure/scsi1/lun1
sudo pvcreate /dev/disk/azure/scsi1/lun2
sudo pvcreate /dev/disk/azure/scsi1/lun3
sudo pvcreate /dev/disk/azure/scsi1/lun4
sudo pvcreate /dev/disk/azure/scsi1/lun5
sudo vgcreate vg_HANA /dev/disk/azure/scsi1/lun[123]
sudo lvcreate -n lv_HANA_log -l 30%VG --stripes 3 vg_HANA
sudo lvcreate -n lv_HANA_data -l +60%VG --stripes 3 vg_HANA
sudo vgcreate vg_HANA_shared /dev/disk/azure/scsi1/lun4
sudo vgcreate vg_HANA_backup /dev/disk/azure/scsi1/lun5
sudo lvcreate -n lv_HANA_shared -l 90%VG vg_HANA_shared
sudo lvcreate -n lv_HANA_backup -l 90%VG vg_HANA_backup
sudo bash -c "echo '/dev/mapper/vg_HANA-lv_HANA_log  /hana/log   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_HANA-lv_HANA_data  /hana/data   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_HANA_shared-lv_HANA_shared  /hana/shared   xfs      defaults      0 0' >> /etc/fstab"
sudo bash -c "echo '/dev/mapper/vg_HANA_backup-lv_HANA_backup  /hana/backup   xfs      defaults      0 0' >> /etc/fstab"
sudo mkfs.xfs /dev/mapper/vg_HANA-lv_HANA_log
sudo mkfs.xfs /dev/mapper/vg_HANA-lv_HANA_data
sudo mkfs.xfs /dev/mapper/vg_HANA_shared-lv_HANA_shared
sudo mkfs.xfs /dev/mapper/vg_HANA_backup-lv_HANA_backup
sudo mkdir -p /hana/data /hana/log /hana/shared /hana/backup
sudo mount -a
EOF
}

for i in 1 2
do
VMNAME=${SIDLOWER}ascs0${i}
echo "###-------------------------------------###"
echo Creating SAP filesystems and doing basic post-install on ${VMNAME}
printf '%s\n'
fs_create_on_all_sap_servers
VMNAME=${SIDLOWER}app0${i}
echo "###-------------------------------------###"
echo Creating SAP filesystems and doing basic post-install on ${VMNAME}
printf '%s\n'
fs_create_on_all_sap_servers
VMNAME=${SIDLOWER}db0${i}
echo "###-------------------------------------###"
echo Creating SAP and HANA filesystems and doing basic post-install on ${VMNAME}
printf '%s\n'
fs_create_on_all_sap_servers
fs_create_on_db_servers
done

# install ascs
expiry=$(date '+%Y-%m-%dT%H:%MZ' --date "+30 minutes")
if [ -z "$STORACCURL" ]; then
    storageAccountKey=$(az storage account keys list --account-name ${STORACC} --resource-group ${STORACCRG} --query [0].value --output tsv)
fi

download_url () {
if [ -z "$STORACCURL" ]; then
    sasToken=$(az storage blob generate-sas --account-name ${STORACC} --account-key $storageAccountKey --container-name ${STORCONTAINER} --name $1 --permissions r --expiry $expiry --output tsv)
    shortURL=$(az storage blob url --account-name ${STORACC} --container-name ${STORCONTAINER} --name $1 --output tsv)
    fullURL=$shortURL?$sasToken
else
    fullURL=${STORACCURL}${1}${STORSAS}
fi
echo $fullURL
}

create_installfile_ascs () {
echo "sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download" > /tmp/${SIDLOWER}_install_ascs.sh
echo "mkdir installation" >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url sapcar_linux`'" -O /usr/sap/download/sapcar --quiet && sudo chmod ugo+x /usr/sap/download/sapcar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url SWPM.SAR`'" -O /usr/sap/download/SWPM.sar --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url SAPEXE.SAR`'" -O /usr/sap/download/installation/SAPEXE.SAR --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url DW.SAR`'" -O /usr/sap/download/installation/DW.SAR --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'wget "'`download_url SAPHOSTAGENT.SAR`'" -O /usr/sap/download/installation/SAPHOSTAGENT.SAR --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh
# echo 'wget "'`download_url ascs_instkey.pkey`'" -O /usr/sap/download/instkey.pkey --quiet'  >> /tmp/${SIDLOWER}_install_ascs.sh

# ascs ini file modifications
wget https://github.com/msftrobiro/SAPonAzure/raw/master/temp_sap_systems/install_files/ascs_install_ini.params --quiet -O /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_ascs_install_ini.params 
sed -i  "/NW_GetSidNoProfiles.sid/ c\NW_GetSidNoProfiles.sid = ${SAPSID}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_SCS_Instance.instanceNumber/ c\NW_SCS_Instance.instanceNumber = ${ASCSNO}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_SCS_Instance.scsVirtualHostname / c\NW_SCS_Instance.scsVirtualHostname = ${VMNAME}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_webdispatcher_Instance.scenarioSize/ c\NW_webdispatcher_Instance.scenarioSize = 500" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_webdispatcher_Instance.wdHTTPPort/ c\NW_webdispatcher_Instance.wdHTTPPort = 80${ASCSNO}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/NW_webdispatcher_Instance.wdHTTPSPort/ c\NW_webdispatcher_Instance.wdHTTPSPort = 443${ASCSNO}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_ascs_install_ini.params
sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ascs_install_ini.params
echo 'sudo su -' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar'  >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_INPUT_PARAMETERS_URL=/tmp/'${SIDLOWER}'_ascs_install_ini.params' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ASCS:NW752.HDB.HA' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_SKIP_DIALOGS=true' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'export SAPINST_START_GUISERVER=false' >> /tmp/${SIDLOWER}_install_ascs.sh
echo 'cd /usr/sap/download/SWPM && ./sapinst' >> /tmp/${SIDLOWER}_install_ascs.sh
}

execute_install_ascs () {
scp -p -oStrictHostKeyChecking=no -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` -p /tmp/${SIDLOWER}_ascs_install_ini.params ${ADMINUSR}@${VMNAME}:/tmp
ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/${SIDLOWER}_install_ascs.sh`
sudo su - ${SIDLOWER}adm  -c "sapcontrol -nr ${ASCSNO} -function GetProcessList"
EOF
}



setup_nfs_server () { 
APPLSUBNET=`echo ${SAPIP}|sed 's/.\{5\}$//'`
echo 'sudo chown '${SIDLOWER}'adm:sapsys /usr/sap' > /tmp/setup_nfs_server
echo 'sudo su - '${SIDLOWER}'adm -c "mkdir /usr/sap/trans"' >> /tmp/setup_nfs_server
echo 'sudo sh -c "echo  /sapmnt/'${SAPSID}'    '${APPLSUBNET}'.0/24\(rw,no_root_squash\) >> /etc/exports"' >> /tmp/setup_nfs_server
echo 'sudo sh -c "echo  /usr/sap/trans    '${APPLSUBNET}'.0/24\(rw,no_root_squash\) >> /etc/exports"' >> /tmp/setup_nfs_server
echo 'sudo systemctl enable nfsserver' >> /tmp/setup_nfs_server
echo 'sudo systemctl start nfsserver' >> /tmp/setup_nfs_server
echo 'sudo su - '${SIDLOWER}'adm sh -c "echo dbs/hdb/schema = SAPSR3 >> /sapmnt/'${SAPSID}'/profile/DEFAULT.PFL"' >> /tmp/setup_nfs_server

ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
`cat /tmp/setup_nfs_server`
exit
EOF
}

mount_nfs_export () {
    echo 'sudo sh -c "echo '${VMASCS}':/sapmnt    /sapmnt  nfs  defaults 0 0 >> /etc/fstab"' > /tmp/mount_nfs_export
    echo 'sudo sh -c "echo '${VMASCS}':/usr/sap/trans    /usr/sap/trans  nfs  defaults 0 0 >> /etc/fstab"' >> /tmp/mount_nfs_export
    ssh -oStrictHostKeyChecking=no ${ADMINUSR}@${VMNAME} -i `echo $ADMINUSRSSH|sed 's/.\{4\}$//'` << EOF
sudo mkdir /usr/sap/trans /sapmnt
`cat /tmp/mount_nfs_export`
sudo mount -a -t nfs
EOF

}

VMNAME=${SIDLOWER}ascs01
echo "###-------------------------------------###"
echo Creating SAP ASCS installation file and doing basic post-install on ${VMNAME}
printf '%s\n'
create_installfile_ascs
echo "###-------------------------------------###"
echo Executing SAP ASCS installation on ${VMNAME}
printf '%s\n'
execute_install_ascs
echo "###-------------------------------------###"
echo "Creating NFS server for sapmnt and trans on "${VMNAME}
printf '%s\n'
setup_nfs_server
# ASCS instance should be up and running after this
# next mount NFS volume on other app VMs
VMASCS=${SIDLOWER}ascs01
for VMNAME in ${SIDLOWER}ascs02 ${SIDLOWER}app01 ${SIDLOWER}app02
    do
    echo "###-------------------------------------###"
    echo "Mounting NFS volumes /sapmnt and /usr/sap/trans on "${VMNAME}
    printf '%s\n'
    mount_nfs_export
done



# WIP below
# install ERS
create_installfile_ers () {
echo "sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download" > /tmp/${SIDLOWER}_install_ers.sh
echo "mkdir installation" >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url sapcar_linux`'" -O /usr/sap/download/sapcar && sudo chmod ugo+x /usr/sap/download/sapcar'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url SWPM.SAR`'" -O /usr/sap/download/SWPM.sar'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url SAPEXE.SAR`'" -O /usr/sap/download/installation/SAPEXE.SAR'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url DW.SAR`'" -O /usr/sap/download/installation/DW.SAR'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'wget "'`download_url SAPHOSTAGENT.SAR`'" -O /usr/sap/download/installation/SAPHOSTAGENT.SAR'  >> /tmp/${SIDLOWER}_install_ers.sh
# shouldn't need this - echo 'wget "'`download_url ascs_instkey.pkey`'" -O /usr/sap/download/instkey.pkey'  >> /tmp/${SIDLOWER}_install_ers.sh

# ers ini file modifications
wget `download_url ers_install_ini.params` -O /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MASTERPW}" /tmp/${SIDLOWER}_ers_install_ini.params 
sed -i  "/NW_GetSidNoProfiles.sid/ c\NW_GetSidNoProfiles.sid = ${SAPSID}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_SCS_Instance.instanceNumber/ c\NW_SCS_Instance.instanceNumber = ${ersNO}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_SCS_Instance.scsVirtualHostname / c\NW_SCS_Instance.scsVirtualHostname = ${SIDLOWER}ascs02" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_webdispatcher_Instance.scenarioSize/ c\NW_webdispatcher_Instance.scenarioSize = 500" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_webdispatcher_Instance.wdHTTPPort/ c\NW_webdispatcher_Instance.wdHTTPPort = 80${ersNO}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/NW_webdispatcher_Instance.wdHTTPSPort/ c\NW_webdispatcher_Instance.wdHTTPSPort = 443${ersNO}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sapadmUID/ c\nwUsers.sapadmUID = 1001" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = 200" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = 1010" /tmp/${SIDLOWER}_ers_install_ini.params
sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MASTERPW}" /tmp/${SIDLOWER}_ers_install_ini.params
echo 'cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar'  >> /tmp/${SIDLOWER}_install_ers.sh
echo 'sudo bash -c "export SAPINST_INPUT_PARAMETERS_URL=/tmp/"${SIDLOWER}"_ers_install_ini.params && export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ers:NW752.HDB.HA && export SAPINST_SKIP_DIALOGS=true && export SAPINST_START_GUISERVER=false && cd /usr/sap/download/SWPM && ./sapinst"' >> /tmp/${SIDLOWER}_install_ers.sh

ssh -oStrictHostKeyChecking=no bob@vm-eun-sap-s01ers2 << EOF
sudo mkdir /usr/sap/download && sudo chmod 777 /usr/sap/download && cd /usr/sap/download
mkdir installation
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/sapcar_linux -O /usr/sap/download/sapcar && sudo chmod ugo+x /usr/sap/download/sapcar
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/SWPM10SP26_1-20009701.SAR -O /usr/sap/download/SWPM.sar
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/SAPEXE.SAR -O /usr/sap/download/installation/SAPEXE.SAR
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/DW.SAR -O /usr/sap/download/installation/DW.SAR
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/SAPHOSTAGENT.SAR -O /usr/sap/download/installation/SAPHOSTAGENT.SAR
wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/s01_ers_inifile.params
# wget -nv https://saeunsapsoft.blob.core.windows.net/sapsoft/s01_ers_instkey.pkey -O /usr/sap/download/instkey.pkey
cd /usr/sap/download && mkdir SWPM && mv SWPM.sar SWPM && cd SWPM && ../sapcar -xf SWPM.sar

sudo su -
echo `/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print$1}'` vm-eun-sap-s01ascs2 s01ascs2 >> /etc/hosts
export SAPINST_INPUT_PARAMETERS_URL=/usr/sap/download/s01_ers_inifile.params
export SAPINST_EXECUTE_PRODUCT_ID=NW_ABAP_ERS:NW752.HDB.HA
export SAPINST_SKIP_DIALOGS=true
export SAPINST_START_GUISERVER=false
cd /usr/sap/download/SWPM && ./sapinst
exit
EOF
}
# ERS still needs some love


endtime=`date +%s`
runtime=$( echo "$endtime - $starttime" | bc -l )
printf '%s\n'
echo "###-------------------------------------###"
echo SAP VM deployment and ASCS installation complete, took $runtime seconds