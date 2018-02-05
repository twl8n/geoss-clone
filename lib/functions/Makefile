DEPTH = ../..
DEST_DIR = $(LIB_DIR)
NONEXEC_TARGETS = $(BUILD_TARGETS)
BUILD_TARGETS += geoss_sql_lib
BUILD_TARGETS += geoss_analysis_tree_lib
BUILD_TARGETS += geoss_session_lib
BUILD_TARGETS += geoss_miame_lib
BUILD_TARGETS += geoss_reports_lib
BUILD_TARGETS += geoss_analysis_lib
BUILD_TARGETS += geoss_insert_lib
BUILD_TARGETS += geoss_message_lib

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk

$(BUILD_TARGETS): $(DEPTH)/perl-header
