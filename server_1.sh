#!/bin/bash
#
#

rm -rf whole.txt message.txt id.txt name.txt url.txt all.txt database.txt

read -p "请输入合服类型anke/ke:" mode

pwd=""

if [[ "x$mode" == "xanke" ]];then
    gateway=""
elif [[ "x$mode" == "xke" ]];then
    gateway=""
else
    echo "Input error!"
    exit 2
fi

read -p "请输入DB分离ID,例100,189,190 :" ids
sshs="ssh -o StrictHostKeyChecking=no"

#脚本数据初始化1
function init1()
{
    echo "init data ..."
    ssh ubuntu@${gateway} "mysql -uroot -p$pwd -e 'select id from gateway.servers where id in($ids)' -s" >id.txt
    ssh ubuntu@${gateway} "mysql -uroot -p$pwd -e 'select server_name from gateway.servers where id in($ids)' -s" >name.txt
    ssh ubuntu@${gateway} "mysql -uroot -p$pwd -e 'select server_root_url from gateway.servers where id in($ids)' -s" >url.txt
    cat url.txt | egrep -o "([0-9]{1,3}.){3}[0-9]{1,3}" >all.txt
    paste -d"#" id.txt url.txt all.txt >tmp
    cat tmp | sort -n >message.txt
    rm -rf ./tmp
    echo "init data success!"
}

#脚本数据初始化2
function init2()
{
    cat message.txt | cut -d"#" -f1 | while read id
    do
    {
    server=`mysql --default-character-set=utf8 -udb_analysis -p$pwd -h ${gateway} -D gateway -e "select server_root_url from servers where id=${id}" -sN`
    if [[ $? -ne 0 ]] | [[ "x$server" = "x" ]]
    then
        echo "find mysql server error,exit now!" && exit
    fi

    server_port=`echo "$server"|awk -F ':' '{print $3}'|awk -F '/' '{print $1}'`
    if [[ "x$server_port" = "x" ]];then
        server_port=80
    fi
    if [[ "x${mode}" == "xke" ]];then
        case $server_port in
        80)
            database='kings'
            echo "${database}#kings#king_admin_api#redis.conf" >>database.txt
            ;;
        90)
            database='kings_2'
            echo "${database}#kings_two#king_admin_api_two#redis_two.conf" >>database.txt
            ;;
        92)
            database='kings_3'
            echo "${database}#kings_three#king_admin_api_three#redis_three.conf" >>database.txt
            ;;
        94)
            database='kings_4'
            echo "${database}#kings_four#king_admin_api_four#redis_three.conf" >>database.txt
            ;;
        *)
            echo 'search database error,exit now!' && exit
            ;;
        esac
    else
        case $server_port in
        91)
            database='kings'
            echo "${database}#kings#king_admin_api#redis.conf" >>database.txt
            ;;
        92)
            database='kings_2'
            echo "${database}#kings_two#king_admin_api_two#redis_two.conf" >>database.txt
            ;;
        *)
            echo 'search database error,exit now!' && exit ;;
        esac
    fi
    }
    done
    paste -d"#" message.txt database.txt name.txt>whole.txt
}
init1
init2
echo "update gateway status 2"
$sshs ubuntu@$gateway "mysql -uroot -p$pwd -D gateway -e 'update servers set maintain_status=1 where id in ($ids)'"
echo "停服并删除服务器逻辑服crontab自动任务〜！"

while read line
do
{
    echo "OK"
    ip=`echo "$line" | cut -d"#" -f3`
    king=`echo "$line" | cut -d"#" -f5`
    api=`echo "$line" | cut -d"#" -f6`
    echo "$ip $king $api"
    #ssh opsuser@${ip} "sudo /etc/init.d/cron start" </dev/null
    #ssh ubuntu@${ip} "cd /var/www/apps/${king}/current && whenever -c ${king}" </dev/null
    ssh ubuntu@${ip} "cd /var/www/apps/${king}/current && script/rails runner -e production \"BugFix.update_server_domain\"" </dev/null
    ssh ubuntu@${ip} "cd /var/www/apps/${king}/current && rails runner -e production \" ServerInfo.set 'maintain_status','1' \"" </dev/null
}
done < whole.txt
echo "网关和游戏服状态更新OK"
rm -rf ./*.txt 
