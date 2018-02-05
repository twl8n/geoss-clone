DEPTH = .
DEST_DIR = $(WEB_DIR)
CVSIGNORE = perl-header build-options.mk

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk

all: directories build install
unall: uninstall rmdirectories 

directories: 
	install -d -m 775 -g $(WEB_USER) $(ROOT)/$(USER_DATA_DIR)
	install -d $(ROOT)/$(WEB_DIR)
	install -d $(ROOT)/$(WEB_DIR)/site
	install -d -m 775 -g $(WEB_USER) $(ROOT)/$(WEB_DIR)/site/public_files
	install -d -m 775 -g $(WEB_USER) $(ROOT)/$(WEB_DIR)/site/logos
	install -d -m 775 -g $(WEB_USER) $(ROOT)/$(WEB_DIR)/site/icons
	install -d -m 775 -g $(WEB_USER) $(ROOT)/$(WEB_DIR)/site/webdoc/EN/html
 
rmdirectories:
	-rm -rf $(ROOT)/$(USER_DATA_DIR)
	-rm -rf $(ROOT)/$(WEB_DIR)

# lib must be built first
SUBDIRS = lib database bin site
