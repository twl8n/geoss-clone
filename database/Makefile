DEPTH = ..
DEST_DIR = $(WEB_DIR)/database
BUILD_TARGETS = geoss_schema.sql
EXEC_TARGETS = $(BUILD_TARGETS)
NONEXEC_TARGETS = initialize_db.sql

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk

$(BUILD_TARGETS): $(DEPTH)/perl-header

geoss_schema.sql : geoss_schema.in
	sed 's/%%GEOSS_SU_USER%%/$(GEOSS_SU_USER)/' geoss_schema.in > geoss_schema.sql 

SUBDIRS = 

