package main;
use strict;

sub messages
{
  my ($key, $param, $param2, $param3) = @_;

  my $error = "#FF0000";
  my $warn = "#808000";
  my $success = "#008000";
  my %messages;
    
  $messages{ERROR_POSTGRES} = {
        'color' => "$error",
        'text' => "$param.<br>\n",
  };

  $messages{ERROR_ARRAY_CENTER_NOT_ENABLED} = {
        'color' => "$error",
        'text' => "You cannot perform the desired activity as array center
          functionality is not enabled for installation.<br>\n",
  };

  $messages{ERROR_DATA_PUBLISHING_NOT_ENABLED} = {
        'color' => "$error",
        'text' => "You cannot perform the desired activity as data publishing
          functionality is not enabled for installation.<br>\n",
  };

  $messages{ERROR_SHORT_NAME_TOO_LONG} = {
        'color' => "$error",
        'text' => "One or more of your short names has more than 6 characters.<br>\n",
  };

  $messages{ERROR_SHORT_NAME_INVALID_CHARACTERS} = {
    'color' => "$error", 
    'text' => "Short name can only contain letters and digits.<br>\n",
  };

  $messages{CANT_PASTE_UNSPECIFIED_EXP_COND} = { 
    'color' => "$error", 
    'text' => "You must choose a study/experimental condition in order to paste in an experimental condition<br>\n",
  };


   # general
  $messages{FIELD_MUST_BE_UNIQUE} = { 
    'color' => "$error", 
    'text' => "$param is not unique. Please select another.<br>\n",
  };

  $messages{NAME_MUST_BE_UNIQUE} = { 
    'color' => "$error", 
    'text' => "Name is not unique. Please select another.<br>\n",
  };

  $messages{SUCCESS_UPDATE_FIELDS} = {
    'color' => "$success",
    'text' => "Successfully updated fields.<br>\n",
  };

# order

  $messages{CANT_DELETE_ORDER} = { 
   'color' => "$error", 
   'text' => "You cannot delete the array order as associated data has
      already been loaded.<br>",
  };

  $messages{INCOMPLETE_ORDER_SAMPLE_NEEDS_EXP_COND} = {
    'color' => "$error",
    'text' => "Order is incomplete.  Each sample needs at least one hybridization.<br>\n",
  };
    
 # groupref
  $messages{SUCCESS_UPDATE_GROUP_PERMS}= {
    'color' => "$success",
    'text' => "Successfully updated group/permission info.<br>\n",
  };


# tree
  $messages{CANT_DELETE_ROOT_NODE} = { 
    'color' => "$error", 
    'text' => "You cannot delete the root node.<br>\n",
  };

  $messages{CANT_RUN_OBSOLETE_TREE} = { 
    'color' => "$error", 
    'text' => "You cannot run an obsolete tree.<br>\n",
  };

  $messages{UNABLE_TO_COPY_TREE} = { 
    'color' => "$error", 
    'text' => "Error copying tree. $param.<br>\n",
  };

  $messages{UNABLE_TO_UPGRADE_TREE} = { 
    'color' => "$error", 
    'text' => "Tree cannot be upgraded.  It likely contains obsolete analysis
      nodes that have no current version.<br>\n",
  };

  $messages{TREE_SUCCESS} = { 
    'color' => "$error", 
    'text' => "Successfully $param the tree.<br>\n",
  };

  $messages{ERROR_OBJECT_UNKNOWN} = {
    'color' => "$error", 
    'text' => "Unable to find $param object for identifier $param2.<br>\n",
  };

  $messages{ERROR_TREE_NO_OUTPUT} = {
    'color' => "$error", 
    'text' => "No output files exist for tree $param.<br>\n",
  };


  $messages{TREE_OBSOLETE} = { 
    'color' => "$warn", 
    'text' => "This tree contains obsolete nodes that run versions of
      analyses that are no longer supported.  You may still view result
      files, but can no longer run the tree.  If newer versions of the
      relevant nodes are available, you may either 'Upgrade Tree' (will
      overwrite result files when run) or 'Copy Tree' (creates an
      upgraded copy of tree, preserving the original).
      <br>\n",
  };


  $messages{ERROR_TREE_CONFIG} = { 
    'color' => "$error", 
    'text' => "Cannot run tree due to improper tree configuration: $param<br>\n",
  };

  

 # study  
  $messages{INVALID_NUM_EXP_CONDS_ADD} = { 
   'color' => "$error", 
   'text' => "The number of experimental conditions to add must be between
     1-99.<br>",
  };

  $messages{BAD_DATE_FORMAT} = { 
   'color' => "$error", 
   'text' => "Invalid date format.  Dates must be specified as YYYY-MM-DD.<br>",
  };

  $messages{INCOMPLETE_ORDER_SAMPLE_NEEDS_EXP_COND} = {
    'color' => "$error",
    'text' => "Order is incomplete.  Each sample needs at least one hybridization.<br>\n",
  };

  $messages{ERROR_CANT_MODIFY_LOADED} = {
    'color' => "$error",
    'text' => "You cannot modify $param as it already has loaded data
      associated with it.<br>\n",
  };

  $messages{CANT_DELETE_LOCKED_STUDY} = { 
    'color' => "$error", 
    'text' => " has one or more locked experimental conditions. Experimental conditions are locked when there is a locked array order with a sample using that experimental condition.<br>\n",
  };

  $messages{ERROR_NAME_CHANGE_LOADED} = { 
    'color' => "$error", 
    'text' => "You cannot change the name of $param as it has data
      loaded.<br>\n",
  };

  $messages{ERROR_NO_CHIPS_IN_ORDER} = { 
    'color' => "$error", 
    'text' => "No order is necessary as there are no chips that are not
      currently ordered.<br>\n",
  };

  $messages{CANT_DELETE_LOADED} = { 
    'color' => "$error", 
    'text' => "$param has data loaded and cannot be deleted.<br>\n",
  };

  $messages{CANT_DELETE_LOCKED} = { 
    'color' => "$error", 
    'text' => "$param is associated with a locked order and cannot be
      deleted.<br>\n",
  };

  $messages{CANT_DELETE} = { 
    'color' => "$error", 
    'text' => "You cannot delete $param. $param2.<br>\n", 
  };

  $messages{CANT_DELETE_IN_USE_EXP_COND} = { 
    'color' => "$error", 
    'text' => "You cannot delete an experimental condition that is being used by a sample.<br>\n",
  };

  #permissions

  $messages{INVALID_PERMS} = { 
  'color' => "$error", 
  'text' => "You do not have appropriate permissions for the" .
     " requested activity.<br>\n",
  };

    
  $messages{INVALID_EMAIL_ADDRESS} = { 
    'color' => "$error", 
    'text' => "$param email address has invalid format.<br>\n",
  };

  $messages{INVALID_INACTIVITY_LOGOUT} = { 
    'color' => "$error", 
    'text' => "$param inactivity logout must be 1 or more minutes\n",
  };

  $messages{LAYOUT_MISMATCH} = {
        'color' => "$error", 
    'text' => "All selected hybridizations must have the same layout type<br>\n",
  };

  $messages{ERROR_INVALID_LOGIN} = { 
    'color' => "$error", 
    'text' => "Invalid login. Please try again.<br>\n",
  };

  $messages{SUCCESS_DELETE_STUDY} = {
    'color' => "$success",
    'text' => "Successfully deleted study $param.<br>\n",
  };

  $messages{SUCCESS_DELETE_EXP_COND} = {
    'color' => "$success",
    'text' => "Experimental condition delete successful.<br>\n",
  };

  $messages{ERROR_PUBLISH_DATA} = { 
    'color' => "$error", 
    'text' => "Publish data failed. Contact administrator for assistance<br>\n",
  };

  $messages{CANT_REMOVE_LAST_PI} = { 
    'color' => "$error", 
    'text' => "All users must be associated with a PI.  You may not remove the last PI associated with this user.<br>\n",
  };

  $messages{NAME_CANT_BE_BLANK} = { 
    'color' => "$error", 
    'text' => "Name cannot be blank.<br>\n",
  };

  $messages{SUCCESS_ORDER_CREATED} = { 
    'color' => "$success", 
    'text' => "Order $param successfully created.<br>\n",
  };

  $messages{SUCCESS_STUDY_CREATED} = { 
    'color' => "$success", 
    'text' => "Study $param successfully created.<br>\n",
  };

  $messages{ERROR_UNABLE_TO_CREATE} = { 
    'color' => "$error", 
    'text' => "Unable to create $param.<br>\n",
  };

  $messages{ERROR_PASSWORD_MISMATCH} = { 
    'color' => "$error", 
    'text' => "New passwords do not match.<br>\n",
  };

  $messages{INVALID_PASSWORD} = { 
    'color' => "$error", 
    'text' => "Passwords must contain no whitespace characters.  They must be at least 6 characters long.<br>\n",
  };

  $messages{INVALID_PI} = { 
    'color' => "$error", 
    'text' => "$param is not a PI.  If the new user is not their own PI, then you must specify a valid PI.<br>\n",
  };


  $messages{SUCCESS_DELETE_USER} = {
    'color' => "$success",
    'text' => "Successfully deleted $param user<br>\n",
  };

  $messages{ERROR_DELETE_USER_IS_PI} = {
    'color' => "$error",
    'text' => "Unable to delete $param user as they are a PI for another user.<br>\n",
  };

  $messages{ERROR_DELETE_USER_OWNS_DATA} = {
    'color' => "$error",
    'text' => "Unable to delete $param user.  The user owns data.<br>\n",
  };

  $messages{SUCCESS_ADD_USER} = {
    'color' => "$success",
    'text' => "Successfully added user $param.<br>\n",
  };

  $messages{ERROR_DELETE_SELF} = {
    'color' => "$error",
    'text' => "You are not allowed to remove yourself.<br>\n",
  };

  $messages{ERROR_DISABLE_SELF} = {
   'color' => "$error",
    'text' => "You are not allowed to disable yourself.<br>\n",
  };

  $messages{SUCCESS_DISABLE_USER} = {
    'color' => "$success",
    'text' => "Successfully disabled $param user<br>\n",
  };

  $messages{SUCCESS_ENABLE_USER} = {
    'color' => "$success",
    'text' => "Successfully enabled $param user<br>\n",
  };

  $messages{CANT_LOGIN_DISABLED} = {
    'color' => "$error",
    'text' => "Account disabled.<br>\n",
  };

  $messages{INCOMPLETE_ORDER_NEEDS_SAMPLE} = {
    'color' => "$error",
    'text' => "Order is incomplete.  Orders need at least one sample.<br>\n",
  };

  $messages{INCOMPLETE_ORDER_SAMPLE_NEEDS_HYB} = {
    'color' => "$error",
    'text' => "Order is incomplete.  Each sample needs at least one hybridization.<br>\n",
  };

  $messages{INVALID_USER_TYPE} = {
    'color' => "$error",
    'text' => "You cannot create a user of type '$param' on this installation. That type of user is disabled for this installation.<br>\n",
  };

  $messages{INVALID_LENGTH_128} = {
    'color' => "$error",
    'text' => "Too much data entered for the $param field. Less than 128 
      characters is required.<br>\n",
  };

  $messages{WARN_CHANGE_PASSWORD} = {
    'color' => "$warn",
    'text' => "For security reasons, we recommend you change your password.<br>\n"
  };

  $messages{INVALID_DAYS_TO_CONFIRM} = {
    'color' => "$error",
    'text' => "Days to confirm must be an integer between one and thirty.<br>\n"
  };

  $messages{ERROR_DELETE_SPECIAL_CENTER_HAS_MEMBERS} = {
    'color' => "$error",
    'text' => "The special center cannot be deleted while it has members.<br>\n"
  };

  $messages{SUCCESS_MODIFY_SPECIAL_CENTER} = {
    'color' => "$success",
    'text' => "Successfully $param the special center.<br>\n",
  };

  $messages{ERROR_ACTION} = {
    'color' => "$error",
    'text' => "Invalid action.<br>\n"
  };

  $messages{SUCCESS_MODIFY_MEMBERS} = {
    'color' => "$success",
    'text' => "Successfully $param the members.<br>\n",
  };

  $messages{SUCCESS_SUBMIT_ORDER} = {
   'color' => "$success",
   'text' => "Your array order was successfully submitted. You can monitor
     your order status via the View All Array Orders link.<br>\n",
  };

  $messages{INCORRECT_ORDER_STATUS} = { 
   'color' => "$error", 
   'text' => "Only array orders with $param status can be $param2.<br>\n",
  };

  $messages{SUCCESS_ORDER_APPROVED} = {
   'color' => "$success",
    'text' => "Order $param has been approved.<br>\n",
  };

  $messages{FIELD_MANDATORY} = {
     'color' => "$error",
     'text' => "$param is a mandatory field${param2}.<br>\n",
  };
  $messages{DATA_SOURCE_MANDATORY} = {
        'color' => "$error",
        'text' => "You must select a data source.<br>\n",
  };

  $messages{ERROR_CHANGE_PASSWORD_NO_ACCESS} = { 
    'color' => "$error", 
    'text' => "Only users with write access to $WEB_DIR/.geoss can change the password.<br>\n",
  };

  $messages{SUCCESS_CHANGE_PASSWORD} = {
    'color' => "$success",
    'text' => "Successfully changed password for $param.<br>\n",
  };

  $messages{ERROR_NO_LAYOUT_SPECIFIED} = { 
    'color' => "$error", 
    'text' => "No layout rows for specified chip ($param).<br>\n",
  };

  $messages{ERROR_AMBIGUOUS_SPOT_ID} = { 
    'color' => "$error", 
    'text' => "Ambiguous spot identifier ($param) in the layout..<br>\n",
  };

  $messages{ERROR_NO_SPOT_FOR_PROBE_SET_NAME} = { 
    'color' => "$error", 
    'text' => "No spots matching Probe Set Name ($param)<br>\n",
  };

  $messages{ERROR_FILE_OPEN} = { 
    'color' => "$error", 
    'text' => "Unable to open file: $param.<br>\n",
  };

  $messages{ERROR_DATA_LOAD} = { 
    'color' => "$error", 
    'text' => "Data load failed. $param<br>\n",
  };

  $messages{ERROR_DATA_LOAD_INVALID_ROW} = { 
    'color' => "$error", 
    'text' => "Invalid input row at line number: $param.  $param2<br>\n",
  };

  $messages{ERROR_DATA_LOAD_HYB_EXIST} = { 
    'color' => "$error", 
    'text' => "Hybridization ($param) specified in $param2 does not exist.<br>\n",
  };

  $messages{ERROR_DATA_LOAD_HYB_IN_REQ} = { 
    'color' => "$error", 
    'text' => "Hybridization ($param) specified in $param2 is not part of
      $param3.<br>\n",
  };

  $messages{ERROR_DATA_LOAD_PARSE} = { 
    'color' => "$error", 
    'text' => "Error loading data from $param.  First column header must be
      'Probesets' or 'probe set name'.<br>\n",
  };

  $messages{ERROR_DATA_LOAD_MULT_CHIP_TYPE_SINGLE_FILE} = { 
    'color' => "$error", 
    'text' => "Data load request includes hybridizations with multiple chip
      types.  Data cannot be loaded from a single file for multiple chip
      types.<br>\n",
  };

  $messages{CANT_PLACE_ORDER_STUDY_NOT_COMPLETE} = { 
    'color' => "$error", 
    'text' => "You cannot place an order for a study until the study status
      ($param) is COMPLETE <br>\n",
  };

  $messages{CANT_LOAD_DATA_STUDY_NOT_COMPLETE} = { 
    'color' => "$error", 
    'text' => "Data cannot be loaded until the array study status is " .
      "COMPLETE <br>\n",
  };

  $messages{CANT_LOAD_DATA_UNLOCKED} = { 
    'color' => "$error", 
    'text' => "Data cannot be loaded until the array order is locked <br>\n",
  };

  $messages{CANT_LOAD_DATA_NOT_APPROVED} = { 
    'color' => "$error", 
    'text' => "Data cannot be loaded until the array order is approved.<br>\n",
  };

  $messages{ERROR_DATA_LOAD_DUPLICATES} = { 
    'color' => "$error", 
    'text' => "Ambiguous file load requested. Duplicate files exist for $param under the CHIP_DATA_PATH.  Please delete one of the versions.<br>\n",
  };

  $messages{ERROR_LOAD_DATA_LINK} = { 
    'color' => "$error", 
    'text' => "Link failed linking $param to $param2.  Contact your system administrator for assistance.<br>\n",
  };

  $messages{ERROR_DATA_ALREADY_LOADED} = { 
    'color' => "$error", 
    'text' => "Data is already loaded for $param.  You cannot re-load<br>\n",
  };

  $messages{WARN_LAYOUT_MISMATCH} = { 
    'color' => "$warn", 
    'text' => "Analysis input file contains chips of different types.  Analysis results will not be meaningful.<br>\n",
  };

  $messages{ERROR_LAYOUT_MISMATCH} = { 
    'color' => "$error", 
    'text' => "Cannot create tree as the specified input has more than one
      layout type.<br>\n",
  };

  $messages{NO_CDNA_SUPPORT} = { 
    'color' => "$error", 
    'text' => "cDNA upload is not fully supported at this time.<br>\n",
  };

  $messages{ERROR_CREATE_LINK} = { 
    'color' => "$error", 
    'text' => "Unable to link to public data.  Please contact GEOSS administrator immediately.<br>\n",
  };

  $messages{EXTENSION_MISMATCH} = { 
    'color' => "$error", 
    'text' => "The extension on the specified filename ($param2) does not match the extension on the source filename ($param).  This may lead to difficulties viewing the file correctly.<br>\n",
  };

  $messages{SUCCESS_EMAIL} = {
    'color' => "$success",
    'text' => "Email has been sent.<br>\n",
  };

  $messages{ERROR_SUBMIT_DUP_SHORT_NAMES} = { 
    'color' => "$error", 
    'text' => "Unable to submit order.  Two or more of your samples have duplicate experimental condition short names.  Although you may use experimental conditions from different studies in the same order, they may not have the same name, due to array center requirements.  Please modify your experimental condition names by editing the appropriate study.<br>\n",
  };

  $messages{ERROR_VIEW_QC_NO_DATA} = {
    'color' => "$error",
    'text' => "Currently, you have no data loaded.  You cannot view quality
    control records for data that has not yet been loaded.<br>\n",
  };
    


  $messages{WARN_ANALYSIS_SET_EXISTS} = { 
     'color' => "$warn", 
     'text' => "Analysis set $param already exists.  A new analysis set will
        not automatically created for column $param2.<br>\n",
  };

  $messages{WARN_ANALYSIS_COND_EXISTS} = { 
     'color' => "$warn", 
     'text' => "Analysis condition $param already exists.  A new analysis
        condition will not be automatically created for column $param2.<br>\n",
  };


  $messages{SUCCESS_LOAD} = { 
    'color' => "$success", 
    'text' => "Initiated data load for $param.  You will receive an email
      when the load is complete.<br>\n",
  };
  $messages{ERROR_LOAD} = { 
     'color' => "$error", 
     'text' => "File did not load correctly.<br>\n",
  };

  $messages{ERROR_LOAD_BAD_INPUT} = { 
    'color' => "$error", 
    'text' => "Unable to load chip data due to a bad file format.  Please contact the GEOSS administrator for information regarding appropriate file format.<br>\n",
  };

  $messages{SUCCESS_DELETE} = { 
    'color' => "$success", 
    'text' => "Successfully deleted $param $param2.<br>\n",
  };

  $messages{SUCCESS_ADD_GROUP} = { 
    'color' => "$success", 
    'text' => "Successfully added group $param.<br>\n",
  };

  $messages{ERROR_SAMPLES_PER_CONDITION_INVALID} = { 
    'color' => "$error", 
    'text' => "You must specify the default number of samples per condition.  
      The number must be greater than zero.<br>\n",
  };

  $messages{ERROR_CHIPS_PER_SAMPLE_INVALID} = { 
    'color' => "$error", 
    'text' => "You must specify the default number of chips per sample.  The
    number must be greater than zero.<br>\n",
  };

  $messages{ERROR_NEEDS_HYB} = { 
    'color' => "$error", 
    'text' => "Number of hybridizations must be greater than zero.<br>\n",
  };

  $messages{ERROR_UNLOCK} = { 
    'color' => "$error", 
    'text' => "Cannot unlock $param.<br>\n",
  };

  $messages{ERROR_LOCK} = { 
    'color' => "$error", 
    'text' => "Cannot lock $param.<br>\n",
  };
    
  $messages{ERROR_DUPLICATE_ORDER} = { 
    'color' => "$error", 
    'text' => "Cannot insert order $param as that order already exists.<br>\n",
  };
    
  $messages{INVALID_FIELD_FOR_TABLE} = { 
    'color' => "$error", 
    'text' => "Invalid field $param2 specified for table $param.<br>\n",
  };

  $messages{INVALID_PK_FOR_TABLE} = { 
    'color' => "$error", 
    'text' => "Invalid pk: $param2 specified for table $param.<br>\n",
  };
    
  $messages{INVALID_EXP_COND_NO_STUDY} = { 
    'color' => "$error", 
    'text' => "$param experimental condition has no study associated with it.<br>\n",
  };

  $messages{ERROR_DUPLICATE_SHORT_NAME_IN_SAME_STUDY} = { 
    'color' => "$error", 
    'text' => "You cannot use a duplicate short name/abbrev. name ($param) for two experimental conditions in the same study.<br>\n",
  };

  $messages{INCOMPLETE_SAMPLE_NEEDS_ORDER} = { 
    'color' => "$error", 
    'text' => "Sample must have an associated order(oi_fk).<br>\n",
  };

  $messages{INCOMPLETE_HYB_NEEDS_SAMPLE} = { 
    'color' => "$error", 
    'text' => "Hybridizations must have an associated sample(smp_fkk).<br>\n",
  };

  $messages{INCOMPLETE_HYB_NEEDS_CHIP_TYPE} = { 
    'color' => "$error", 
    'text' => "Hybridizations must have an associated layout(al_fk).<br>\n",
  };
    
  $messages{CANT_SET_CALCULATED_VALUE} = { 
    'color' => "$error", 
    'text' => "The $param field cannot be set directly on insert. It is a
       calculated value.<br>\n",
  };

  $messages{ERROR_VIEW_ORDER_BAD_CONFIG} = { 
    'color' => "$error", 
    'text' => "Cannot view order due to improper order configuration 
       resulting in an inability to name hybridizations uniquely.  This 
       may have been caused by having more than 26 biological replicates or
       by using experimental conditions from different studies that have the
       same short name in the order.<br>\n",
  };


  # File related errors

  $messages{ERROR_BAD_FILE_DUPLICATE_ROWS} = { 
    'color' => "$error", 
    'text' => "Duplicate rows for $param contain different data values.<br>\n",
  };
    

  $messages{ERROR_BAD_FILE_INVALID_HYB} = { 
     'color' => "$error", 
     'text' => "Bad criteria file (line: $param).  Hybridization $param2
        does not exist.<br>\n",
  };

  $messages{WARN_BAD_FILE_MISSING_DATA} = { 
     'color' => "$warn", 
     'text' => "No data specified on line: $param col: $param2.  This may 
        provide unexpected results when using criteria files.<br>\n",
  };

  $messages{ERROR_BAD_FILE_TYPE} = { 
     'color' => "$error", 
     'text' => "Bad file type.  Expected a file of type: $param.<br>\n",
  };

  $messages{ERROR_BAD_FILE_TYPE_CRITERIA_NOT_ASCII} = { 
     'color' => "$error", 
     'text' => "Bad file type: $param.  Criteria files must be ASCII text.<br>\n",
  };

  $messages{ERROR_BAD_FILE_FORMAT} = { 
     'color' => "$error", 
     'text' => "Bad file format.  $param<br>\n",
  };

  $messages{ERROR_BAD_FILE_CONTENT} = { 
     'color' => "$error", 
     'text' => "Bad file content.  $param<br>\n",
  };


  $messages{ERROR_BAD_FILE_FIRST_COL} = { 
     'color' => "$error", 
     'text' => "Bad critieria file (line: $param).  The header for the
        first column ($param2) must be 'Name'.<br>\n",
  };


  $messages{ERROR_BAD_FILE_CAT_OR_CONT} = { 
     'color' => "$error", 
     'text' => "Bad criteria file (line: $param col: $param2).  Column
        headers must be of the format '<View>::Categorical' or
        '<View>::Continuous'.<br>\n",
  };


  $messages{ERROR_BAD_FILE_CAT_AND_CONT} = { 
     'color' => "$error", 
     'text' => "Bad criteria file (lin: $param col:$param2). Column header
        must be either categorical or continuous, not both.<br>\n",
  };
  $messages{ERROR_DATA_LOAD_NO_DATA_FILE} = { 
    'color' => "$error", 
    'text' => "Cannot find file $param under $param2.  Please copy the file to the appropriate location<br>\n",
  };

  $messages{ERROR_UNABLE_TO_READ_FILE} = { 
    'color' => "$error", 
    'text' => "Unable to read file $param.<br>\n",
  };

  
  $messages{ERROR_CHIP_TYPE_FILE_MISMATCH} = { 
     'color' => "$error", 
     'text' => "GEOSS chip type ($param) does not match file chip type ($param2).  Data cannot be loaded.<br>\n",
  };
  
  $messages{WARN_NO_DEFAULT_AL_FK} = { 
     'color' => "$warn", 
     'text' => "No default chip type is defined.  Defining a chip type is
       required for all samples and setting a default will save configuration
       time.  Click 'Edit Defaults' to set a default chip type.<br>\n",
  };
  
  $messages{WARN_FILE_CHIP_TYPE_UNKNOWN} = { 
     'color' => "$warn", 
     'text' => "Unable to verify accuracy of the specified GEOSS chip type
       ($param) as no rpt file was provided.  Attempting to proceed with data
       load.<br>\n",
  };
  
  $messages{ERROR_FILE_EXISTS} = {
     'color' => "$error",
     'text' => "That file already exists.  Please specify a different file name.<br>\n",
  };
  
  $messages{INVALID_FILE_NAME} = {
     'color' => "$error",
     'text' => "Invalid filename.  Please specify a valid filename.<br>\n",
  };
  
  $messages{CANT_DELETE_FILE} = { 
   'color' => "$error", 
   'text' => "You cannot delete that file as it is in use.<br>\n",
  };

  $messages{ERROR_LOAD_DATA_MISSING_DATA_FILE} = { 
    'color' => "$error", 
    'text' => "Missing data file $param. Unable to load data.<br>\n",
  };

  $messages{ERROR_CONDITION_GROUPING_FORMAT} = { 
    'color' => "$error", 
    'text' => "Bad condition grouping format.  Condition groups should be " .
       "series of numbers delimited by commas.<br>\n",
  };
  $messages{ERROR_CONDITION_LABELS_FORMAT} = { 
    'color' => "$error", 
    'text' => "Bad condition label format.  Condition labels should be " .
       "series of labels (words comprised of letters and numbers)" .
       "  delimited by commas.<br>\n",
  };
  $messages{ERROR_NE_CONDS_AND_CONDS_LABELS} = { 
    'color' => "$error", 
    'text' => "The number of condition groups must equal the number of " .
      " condition labels.  This means that there should be an equal number " .
      " of elements separated by commas in each of the fields.<br>\n",
  };

  # curator
  $messages{ERROR_STATUS} = { 
    'color' => "$error", 
    'text' => "$param must have status $param to perform operation. <br>\n",
  };

  $messages{SUCCESS_ASSIGN} = { 
    'color' => "$success", 
    'text' => "Successfully assigned $param to $param2. <br>\n",
  };

  $messages{ERROR_ASSIGN_ORDER_NUMBER} = { 
    'color' => "$error", 
    'text' => "Unable to assign $param to $param2. <br>\n",
  };

  $messages{ERROR_LOAD_NO_ORDER_NUM} = { 
    'color' => "$error", 
    'text' => "You must assign an order number to the order prior to loading
      it. <br>\n",
  };

  $messages{ERROR_ASSIGN_ORDER_NUMBER} = { 
    'color' => "$error", 
    'text' => "Unable to assign order number as the order already has an " .
      "assigned order number ($param). <br>\n",
  };

  $messages{SUCCESS_ASSIGN_ORDER_NUMBER} = { 
    'color' => "$success", 
    'text' => "Order number $param was assigned to the order.<br>\n",
  };

  $messages{ERROR_NO_ORD_NUM_FORMAT} = { 
    'color' => "$error", 
    'text' => "No order number format is configured.  Contact the " .
      "administrator to configure an order number format via the " .
      "Configure GEOSS link. <br>\n",
  };

  
  if (!exists($messages{$key}))
  {
    $messages{$key} = { 
      'color' => "$error", 
      'text' => "Unable to determine message text for message $key.<br>\n",
    };
    warn "Unknown message: $key";
  }
  return $messages{$key};
}

1;
