$(DEPTH)/perl-header: $(DEPTH)/build-options.mk $(DEPTH)/rules.mk
	(echo -n '#!'; \
	if [ "$(PERL_LOCATION)" = "auto" ]; then \
	  which perl || exit 1; \
	else \
	  echo '$(PERL_LOCATION)'; \
	fi ; \
	echo '# The following variables come from the build-options.mk';\
	echo 'our $$GEOSS_DIR = "$(GEOSS_DIR)";'; \
	echo 'our $$HTML_DIR = "$(HTML_DIR)";'; \
	echo 'our $$WEB_DIR = "$(WEB_DIR)";'; \
	echo 'our $$BIN_DIR = "$(BIN_DIR)";'; \
	echo 'our $$LIB_DIR = "$(LIB_DIR)";'; \
	echo 'our $$USER_DATA_DIR = "$(USER_DATA_DIR)";'; \
	echo 'our $$GEOSS_DBMS = "$(GEOSS_DBMS)";'; \
	echo 'our $$DB_NAME = "$(DB_NAME)";'; \
	echo 'our $$GEOSS_HOST = "$(GEOSS_HOST)";'; \
	echo 'our $$GEOSS_PORT = "$(GEOSS_PORT)";'; \
	echo 'our $$GEOSS_SU_USER = "$(GEOSS_SU_USER)";'; \
	echo 'our $$PERL_LOCATION = "$(PERL_LOCATION)";'; \
	echo 'our $$VERSION = "$(VERSION)";'; \
	echo 'our $$COOKIE_NAME = "$(COOKIE_NAME)";'; \
	echo 'our $$WEB_USER = "$(WEB_USER)";'; \
	echo 'our $$SQL_DEBUG = "$(SQL_DEBUG)";'; \
	echo 'BEGIN { push @INC, "$(LIB_DIR)"; }'; \
	) > $(DEPTH)/perl-header

%.cgi: %.pl $(DEPTH)/perl-header
	(cat $(DEPTH)/perl-header; \
	 echo "#line 1 \"$<\""; \
	 cat $< \
	) > $@.tmp
	perl -c -I$(DEPTH)/lib $@.tmp
	chmod a+x $@.tmp
	mv $@.tmp $@

%: %.pl $(DEPTH)/perl-header
	(cat $(DEPTH)/perl-header; \
	 echo "#line 1 \"$<\""; \
	 cat $< \
	) > $@.tmp
	perl -c -I$(DEPTH)/lib $@.tmp
	chmod a+x $@.tmp
	mv $@.tmp $@

XML_ROOT ?= index.xml
doc-%-done: %.xsl $(XML_SOURCE)
	xsltproc -o $*/ $*.xsl $(XML_ROOT)
	touch $@

.cvsignore: Makefile $(DEPTH)/rules.mk
	@echo Creating .cvsignore...
	@(echo .cvsignore;\
	  for i in $(BUILD_TARGETS) $(CVSIGNORE); do echo $$i; done \
	) > .cvsignore.tmp
	@mv .cvsignore.tmp .cvsignore

spellcheck:
	@for i in $(SPELLCHECK); do \
		echo Spellchecking $$i...; \
		aspell --home-dir=$(DEPTH)/devtools \
		       --per-conf=aspell.conf --personal=aspell.words \
					 check $$i ; \
	done

CVSIGNORE += test-lib.pl
test-lib.cgi: $(TEST_LIBS)
test-lib.pl: Makefile
	@echo 'Making test-lib.pl...' >&2
	@(for i in $(TEST_LIBS); do \
	  echo "use $${i%.pm};"; \
		echo "  $$i" >&2; \
	done) > test-lib.pl.tmp
	@mv test-lib.pl.tmp test-lib.pl
