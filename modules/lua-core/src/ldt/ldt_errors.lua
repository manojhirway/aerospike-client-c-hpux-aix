-- ===================
-- Standard LDT ERRORS
-- ===================

-- Note date and iteration of the last update:
local MOD="2014_04_04.A";

-- These errors align with the errors found in:
-- client/aerospike/src/include/aerospike/as_status.h
-- as_status.h::AEROSPIKE_ERR_LDT_INTERNAL == ldt_errors.lua::ERR_INTERNAL
local exports = {

  -- Special LDT Error Codes

  -- NOTE: We've changed "Top Rec" not found from 1415 to 2, to be 
  -- consistent with the rest of Aerospike KV convention (record not found).
  ERR_TOP_REC_NOT_FOUND    ="0002:LDT-Top Record Not Found",
  -- Also, we've changed the "Item Not Found" (1401) to 125, as this is now
  -- a real wire-protocol return code (must be less than 255).
  ERR_NOT_FOUND            ="0125:LDT-Item Not Found",

  -- Regular LDT Error Codes
  ERR_INTERNAL             ="1400:LDT-Internal Error",
  ERR_UNIQUE_KEY           ="1402:LDT-Unique Key or Value Violation",
  ERR_INSERT               ="1403:LDT-Insert Error",
  ERR_SEARCH               ="1404:LDT-Search Error",
  ERR_DELETE               ="1405:LDT-Delete Error",
  ERR_VERSION              ="1406:LDT-Version Mismatch Error",

  ERR_CAPACITY_EXCEEDED    ="1408:LDT-Capacity Exceeded",
  ERR_INPUT_PARM           ="1409:LDT-Input Parameter Error",

  ERR_TYPE_MISMATCH        ="1410:LDT-Type Mismatch for LDT Bin",
  ERR_NULL_BIN_NAME        ="1411:LDT-Null Bin Name",
  ERR_BIN_NAME_NOT_STRING  ="1412:LDT-Bin Name Not a String",
  ERR_BIN_NAME_TOO_LONG    ="1413:LDT-Bin Name Exceeds 14 char",
  ERR_TOO_MANY_OPEN_SUBRECS="1414:LDT-Exceeded Open Sub-Record Limit",
  ERR_SUB_REC_NOT_FOUND    ="1416:LDT-Sub Record Not Found",
  ERR_BIN_DOES_NOT_EXIST   ="1417:LDT-LDT Bin Does Not Exist",
  ERR_BIN_ALREADY_EXISTS   ="1418:LDT-LDT Bin Already Exists",
  ERR_BIN_DAMAGED          ="1419:LDT-LDT Bin is Damaged",

  ERR_SUBREC_POOL_DAMAGED  ="1420:LDT-Sub Record Pool is Damaged",
  ERR_SUBREC_DAMAGED       ="1421:LDT-Sub Record is Damaged",
  ERR_SUBREC_OPEN          ="1422:LDT-Sub Record Open Error",
  ERR_SUBREC_UPDATE        ="1423:LDT-Sub Record Update Error",
  ERR_SUBREC_CREATE        ="1424:LDT-Sub Record Create Error",
  ERR_SUBREC_DELETE        ="1425:LDT-Sub Record Delete Error",
  ERR_SUBREC_CLOSE         ="1426:LDT-Sub Record Close Error",
  ERR_TOPREC_UPDATE        ="1427:LDT-TOP Record Update Error",
  ERR_TOPREC_CREATE        ="1428:LDT-TOP Record Create Error",

  ERR_FILTER_BAD           ="1430:LDT-Bad Read Filter Name",
  ERR_FILTER_NOT_FOUND     ="1431:LDT-Read Filter Not Found",
  ERR_KEY_FUN_BAD          ="1432:LDT-Bad Key (Unique) Function Name",
  ERR_KEY_FUN_NOT_FOUND    ="1433:LDT-Key (Unique) Function Not Found",
  ERR_TRANS_FUN_BAD        ="1434:LDT-Bad Transform Function Name",
  ERR_TRANS_FUN_NOT_FOUND  ="1435:LDT-Transform Function Not Found",
  ERR_UNTRANS_FUN_BAD      ="1436:LDT-Bad UnTransform Function Name",
  ERR_UNTRANS_FUN_NOT_FOUND="1437:LDT-UnTransform Function Not Found",
  ERR_USER_MODULE_BAD      ="1438:LDT-Bad User Module Name",
  ERR_USER_MODULE_NOT_FOUND="1439:LDT-User Module Not Found"

} -- end exports section

-- Make this table visible to those importing the file.
return exports;

-- ldt_errors.lua
--
-- Use:  
-- local ldte = require('ldt_errors')
--
-- Use the error constant in the error() function.
-- error( ldte.ERR_INTERNAL );

