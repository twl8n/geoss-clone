DEPTH = ../..
DEST_DIR = $(WEB_DIR)/site/orgtools
BUILD_TARGETS = choose_organization.cgi index.cgi org_approve.cgi org_editorg.cgi org_edit_mem.cgi org_reports.cgi org_approve2.cgi org_upl.cgi
EXEC_TARGETS = $(BUILD_TARGETS)
NONEXEC_TARGETS += choose_organization.html index.html org_approve.html org_editorg.html org_edit_mem.html org_upl.html upl_filetype.html

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk


$(BUILD_TARGETS): $(DEPTH)/perl-header

SUBDIRS = 

