DEPTH = ../..
DEST_DIR = $(WEB_DIR)/site/admintools
BUILD_TARGETS =  admin_adduser.cgi admin_addorg.cgi admin_config.cgi admin_db_password.cgi admin_disable.cgi admin_email_users.cgi admin_enable.cgi admin_password.cgi admin_removeuser.cgi admin_removeorg.cgi admin_rm_inactive_users.cgi admin_testinstall.cgi admin_vieworg.cgi admin_viewuser.cgi edit_user_pi.cgi edit_user_pi2.cgi edit_user_pi3.cgi index.cgi 
EXEC_TARGETS = $(BUILD_TARGETS)
NONEXEC_TARGETS += admin_adduser.html admin_addorg.html admin_config.html admin_db_password.html admin_disable.html admin_email_users.html admin_enable.html admin_password.html admin_adduser.html admin_removeuser.html admin_removeorg.html admin_removeorg2.html admin_rm_inactive_users_1.html admin_rm_inactive_users_2.html admin_testinstall.html edit_pis_for_user.html edit_user_pi.html edit_users_for_pi.html index.html 

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk


$(BUILD_TARGETS): $(DEPTH)/perl-header

SUBDIRS = 

