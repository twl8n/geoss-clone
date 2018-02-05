DEPTH = ../..
DEST_DIR = $(LIB_DIR)/GEOSS

default: build

NONEXEC_TARGETS += Analysis.pm
NONEXEC_TARGETS += BuildOptions.pm
NONEXEC_TARGETS += Database.pm
NONEXEC_TARGETS += DebugProxy.pm
NONEXEC_TARGETS += Fileinfo.pm
NONEXEC_TARGETS += LazyValue.pm
NONEXEC_TARGETS += Layout.pm
NONEXEC_TARGETS += Session.pm
NONEXEC_TARGETS += Species.pm
NONEXEC_TARGETS += Terminal.pm
NONEXEC_TARGETS += Util.pm

BUILD_TARGETS += BuildOptions.pm
BuildOptions.pm: Makefile $(DEPTH)/build-options.mk
	@echo 'Making BuildOptions.pm...' >&2
	@(echo '# Automatically generated from build-options.mk; do not edit!' \
	 && echo 'package GEOSS::BuildOptions;' \
	 && echo 'use base "Exporter";' \
	 && echo 'push @EXPORT, q($$GEOSS_DIR);' \
	 && echo 'our $$GEOSS_DIR = "$(GEOSS_DIR)";' \
	 && echo 'push @EXPORT, q($$HTML_DIR);' \
	 && echo 'our $$HTML_DIR = "$(HTML_DIR)";' \
	 && echo 'push @EXPORT, q($$WEB_DIR);' \
	 && echo 'our $$WEB_DIR = "$(WEB_DIR)";' \
	 && echo 'push @EXPORT, q($$BIN_DIR);' \
	 && echo 'our $$BIN_DIR = "$(BIN_DIR)";' \
	 && echo 'push @EXPORT, q($$LIB_DIR);' \
	 && echo 'our $$LIB_DIR = "$(LIB_DIR)";' \
	 && echo 'push @EXPORT, q($$USER_DATA_DIR);' \
	 && echo 'our $$USER_DATA_DIR = "$(USER_DATA_DIR)";' \
	 && echo 'push @EXPORT, q($$DBMS);' \
	 && echo 'our $$DBMS = "$(GEOSS_DBMS)";' \
	 && echo 'push @EXPORT, q($$DB_NAME);' \
	 && echo 'our $$DB_NAME = "$(DB_NAME)";' \
	 && echo 'push @EXPORT, q($$HOST);' \
	 && echo 'our $$HOST = "$(GEOSS_HOST)";' \
	 && echo 'push @EXPORT, q($$PORT);' \
	 && echo 'our $$PORT = "$(GEOSS_PORT)";' \
	 && echo 'push @EXPORT, q($$SU_USER);' \
	 && echo 'our $$SU_USER = "$(GEOSS_SU_USER)";' \
	 && echo 'push @EXPORT, q($$PERL_LOCATION);' \
	 && echo 'our $$PERL_LOCATION = "$(PERL_LOCATION)";' \
	 && echo 'push @EXPORT, q($$VERSION);' \
	 && echo 'our $$VERSION = "$(VERSION)";' \
	 && echo 'push @EXPORT, q($$COOKIE_NAME);' \
	 && echo 'our $$COOKIE_NAME = "$(COOKIE_NAME)";' \
	 && echo 'push @EXPORT, q($$WEB_USER);' \
	 && echo 'our $$WEB_USER = "$(WEB_USER)";' \
	 && echo 'push @EXPORT, q($$SQL_DEBUG);' \
	 && echo 'our $$SQL_DEBUG = "$(SQL_DEBUG)";' \
	 && echo '1;' \
	) > BuildOptions.pm.tmp
	mv BuildOptions.pm.tmp BuildOptions.pm

BUILD_TARGETS += test-lib.cgi
TEST_LIBS = $(NONEXEC_TARGETS)

SUBDIRS = Analysis Arraycenter Database Experiment User

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk
