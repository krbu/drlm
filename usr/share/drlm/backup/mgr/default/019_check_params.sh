# bkpmgr workflow

# Simplificated Status Table
####################################################################
#  E/D/W   # Is SNAP # BKP Staus # Snap Status # Has Enabled Snaps #
####################################################################
#  Enable  #    -    #   D or W  #      -      #        -          # *Disable old. Enable DR file
#  Enable  #    0    #     E     #      -      #        0          # *Nothing to do.
#  Enable  #    0    #     -     #      -      #        1          # *Disable old. Enable DR file
#  Enable  #    1    #     -     #      0      #        -          # *Disable old. Enable DR file
#  Enable  #    1    #     E     #      1      #        -          # *Nothing to do.

#  Write   #    -    #   D or E  #      -      #        -          # *Disable old. Enable DR file
#  Write   #    0    #     W     #      -      #        0          # *Nothing to do.
#  Write   #    0    #     -     #      -      #        1          # *Disable old. Enable DR file
#  Write   #    1    #     -     #      -      #        -          # *Nothing to do. (Snaps can only be readable)

#  Disable #    -    #     D     #      -      #        -          # *Nothing to do.
#  Disable #    0    #    E/W    #      -      #        -          # *Disable backup and backup snaps
#  Disable #    1    #    E/W    #      0      #        -          # *Nothing to do. 
#  Disable #    1    #    E/W    #      1      #        -          # *Disable old. Enable DR file


# E = 0 - Enable/ 1 - Disable
# S = 0 - Is Snap/ 1 - Is Backup 
# B = Backup Enabled / Disabled / Write
# N = Snap Enabled / Disabled
# H = Has Enabled Sanps / Don't have Enabled Snaps

# Minimal Form (Disable old. Enable DR file) = ESBN + ~E~SH + ~ES~N + ~E~B 
# Minimal Form (Disable backup and backup snaps) = E~SB
# Minimal Form (Nothing to do) =  ~E~SB~H + ~ESBN + ES~N + E~B 

LogPrint "Checking if Backup ID or Snap ID ( $BKP_ID ) is registered in DRLM database ..."

# Check if recived BKP_ID is an SNAP and if is true get parent Backup ID and STATUS
if exist_snap_id "$BKP_ID"; then
  SNAP_ID=$BKP_ID
  LogPrint "- Snap ID $SNAP_ID found!"
  BKP_ID=$(get_snap_backup_id_by_snap_id $SNAP_ID)
  SNAP_STATUS="$(get_snap_status_by_snap_id $SNAP_ID)"
fi

# Check if BKP_ID exists in the database
if exist_backup_id "$BKP_ID" ; then
  LogPrint "- Backup ID $BKP_ID found!"

  CLI_ID=$(get_backup_client_id_by_backup_id $BKP_ID)
  CLI_NAME=$(get_client_name $CLI_ID)
  CLI_CFG=$(get_backup_config_by_backup_id $BKP_ID)
  BKP_TYPE=$(get_backup_type_by_backup_id $BKP_ID)
  BKP_PROTO=$(get_backup_protocol_by_backup_id $BKP_ID)
  BKP_STATUS=$(get_backup_status_by_backup_id $BKP_ID)
  BKP_ENABLED_SNAP=$(get_backup_active_snap_by_backup_id $BKP_ID)
  DRLM_ENCRYPTION=$(get_backup_encrypted_by_backup_id $BKP_ID)

  if [ "$DRLM_ENCRYPTION" == "1" ]; then
    DRLM_ENCRYPTION="enabled"
    DRLM_ENCRYPTION_KEY=$(get_backup_encryp_pass_by_backup_id $BKP_ID)
  else
    DRLM_ENCRYPTION="disabled"
    DRLM_ENCRYPTION_KEY=""
  fi
  
  # if the workflow is enable and backup status is enabled and has not enabled snaps -> Nothing to do!
  if [ "$ENABLE" == "yes" ] && [ -z "$SNAP_ID" ] && [ "$BKP_STATUS" == "1" ] && [ -z "$BKP_ENABLED_SNAP" ]; then
    LogPrint "WARNING! Trying to enable Backup $BKP_ID and it is already enabled!"
    exit 0
  fi

  # if the workflow is enable and backup status is enabled and snap is enabled -> Nothing to do!
  if [ "$ENABLE" == "yes" ] && [ -n "$SNAP_ID" ] && [ "$BKP_STATUS" == "1" ] && [ "$SNAP_STATUS" == "1" ]; then
    LogPrint "WARNING! Trying to enable Snap $SNAP_ID of Backup $BKP_ID and it is already enabled!"
    exit 0
  fi

  # if the workflow is write and backup status is write and has not enabled snaps -> Nothing to do!
  if [ "$WRITE_LOCAL_MODE" == "yes" ] && [ -z "$SNAP_ID" ] && [ "$BKP_STATUS" == "2" ] && [ -z "$BKP_ENABLED_SNAP" ]; then
    LogPrint "WARNING! Trying to enable Backup $BKP_ID in write mode and it is already enabled!"
    exit 0
  fi

  # if the workflow is write and backup status is write and has not enabled snaps -> Nothing to do!
  if [ "$WRITE_FULL_MODE" == "yes" ] && [ -z "$SNAP_ID" ] && [ "$BKP_STATUS" == "3" ] && [ -z "$BKP_ENABLED_SNAP" ]; then
    LogPrint "WARNING! Trying to enable Backup $BKP_ID in full write mode and it is already enabled!"
    exit 0
  fi

  # if the workflow is write and backup status is write and snap is enabled -> Nothing to do!
  if ( [ "$WRITE_LOCAL_MODE" == "yes" ] || [ "$WRITE_FULL_MODE" == "yes" ] ) && [ -n "$SNAP_ID" ]; then
    LogPrint "WARNING! Trying to enable Snap $SNAP_ID of Backup $BKP_ID in write mode and snaps are read only!"
    exit 0
  fi

  # if the workflow is disable and snap status is disabled -> Nothing to do!
  if [ "$DISABLE" == "yes" ] &&  [ -n "$SNAP_ID" ] && [ "$SNAP_STATUS" == "0" ]; then
    LogPrint "WARNING! Trying to disable Snap $SNAP_ID and it is already disabled!"
    exit 0
  fi

  # if the workflow is disable and backup status is disabled -> Nothing to do! 
  if [ "$DISABLE" == "yes" ] && [ "$BKP_STATUS" == "0" ]; then
    LogPrint "WARNING! Trying to disable Backup $BKP_ID and it is already disabled!"
    exit 0
  fi

else
  Error "Backup ID ($BKP_ID) not found!"
fi
