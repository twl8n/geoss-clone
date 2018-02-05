DEPTH = ..
DEST_DIR = $(WEB_DIR)/site
BUILD_TARGETS =  doc.cgi index.cgi req_account.cgi
EXEC_TARGETS = $(BUILD_TARGETS)
NONEXEC_TARGETS += account_request_adm_email.txt admin_guide.html analysis_step.html analysis_tutorial.html background.html closed.html data_file_creation.html db_access_error.html design_docs.html developer_guide.html doc.html download.html footer.html geoss_contact.html geoss_info.html header.html index.html install_guide.html intro_to_geoss.html layout_creation.html org_curator_guide.html req_account1.html req_account2_pub.html req_account2_mem.html req_account2_none.html req_account3.html req_account_pub_email.txt req_account_mem_email.txt schema_changes.html schema.html security.html stepbystep.html transcript.html user_guide.html web_interface.html workflow.html release_notes.txt 

include $(DEPTH)/build-options.mk
include $(DEPTH)/subdirs.mk
include $(DEPTH)/rules.mk


$(BUILD_TARGETS): $(DEPTH)/perl-header

SUBDIRS = public_data graphics webtools admintools orgtools curtools

