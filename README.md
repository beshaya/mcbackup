A script for backing up minecraft worlds. Optionally backs up to Google Cloud Storage as well!

##Usage:##

Saving backups (run this in cron!)
```
./mcbackup.sh -w [PATH_TO_MINECRAFT_WORLD] -b [Google Bucket] -s [Screen session]
```
(By default, backups will only be saved to Google Cloud once per day, unless you use the force (-f) flag)

Restoring from backup
```
./mcbackup.sh -w [PATH_TO_MINECRAFT_WORLD] -b [Google Bucket] -d restore
```
(Restores the most recent save from Google Cloud Storage)
