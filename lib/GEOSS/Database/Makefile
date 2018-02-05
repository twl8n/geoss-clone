DEPTH = ../../..
DEST_DIR = $(LIB_DIR)/GEOSS/Database

NONEXEC_TARGETS += ControlledObject.pm
NONEXEC_TARGETS += Delete.pm
NONEXEC_TARGETS += Insert.pm
NONEXEC_TARGETS += Iterator.pm
NONEXEC_TARGETS += Object.pm
NONEXEC_TARGETS += Query.pm
NONEXEC_TARGETS += Select.pm
NONEXEC_TARGETS += Update.pm

BUILD_TARGETS += test-lib.cgi
TEST_LIBS = $(NONEXEC_TARGETS)

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk
