#!/bin/bash

# A script to backup minecraft worlds

function GetBackupPath {
    world=$1

    path_parts=(${world//// })
    len=${#path_parts[@]}
    backup_path="${path_parts[len - 2]}-${path_parts[len - 1]}"
    echo $backup_path
}

function GetLastModifiedSeconds {
    find $1 -printf "%Ts\n" | sort -nr | head -n 1
}

function GetLastModifiedReadable {
    find $1 -printf "%T+\n" | sort -nr | head -n 1
}    

function backup {
    world=$1
    backup_path=$(GetBackupPath $world)
    mkdir $backup_path

    world_modified_check="${world}/playerdata"
    world_last_modified=$(GetLastModifiedSeconds $world_modified_check)
    world_last_readable="$(GetLastModifiedReadable $world_modified_check)"
    last_backup_time=$(GetLastModifiedSeconds $backup_path)

    
    if [[ $last_backup_time < $world_last_modified ]]; then
        [[ $world_last_readable =~ [^.]* ]]
        filename="${BASH_REMATCH[0]}.zip"
        zip -r ${backup_path}/$filename $world
    else
        echo "No new activity since $world_last_readable"
    fi

}

backup $1
