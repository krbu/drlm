# runbackup workflow

# Available VARs
# ==============
# CLI_ID      (Client Id) 
# CLI_NAME    (Client Name)
# CLI_CFG     (Client Configuration. If not set = "default"
# CLI_MAC     (Client Mac)
# CLI_IP      (Client IP)
# DISTRO      (Client Linux Distribution)
# RELEASE     (Client Linux Release)
# CLI_REAR    (Client ReaR Version)

# BKP_TYPE    (Backup Type. 0 - Data Only, 1 - PXE, 2 - ISO)
# ACTIVE_PXE  (=1 if backup type = PXE )

Log "$PROGRAM:$WORKFLOW:REMOTE:getspace:DR:$CLI_NAME: Collecting DR Image space requirements..."

if [ "$CLI_CFG" = "default" ]; then
  eval "$(egrep "EXCLUDE_MOUNTPOINTS|EXCLUDE_VG|INCLUDE_VG|ONLY_INCLUDE_VG|BACKUP_PROG_EXCLUDE" /etc/drlm/clients/$CLI_NAME.cfg | grep -v '#')"
else
  eval "$(egrep "EXCLUDE_MOUNTPOINTS|EXCLUDE_VG|INCLUDE_VG|ONLY_INCLUDE_VG|BACKUP_PROG_EXCLUDE" /etc/drlm/clients/$CLI_NAME.cfg.d/$CLI_CFG.cfg | grep -v '#')"
fi

INCLUDE_LIST_VG=( ${ONLY_INCLUDE_VG[@]} ${INCLUDE_VG[@]} )
EXCLUDE_LIST_VG=( ${EXCLUDE_VG[@]} )

EXCLUDE_LIST=( ${EXCLUDE_MOUNTPOINTS[@]} ${BACKUP_PROG_EXCLUDE[@]} )

if DR_IMG_SIZE_MB=$(ssh $SSH_OPTS $DRLM_USER@$CLI_NAME "$(declare -p EXCLUDE_LIST INCLUDE_LIST_VG EXCLUDE_LIST_VG ; declare -f get_fs_free_mb get_fs_size_mb get_fs_used_mb get_client_used_mb); get_client_used_mb") ; then
    Log "$PROGRAM:$WORKFLOW:REMOTE:getspace:DR:$CLI_NAME: .... remote space collection Success!"
    let "DR_IMG_SIZE_MB+=DR_IMG_SIZE_MB*10/100"
else
    report_error "ERROR:$PROGRAM:$WORKFLOW:REMOTE:getspace:DR:$CLI_NAME: Problem collecting remote space! aborting ...  Error Message: [ $DR_IMG_SIZE_MB ]"
    Error "$PROGRAM:$WORKFLOW:REMOTE:getspace:DR:$CLI_NAME: Problem collecting remote space! aborting ..."
fi

# Check if returned value is a number
re='^[0-9]+$'
if ! [[ $DR_IMG_SIZE_MB =~ $re ]] ; then
   Error "$PROGRAM:$WORKFLOW:REMOTE:getspace:DR:$CLI_NAME: Problem collecting remote space! DR_IMG_SIZE_MB is not numeric. aborting ..."
fi
