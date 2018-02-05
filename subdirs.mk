build: build-here build-subdirs
build-here: .cvsignore $(BUILD_TARGETS)
build-subdirs :
	@for i in $(SUBDIRS); do cd $$i && make build || exit 1; cd .. ; done

install: install-here install-subdirs
install-here: build-here
	install -d  --mode=755 \
	  $(ROOT)/$(DEST_DIR)
	@for i in $(EXEC_TARGETS); do \
	  echo "Installing $$i $(ROOT)/$(DEST_DIR)"; \
	  install --mode=755 \
	    $$i $(ROOT)/$(DEST_DIR) || \
	  exit 1; \
	done
	@for i in $(NONEXEC_TARGETS); do \
	  echo "Installing $$i $(ROOT)/$(DEST_DIR)"; \
	  install --mode=644 \
	    $$i $(ROOT)/$(DEST_DIR) || \
	  exit 1; \
	done
	@for i in $(DOC_TARGETS); do \
	  echo "Installing $$i $(ROOT)/$(DEST_DIR)"; \
	  install --mode=644 \
	    html/*  $(ROOT)/$(DEST_DIR)/html || \
	  exit 1; \
	done

install-subdirs :
	@for i in $(SUBDIRS); do cd $$i && make install || exit 1; cd .. ; done

clean: clean-here clean-subdirs
clean-here: 
	rm -f $(BUILD_TARGETS) $(CLEAN)
clean-subdirs :
	@for i in $(SUBDIRS); do cd $$i && make clean || exit 1; cd .. ; done

uninstall: uninstall-subdirs uninstall-here
uninstall-here: 
	@for i in $(EXEC_TARGETS) $(NONEXEC_TARGETS); do \
	  echo "Uninstalling $$i from $(ROOT)/$(DEST_DIR)" ; \
	  rm -f $(ROOT)/$(DEST_DIR)/$$i || exit 1; \
	done
	rmdir $(DEST_DIR) || echo;
uninstall-subdirs :
	@for i in $(SUBDIRS); do cd $$i && make uninstall || exit 1; cd .. ; done
