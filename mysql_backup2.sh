#!/bin/sh

db_backup_date=`date +%Y%m%d%H%M%S`
bak_path=/mnt1/mysql_backup2
eip=`ec2metadata |grep public-ipv4|awk '{print $2}'`
 
s3dir=""

if [ ! -d $bak_path/full ];then
        mkdir -p $bak_path/full
fi

if [ ! -d $bak_path/incremental ];then
        mkdir -p $bak_path/incremental
fi

cd $bak_path/full

lastfullbackupdate=`ls -l -t -r  | grep ^d | tail -1 | awk '{print $9}' | awk -F_ '{print $1}'`
todaydate=`date +%Y-%m-%d`

if [ "$lastfullbackupdate" != "$todaydate" ];then
        ls -l -t -r  | grep ^d | tail -1 | awk '{print $9}' | xargs rm -rf
        innobackupex $bak_path/full > $bak_path/full/$db_backup_date.log 2>&1
        result=`tail -1 $bak_path/full/$db_backup_date.log | grep -c completed`
        if [ $result -eq 1 ];then
                fullfilename=`ls -l -t -r | grep ^d | tail -1 | awk '{print $9}'`
                tar zcf full_$db_backup_date.tar.gz $fullfilename
                find  ./ -maxdepth 1 -cmin +600 | xargs rm -rf
                echo `sha1sum full_$db_backup_date.tar.gz` >> ../file.sha1sum
                s3cmd sync full_$db_backup_date.tar.gz ${s3dir}${eip}/
                s3cmd sync ../file.sha1sum ${s3dir}${eip}/
                rm -rf full_$db_backup_date.tar.gz
        fi
else
        lastfullbackupname=`ls -l -t -r  | grep ^d | tail -1 | awk '{print $9}'`
        innobackupex --incremental $bak_path/incremental -incremental-basedir=$bak_path/full/$lastfullbackupname > $bak_path/incremental/$db_backup_date.log 2>&1
        result=`tail -1 $bak_path/incremental/$db_backup_date.log | grep -c completed`
        if [ $result -eq 1 ];then
                cd $bak_path/incremental
                incrementalfilename=`ls -l -t -r | grep ^d | tail -1 | awk '{print $9}'`
                tar zcf incremental_$db_backup_date.tar.gz $incrementalfilename
                echo `sha1sum incremental_$db_backup_date.tar.gz` >> ../file.sha1sum
                s3cmd sync  incremental_$db_backup_date.tar.gz ${s3dir}${eip}/
                s3cmd sync   ../file.sha1sum ${s3dir}${eip}/
                find  ./ -maxdepth 1 -cmin +600 | xargs rm -rf
                rm -rf $incrementalfilename
        fi
fi
