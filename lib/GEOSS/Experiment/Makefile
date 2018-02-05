DEPTH = ../../..
DEST_DIR = $(LIB_DIR)/GEOSS/Experiment

NONEXEC_TARGETS += Arraylayout.pm
NONEXEC_TARGETS += Arraymeasurement.pm
NONEXEC_TARGETS += ExpCondition.pm
NONEXEC_TARGETS += Sample.pm
NONEXEC_TARGETS += Study.pm

BUILD_TARGETS += test-lib.cgi
TEST_LIBS = $(NONEXEC_TARGETS)

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk
