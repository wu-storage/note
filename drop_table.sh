#!/bin/bash
#
#
 
user=""
pwd=""

function Del_db()
{
count=`mysql -u$user -p$pwd -e "show processlist;" | grep "${database}$" | wc -l`
if [ $count -gt 3 ];then
    echo "Warning please check $database"
    mysql -u$user -p$pwd -e "show processlist;" | grep "${database}$"
    exit
fi


params=$(mysql -u$user -p$pwd -D $database -N -e "show tables;")

for table in $params
do
    mysql -u$user -p$pwd -e "drop table ${database}.${table}"
sleep 2
    echo "Del ${database}.${table} is OK"
done
mysql -u$user -p$pwd -e "drop database ${database};"
sleep 2
echo "Del ${database} is OK"
}

function main()
{
    cd  /InstanceStorage/merge_dump_file && ls -l | grep "kings_v2_${1}#" | grep -v grep  
    if [ $? -eq 0 ];then
        echo "Please check backup ~"
        exit
    fi

        
    database="kings_v2_$1" && Del_db
    database="kings_v2_$1_data" && Del_db
}
main $1
