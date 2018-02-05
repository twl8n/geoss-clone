DEPTH = ../../..
DEST_DIR = $(LIB_DIR)/GEOSS/Analysis

NONEXEC_TARGETS += Extension.pm
NONEXEC_TARGETS += Filetype.pm
NONEXEC_TARGETS += Node.pm
NONEXEC_TARGETS += NodeNamer.pm
NONEXEC_TARGETS += SystemParameter.pm
NONEXEC_TARGETS += Tree.pm
NONEXEC_TARGETS += UserParameter.pm

BUILD_TARGETS += test-lib.cgi
TEST_LIBS = $(NONEXEC_TARGETS)

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk
