#!/bin/sh
# MySQL backup script
# Assumes private key of the user is used to authenticate

### Config ###
SFTPDIR="/db/"
SFTPUSER="username"
SFTPHOST="hostname"
LIMITBACKUPS=14

MCONFIG=(config1.cnf config2.cnf)

### DO NOT MODIFY BELOW THIS LINE ###
BACKUP=/tmp/backup.$$
NOW=$(date +"%Y-%m-%d")
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
GZIP="$(which gzip)"
SFTP="$(which sftp)"

## Remove old backups ##
echo 'ls -1a' | sftp ${SFTPUSER}@${SFTPHOST}:${SFTPDIR} > /tmp/dbsftp.out

### Start MySQL Backup ###
[ ! -d $BACKUP ] && mkdir -p $BACKUP || :

for conf in $MCONFIG
do
    MDBS="$($MYSQL --defaults-extra-file=$conf -Bse 'show databases')"
    for db in $MDBS
    do
        LIST="$(grep -o "$db.[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}*.*" /tmp/dbsftp.out | sort -r)"
        echo $LIST
        i=1
        for item in $LIST
        do
            i=$((i+1))
            RMFILE=mysql-$item
            if test "$i" -gt "$LIMITBACKUPS" ; then
                echo "DELETING "$RMFILE
                echo 'rm '$RMFILE | sftp ${SFTPUSER}@${SFTPHOST}:${SFTPDIR}
            fi
        done

        FILE=$BACKUP/mysql-$db.$NOW-$(date +"%T").gz
        echo "DUMPING " $FILE
        $MYSQLDUMP --defaults-extra-file=$conf $db | $GZIP -9 > $FILE
        scp $FILE ${SFTPUSER}@${SFTPHOST}:${SFTPDIR}
    done
done

rm -rf $BACKUP
