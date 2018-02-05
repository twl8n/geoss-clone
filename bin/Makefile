DEPTH = ..
DEST_DIR = $(BIN_DIR)
BUILD_TARGETS +=geoss_add_analysis 
BUILD_TARGETS +=geoss_add_all_ana 
BUILD_TARGETS +=geoss_add_all_layouts 
BUILD_TARGETS +=geoss_adduser 
BUILD_TARGETS +=geoss_bulk_adduser 
BUILD_TARGETS +=geoss_bulk_configurator
BUILD_TARGETS +=geoss_bulk_load
BUILD_TARGETS +=geoss_change_dbpw
BUILD_TARGETS +=geoss_change_userpw
BUILD_TARGETS +=geoss_get_ord_num
BUILD_TARGETS +=geoss_file_insert
BUILD_TARGETS +=geoss_initialize
BUILD_TARGETS +=geoss_load_available
BUILD_TARGETS +=geoss_loadaffylayout
BUILD_TARGETS +=geoss_multi_chip_load
BUILD_TARGETS +=geoss_order_info
BUILD_TARGETS +=geoss_rm_analysis
BUILD_TARGETS +=geoss_rm_inactive_users
BUILD_TARGETS +=geoss_study_info
BUILD_TARGETS +=geoss_study_load
BUILD_TARGETS +=geoss_tree_info
BUILD_TARGETS +=geoss_user_info
BUILD_TARGETS +=geoss_vacuum
BUILD_TARGETS +=geoss_versions

EXEC_TARGETS = $(BUILD_TARGETS)

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk

$(BUILD_TARGETS): $(DEPTH)/perl-header
