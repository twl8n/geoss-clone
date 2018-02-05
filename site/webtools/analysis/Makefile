DEPTH = ../../..
DEST_DIR = $(WEB_DIR)/site/webtools/analysis
BUILD_TARGETS = Rwrapper.cgi
EXEC_TARGETS = $(BUILD_TARGETS)

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk

$(BUILD_TARGETS): $(DEPTH)/perl-header

SUBDIRS += addLinks
SUBDIRS += cluster
SUBDIRS += classification
SUBDIRS += diffDiscover
SUBDIRS += diffDiscMult
SUBDIRS += filter
SUBDIRS += filterMult
SUBDIRS += permCluster
SUBDIRS += qualityControl
SUBDIRS += treedraw
SUBDIRS += westfallYoung
