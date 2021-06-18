
m_tasks_apk.sh
	_mta_

	_task_install_my_software	->	_mta_task_install_my_software
	_expand_all_deploy_paths_apk	->	_mta_expand_all_deploy_paths
	task_update			->	task__update
	task_upgrade			->	task__upgrade
	task_remove_software		->	task__remove_unwanted
	task_install_my_software	->	task__install_requested

m_tasks_user.sh
	_mtu_

	task_restore_user	->	task_restore_user
	task_user_pw_reminder	->	task_user_pw_reminder

task_do_extra.sh
	_tde_

	task_do_extra_task	->	task_do_extra_task

task_etc_files.sh
	_tef_
	
	task_replace_some_etc_files ->	task_tef_replace_etc_files

task_nopasswd_sudo.sh
	_tns_

	task_nopasswd_sudo	->	task_tef_nopasswd_sudo

task_restore_root.sh
	_trr_
	task_restore_root	->	task_trr_restore_root

task_runbg.sh
	_trb_
	task_runbg	->	task_trb_runbg

task_sshd.sh
	_ts_
	task_sshd	->	task_ts_sshd
task_timezone.sh
	_tz_
	task_timezone



#
#   Sourcing dependency
#

if ! type 'ensure_service_is_added' 2>/dev/null | grep -q 'function' ; then
    verbose_msg "task_runbg needs to source openrc"
    . "$DEPLOY_PATH/scripts/extras/openrc.sh"
fi


#
#  Splitting long params on separate lines
#
msg_3 "$(printf "Will be created as %s :x:%s" "$SPD_UNAME" "$SPD_UID"
         echo ":$SPD_GID::/home/$SPD_UNAME:$SPD_SHELL"
        )"

