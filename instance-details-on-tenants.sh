#!/bin/bash
if [ -z "$1" ]; then
	. /root/openrc
	TARGET_ENV=""
else
	TARGET_ENV=$1
	ENVRC_FILE="/etc/environments/${TARGET_ENV}/envrc"
	if [ -f "$ENVRC_FILE" ]; then
		. $ENVRC_FILE
	else
		. /root/openrc
	fi
fi	
OS_TENANT_NAME=admin
PATH=$PATH:/root/bin
OP_FILE=/tmp/vm-details.$$
OP_FILE2=/tmp/vm-details2.$$
OP_FILE2_CSV=/tmp/vm-details2.csv.$$
OP_FILE3_CSV=/tmp/vm-details3.csv.$$
OP_TL_FILE=/tmp/vm-details.tl.$$
OP_FL_FILE=/tmp/vm-details.fl.$$
OP_FD_FILE=/tmp/vm-details.fd.$$
OP_VM_FILE=/tmp/vm-details.vm.$$
OP_US_FILE=/tmp/vm-details.us.$$
OP_NA_FILE=/tmp/vm-details.na.$$
VM_DATA_DIR=/var/www/data

depipe()
{
	grep -v '^[-+|]*$' | sed -e 's/^| *//' | sed -e 's/ *|$//' | sed -e 's/ *| */\t/g'
}
{
echo "Project VM details data output $TARGET_ENV `date`: $OP_FILE" 
echo "" 
printf "\t%32s %-50s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-15s\n" 'Project ID' 'Project Name' 'VMs' 'VCPUs' 'VRAMs(GB)' 'DISK(GB)' 'VM-Usage' 'RAM-MB-HOURS' 'CPU-HOURS' 'DISK-GB-HOURS' 'Users'
printf "\t%32s %-50s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-5s %-15s\n" '--------------------------------' '------------' '---' '-----' '---------' '--------' '--------' '------------' '---------' '-------------' '-----'
echo ""
} |tee -a $OP_FILE |tee -a $OP_FILE2 

{
	echo "Project_ID,Project_Name,VMs,VCPUs,VRAMs(GB),DISK(GB),VM-Usage,RAM-MB-HOURS,CPU-HOURS,DISK-GB-HOURS,Users"
} |tee -a $OP_FILE2_CSV

{
	echo "Project_Name,Project_ID,VM_name,VM_ID,VCPUs,DISK(GB),VRAMs(GB),Image_name,Flavor,Status,Created,Network(s),User_name,Nova_Host,Config_Drive,Aggregate_Name,Ephemeral_DISK(GB),MAILER,SCRUM_PROJECT_KEY,DO_NOT_DELETE"
} |tee -a $OP_FILE3_CSV

{
	nova  aggregate-list | depipe | awk 'NR>1 {print $1}'| while read agg; do nova aggregate-details $agg; done
} | depipe > $OP_NA_FILE 

keystone tenant-list|depipe|awk -F'\t' 'NR>1 {print $1 "|" $2}' > $OP_TL_FILE
#echo "3bd882c1efbd40ad810d71d79e7fdeb3 admin"  | while read tenant_id tenant
#echo "15623daf25734d3292e0b6a65228776b CIS-DevOps"  | while read tenant_id tenant
#echo "6fc6c8193e1d45f095f3a330fe1b0688 CIS-ServiceAssure"  | while read tenant_id tenant
#echo "ec6f0491a5a3445ab3804f780be286f3 AS-SDN"  | while read tenant_id tenant
#echo "b8f046fa58ae4bd28f7467b274894cd2 qi-devops-vpn" | while read tenant_id tenant
#echo "44d617272e08459b9888833c492c81a3 angfong-test-1" | while read tenant_id tenant
cat $OP_TL_FILE | while IFS="|" read tenant_id tenant
do
        echo "processing tenant $tenant ..."
#        export OS_TENANT_NAME=$tenant
        vm_count=$(nova --os-tenant-id $tenant_id list --fields flavor|depipe|awk 'NR>1 {print $1,$2}'|tee $OP_FL_FILE|wc -l)
#        vm_count=$((vm_count - 1))
	if [ $vm_count -le 0 ]; then
		vm_count=0
		total_vcpus=0
		total_vrams=0
		total_disk=0
		vm_usage=0
		ram_mb_hours=0
		cpu_hours=0
		disk_gb_hours=0
	else
		total_vcpus=0
		total_vrams=0
		total_disk=0
		for flavor in `cat $OP_FL_FILE|awk ' {print $2}'`
		do
			nova flavor-show $flavor | depipe | egrep -w 'ram|disk|vcpus' > $OP_FD_FILE	
			vcpus=$(cat $OP_FD_FILE|grep -w vcpus | awk '{print $2}')
#			echo "vcpus=$vcpus"
			total_vcpus=$((total_vcpus + vcpus))
#			echo "total_vcpus=$total_vcpus"
			disk=$(cat $OP_FD_FILE|grep -w disk | awk '{print $2}')
#			echo "disk=$disk"
			total_disk=$((total_disk + disk))
			ram=$(cat $OP_FD_FILE|grep -w ram | awk '{print $2}')
#			echo "ram=$ram"
			total_vrams=$((total_vrams + ram))
			rm -f $OP_FD_FILE
		done
		total_vrams=$((total_vrams / 1024))
#		echo "total_vrams=$total_vrams"

		for vmid in `cat $OP_FL_FILE|awk '{print $1}'`
		do
			nova show $vmid | depipe | egrep -w '^status|^image|^flavor|^name|^created|^user_id|^tenant_id|^id|^OS-EXT-SRV-ATTR:host|^config_drive|network|^metadata' > $OP_VM_FILE
			status=$(cat  $OP_VM_FILE|grep -w "^status" |awk '{print $2}')
			image=$(cat  $OP_VM_FILE|grep -w "^image" |awk '{$1=$NF="";print $0}' | sed -e 's#^[[:blank:]]*##;s#[[:blank:]]*$##')
			flavor_id=$(cat  $OP_VM_FILE|grep -w "^flavor" |awk '{print $3}'| tr "(" " "|tr ")" " ")
			flavor=$(cat  $OP_VM_FILE|grep -w "^flavor" |awk '{print $2}')
			nova flavor-show $flavor_id | depipe | egrep -w 'ram|disk|vcpus|OS-FLV-EXT-DATA:ephemeral' > $OP_FD_FILE	
			vcpusid=$(cat $OP_FD_FILE|grep -w vcpus | awk '{print $2}')
			diskid=$(cat $OP_FD_FILE|grep -w disk | awk '{print $2}')
			ramid=$(cat $OP_FD_FILE|grep -w ram | awk '{print $2}')
			ramid=$((ramid/1024))
			ephemeral=$(cat $OP_FD_FILE|grep -w "OS-FLV-EXT-DATA:ephemeral" | awk '{print $2}')
			rm -f $OP_FD_FILE
			network=$(cat  $OP_VM_FILE|grep -ow  "network.*" | egrep "[0-9]{1,3}\.[0-9]{1,3}" |awk '{gsub(".*network","");print $0}' |while read n;do echo -n "$n ";done|sed -e s#,##g)
			vm_name=$(cat  $OP_VM_FILE|grep -w  "^name" |awk '{print $2}')
			created=$(cat  $OP_VM_FILE|grep -w  "^created" |awk '{print $2}')
			user_id=$(cat  $OP_VM_FILE|grep -w  "^user_id" |awk '{print $2}')
			tenant_id=$(cat  $OP_VM_FILE|grep -w  "^tenant_id" |awk '{print $2}')
			vm_id=$(cat  $OP_VM_FILE|grep -w  "^id" |awk '{print $2}')
			nova_host=$(cat  $OP_VM_FILE|grep -w  "^OS-EXT-SRV-ATTR:host" |awk '{print $2}')
			config_drive=$(cat  $OP_VM_FILE|grep -w  "^config_drive" |awk '{print $2}')
			if [ -n "$nova_host" ]; then
				aggregate_name=$(cat  $OP_NA_FILE|grep -w  "$nova_host" |awk '{print $2}'|head -1)
			else
				aggregate_name=""
			fi
			user_name=$(keystone --os-tenant-name admin user-get $user_id|depipe|grep -w name | awk '{print $2}')
			mailer=$(cat  $OP_VM_FILE|grep -w  "^metadata" |grep -Po '(?<="MAILER": ")[^"]*')
			scrum_project_key=$(cat  $OP_VM_FILE|grep -w  "^metadata" |grep -Po '(?<="SCRUM_PROJECT_KEY": ")[^"]*')
			do_not_delete=$(cat  $OP_VM_FILE|grep -w  "^metadata" |grep -Po '(?<="DO_NOT_DELETE": ")[^"]*')
			{
				echo "$tenant,$tenant_id,$vm_name,$vm_id,$vcpusid,$diskid,$ramid,\"$image\",$flavor,$status,$created,$network,$user_name,$nova_host,$config_drive,$aggregate_name,$ephemeral,$mailer,$scrum_project_key,$do_not_delete" 
			} |tee -a $OP_FILE3_CSV
			rm -f $OP_VM_FILE
		done

#		OS_TENANT_NAME=$tenant
		read vm_usage ram_mb_hours cpu_hours disk_gb_hours <<< $(nova usage --start `date -d '-1 day' '+ %Y-%m-%d'` --end `date '+ %Y-%m-%d'` --tenant $tenant_id|depipe|awk 'NR>2 {print $1,$2,$3,$4}')
		OS_TENANT_NAME=admin
	fi
	rm -f $OP_FL_FILE
	OS_TENANT_NAME=admin
        users=$(keystone user-list --tenant-id $tenant_id|depipe|awk 'NR>1 {print $2}'|grep -v admin|sed -e "s#\n#,#g")
	for user in $users 
	do
	{
		printf "\t%32s %-50s %-6s %-7s %-7s %-9s %-6s %-15s %-10s %-10s %-15s\n" $tenant_id "$tenant" $vm_count $total_vcpus $total_vrams $total_disk $vm_usage $ram_mb_hours $cpu_hours $disk_gb_hours $user
	} | tee -a $OP_FILE2
	{
		echo "$tenant_id,$tenant,$vm_count,$total_vcpus,$total_vrams,$total_disk,$vm_usage,$ram_mb_hours,$cpu_hours,$disk_gb_hours,$user"
	} | tee -a $OP_FILE2_CSV
	done
	users=$(echo $users|sed -e "s# #,#g")
        {
		printf "\t%32s %-50s %-6s %-7s %-7s %-9s %-6s %-15s %-10s %-10s %-15s\n" $tenant_id "$tenant" $vm_count $total_vcpus $total_vrams $total_disk $vm_usage $ram_mb_hours $cpu_hours $disk_gb_hours $users
        } | tee -a $OP_FILE
done
rm -f $OP_TL_FILE
rm -f $OP_NA_FILE
if [ -s $OP_FILE ]; then
	mkdir -p $VM_DATA_DIR
	if [ -z "$TARGET_ENV" ]; then
		mv $OP_FILE $VM_DATA_DIR/VM-Details
	else
		mv $OP_FILE $VM_DATA_DIR/${TARGET_ENV}_VM-Details
	fi
fi
if [ -s $OP_FILE2 ]; then
	mkdir -p $VM_DATA_DIR
	if [ -z "$TARGET_ENV" ]; then
		mv $OP_FILE2 $VM_DATA_DIR/VM-Details2
	else
		mv $OP_FILE2 $VM_DATA_DIR/${TARGET_ENV}_VM-Details2
	fi
fi
if [ -s $OP_FILE2_CSV ]; then
	mkdir -p $VM_DATA_DIR
	if [ -z "$TARGET_ENV" ]; then
		mv $OP_FILE2_CSV $VM_DATA_DIR/VM-Details2.csv
	else
		mv $OP_FILE2_CSV $VM_DATA_DIR/${TARGET_ENV}_VM-Details2.csv
	fi
fi
if [ -s $OP_FILE3_CSV ]; then
	mkdir -p $VM_DATA_DIR
	if [ -z "$TARGET_ENV" ]; then
		mv $OP_FILE3_CSV $VM_DATA_DIR/VM-Details3.csv
	else
		mv $OP_FILE3_CSV $VM_DATA_DIR/${TARGET_ENV}_VM-Details3.csv
	fi
fi
echo
if [ -z "$TARGET_ENV" ]; then
	echo "Projects VM details data output in $VM_DATA_DIR/VM-Details"
	echo "Projects VM details2 data output in $VM_DATA_DIR/VM-Details2"
	echo "Projects VM details2 csv data output in $VM_DATA_DIR/VM-Details2.csv"
	echo "Projects VM details3 csv data output in $VM_DATA_DIR/VM-Details3.csv"
else
	echo "Projects VM details data output in $VM_DATA_DIR/${TARGET_ENV}_VM-Details"
	echo "Projects VM details2 data output in $VM_DATA_DIR/${TARGET_ENV}_VM-Details2"
	echo "Projects VM details2 csv data output in $VM_DATA_DIR/${TARGET_ENV}_VM-Details2.csv"
	echo "Projects VM details3 csv data output in $VM_DATA_DIR/${TARGET_ENV}_VM-Details3.csv"
fi
echo
