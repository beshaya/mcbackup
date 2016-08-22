#!/bin/bash

# A script to backup minecraft worlds

REMOTE_BACKUP_SECONDS=$((60*60*24))

function GetBackupPath {
    world=$1
    path_parts=(${world//// })
    len=${#path_parts[@]}
    echo "${path_parts[len - 2]}-${path_parts[len - 1]}"
}

GetLastModifiedSeconds () {
    find $1 -mindepth 1 -printf "%Ts\n" | sort -nr | head -n 1
}

GetLastModifiedReadable() {
    find $1 -mindepth 1 -printf "%T+\n" | sort -nr | head -n 1;
}

GetLastBackup() { find $1 | sort -nr | head -n 1; }
GetLastRemoteBackup() {
    list=$(gsutil ls $1) || list="0_0.zip"
    echo $list | sort -nr | head -n 1;
}
GetSecondsFromBackup() {
    [[ $1 =~ _([0-9]*)\.zip ]]
    echo ${BASH_REMATCH[1]}
}
    
function Backup {
    world=$1
    backup_path=$(GetBackupPath $world)
    mkdir $backup_path > /dev/null 2>&1

    world_modified_check="${world}/playerdata"
    world_last_modified=$(GetLastModifiedSeconds $world_modified_check)
    world_last_readable="$(GetLastModifiedReadable $world_modified_check)"
    last_backup_time=$(GetLastModifiedSeconds $backup_path)

    if [[ $last_backup_time < $world_last_modified ]]; then
        [[ $world_last_readable =~ [^.]* ]]
        filename="${BASH_REMATCH[0]}_${world_last_modified}.zip"
        current_dir=${PWD}
        cd ${world}/..
        zip -r ${current_dir}/${backup_path}/${filename} ${world##*/}
        cd ${current_dir}
    else
        echo "No new activity since $world_last_readable"
    fi
}

function BackupRemote {
    world=$1
    bucket=$2
    force=$3
    do_backup=true
    
    # Decide whether to backup remotely
    last_remote_zip=$(GetLastRemoteBackup $bucket)
    last_remote_seconds=$(GetSecondsFromBackup $last_remote_zip)

    min_backup_time=$(($(date +%s)-$REMOTE_BACKUP_SECONDS))
    echo "Backup if retrieved time is before $min_backup_time"
    echo "Last save backed up at $last_remote_seconds"
    if [ $min_backup_time -lt $last_remote_seconds ]; then
        do_backup=false
    fi

    # Do the backup
    if ${do_backup} || ${force}; then
        backup_path=$(GetBackupPath $world)
        last_zip=$(GetLastBackup $backup_path)
        remote_name=$(printf ${last_zip////'\n'} | tail -n 1)
        echo "Backing up ${bucket}${remote_name}."
        gsutil cp ${last_zip} ${bucket}${remote_name}
    else
        echo "Next backup at $(($last_remote_seconds+$REMOTE_BACKUP_SECONDS))"
    fi
}

function RestoreRemote {
    world=$1
    bucket=$2
    last_remote_zip=$(GetLastRemoteBackup $bucket) || \
        (echo "no backups to restore!" && exit -1)
    restore_zip="restore.zip"
    echo "Restoring world from $last_remote_zip"
    gsutil cp $last_remote_zip $restore_zip
    unzip $restore_zip > /dev/null
    mv ${world##*/} $world
    rm $restore_zip
}

usage() {
    echo "Usage: $0 [-d direction] [-w world] [-b bucket] [-f]"
    echo "  -d 'backup' or 'restore' (default 'backup')"
    echo "  -w directory of world to save"
    echo "  -b Google Cloud bucket"
    echo "  -f force uploading to Google Cloud"
}

# Parse flags

DIRECTION="backup"
FORCE=false

while getopts ":d:w:b:s:f" o; do
    case "${o}" in
        d)
            DIRECTION=$OPTARG
            ;;
        w)
            WORLD=$OPTARG
            ;;
        b)
            BUCKET=$OPTARG
            ;;
        f)
            FORCE=true
            ;;
        s)
            SCREEN=$OPTARG
            ;;
    esac
done
shift $((OPTIND-1))

if [[ "$WORLD" == "" ]]; then
    usage
    exit -1
fi

if [[ "$DIRECTION" == "backup" ]]; then
    if [[ "$SCREEN" != "" ]]; then
        screen -r -S $SCREEN -X stuff '/save-all\n/save-off\n'
    fi
    Backup $WORLD
    if [[ "$SCREEN" != "" ]]; then
        screen -r -S $SCREEN -X stuff '/save-on\n'
    fi
    if [[ "$BUCKET" != "" ]]; then
        BackupRemote $WORLD $BUCKET $FORCE
    fi
elif [[ "$DIRECTION" == "restore" ]]; then
    RestoreRemote $WORLD $BUCKET
else
    usage
fi
