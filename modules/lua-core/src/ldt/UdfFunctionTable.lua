-- ======================================================================
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- || UDF FUNCTION TABLE ||
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================
-- UDF Function Table:
-- Version 08.08.0:    Last Update: (August 08, 2013) tjl

-- Keep this global value in sync with (above) version
local MOD="UdfFunctionTable_2014_06_14.B"; -- the module name used for tracing

-- Table of Functions: Used for Transformation and Filter Functions in
-- conjunction with Large Stack Objects (LSO) and Large Sets (LSET).
--
-- There is a new family of Aerospike Types and Functions that are
-- implemented with UDFs: Large Stack Objects (LSO) and Large Sets (LSET).
-- Some of these new functions take a UDF as a parameter, which is then
-- executed on the server side.  We pass those "inner" UDFs by name, and
-- and those names reference a function that is stored in a table. This
-- module defines those "inner" UDFs.
--
-- The Transform functions are IMPLICITLY set on create -- so that they
-- are done every time for values going IN and OUT.  Filters are optional
-- and thus may change per query/retrieval.
--
-- This table (currently) defines
-- (*) LSO Transform functions: Used for peek() and push()
-- (*) LSO Filter functions: Used for peek()
-- (*) LSET Transform functions: Used for insert(), exists() and select()
-- (*) LSET Filter functions: Used for exists() and select()
-- 
-- In order to pass functions as parameters in Lua (from C), we don't have
-- the ability to officially pass a true Lua function as a parameter to
-- the top level Lua function, so we instead pass the "inner" Lua function
-- by name, as a simple string.  That string corresponds to the names of
-- functions that are stored in this file, and the parameters to be fed
-- to the inner UDFs are passed in a list (arglist) to the outer UDF.
--
-- NOTE: These functions are not meant to be written by regular users.
-- It is the job of knowledgeable DB Administrators to write, review and
-- install both the top level UDFs and these "inner" UDFs on the Aerospike
-- server.  
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> !!!!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- >>>>> As a result, there are few protections against misuse or
-- >>>>> just plain bad coding.  So -- Users and Administrators Beware!!
-- >>>>>>>>>>>>>>>>>>>>>>>>>>>> !!!!!! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
--
-- ======================================================================
-- || GLOBAL PRINT ||
-- ======================================================================
-- Use this flag to enable/disable global printing (the "detail" level
-- in the server).
-- Usage: GP=F and trace()
-- When "F" is true, the trace() call is executed.  When it is false,
-- the trace() call is NOT executed (regardless of the value of GP)
-- ======================================================================
local GP;     -- We assign T or F to this to generate Global Print
local F=false; -- Set F (flag) to true to turn ON global print

-- ======================
-- || GLOBAL CONSTANTS || -- Local, but global to this module
-- ======================

-- ======================
-- || Imports (errors) ||
-- ======================
local ldte=require('ldt/ldt_errors');

-- ======================================================================
-- Usage:
--
-- From the main function table "functionTable", we can call any of the
-- functions defined here by passing its name and the associated arglist
-- that is supplied by the user.  For example, in stackPeekWithUDF, we
-- 
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
local UdfFunctionTable = {}

-- ======================================================================
-- Sample Filter function to test user entry 
-- Parms (encased in arglist)
-- (1) Entry List
-- ======================================================================
function UdfFunctionTable.transformFilter1( argList )
  local meth = "transformFilter1()";
  local resultList = list();
  local entryList = arglist[1]; 
  local entry = 0;
  GP=F and trace("[ENTER]: <%s:%s> EntryList(%s) \n",
                 MOD, meth, tostring(entryList));

  -- change EVERY entry that is > 200 to 0.
  for i = 1, list.size( entryList ) do
      GP=F and trace("[DEBUG]: <%s:%s> EntryList[%d](%s) \n",
        MOD, meth, i, tostring(entryList[i]));
    if entryList[i] > 200 then 
      GP=F and trace("[DEBUG]: <%s:%s> Setting Entry to ZERO \n", MOD, meth );
      entry = 0;
    else 
      GP=F and trace("[DEBUG]: <%s:%s> Setting Entry to entryList(%s) \n",
        MOD, meth, tostring(entryList[i]));
      entry = entryList[i];
    end
    list.append( resultList, entry );
    GP=F and trace("[DEBUG]: <%s:%s> List Append: Result:(%s) Entry(%s)\n",
                  MOD, meth, tostring(resultList[i]), tostring( entry));
  end

  GP=F and trace("[EXIT]: <%s:%s> Return with ResultList(%s) \n",
                MOD, meth, tostring(resultList));
  return resultList;
end
-- ======================================================================

-- ======================================================================
-- Function Range Filter: Performs a range query on one or more of the
-- entries in the list.
-- Parms (encased in arglist)
-- (1) arglist (Should include comparison details and parms)
-- (2) dbObject: The object we're comparing against
--
-- The rangeFilter will contain a LIST of MAPs, where each map contains
-- the data we need to evaluate each field:
-- (*) map.FieldName
-- (*) map.MinValue
-- (*) map.MaxValue
-- We use the Less Than or Equal Operator and Greater Than or Equal Operator
-- for this general-purpose range filter. Obviously, if a user wants
-- something else -- they should write their own specific filter, which will
-- no doubt be faster as well.
-- Return:
-- FILTER OK: Return Object
-- FILTER NO: Return nil.
-- ======================================================================
function UdfFunctionTable.rangeFilter( dbObject, arglist )
  local meth = "rangeFilter()";
  local result = true;

  GP=F and trace("[ENTER]: <%s:%s> ArgList(%s) dbObject(%s)",
                MOD, meth, tostring(arglist), tostring(dbObject));

  -- Check the "arglist" object -=- it must not be goofy.
  if( type( arglist ) ~= "userdata" ) then
    warn("[ERROR]<%s:%s> arglist is wrong type(%s)", MOD, meth, type(arglist));
    error( ldte.ERR_INTERNAL );
  end

  -- Iterate thru the parameters for each field
  local fieldMap;
  local dbValue;
  for i = 1, list.size( arglist ), 1 do
    fieldMap = arglist[i];
    if( fieldMap.FieldName == nil ) then
      warn("[ERROR]<%s:%s> FieldName is nil, iteration(%d)", MOD, meth, i );
      error( ldte.ERR_INTERNAL );
    end
    dbValue = dbObject[ fieldMap.FieldName ];
    if( dbValue == nil ) then
      result = false;
      break;
    end
    if( type(dbValue) == "userdata" ) then
      warn("[ERROR]<%s:%s> FieldName(%s)must be an atomic val", MOD, meth,
        tostring( fieldMap.FieldName ) )
      error( ldte.ERR_INTERNAL );
    end

    local lowVal = fieldMap.MinValue;
    local lowResult = (lowVal == nil) or (dbValue >= lowVal );
    local hiVal = fieldMap.MaxValue;
    local hiResult = (hiVal == nil) or (dbValue <= hiVal );

    if not( lowResult and hiResult ) then 
      result = false;
      break
    end
  end -- for each term in arglist
  
  GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, tostring(result));
  if result then
    return dbObject
  else
    return nil
  end

end -- rangeFilter
-- ======================================================================

-- ======================================================================
-- Function compressTest4: Compress a 4-part number list into a single
-- as_bytes value.  The Entry List is 4 numbers, which will be packed
-- into the following sizes:
-- 4 bytes, 4 bytes, 4 bytes and 4 bytes.
-- (1) Entry List
-- (2) arglist (args ignored in this function)
-- ======================================================================
function UdfFunctionTable.compressTest4( entryList, arglist )
  local meth = "compressTest4()";
  local rc = 0;
  GP=F and trace("[ENTER]: <%s:%s> EntryList(%s) ArgList(%s) \n",
                MOD, meth, tostring(entryList), tostring(arglist));

  local b16 = bytes(16);
  bytes.put_int32(b16, 1,  entryList[1] ); -- 4 byte int
  bytes.put_int32(b16, 5,  entryList[2] ); -- 4 byte int
  bytes.put_int32(b16, 9,  entryList[3] ); -- 4 byte int
  bytes.put_int32(b16, 13, entryList[4] ); -- 4 byte int

  GP=F and trace("[EXIT]: <%s:%s> b16 Result(%s) \n", MOD, meth, tostring(b16));
  return b16
end -- compressTest4()

-- ======================================================================
-- Function unCompressTest4: Uncompress a single 16 byte packed binary
-- object into 4 integer fields. The packed form is 4 4-byte values,
-- and the list is 4 number values
-- (1) b16: the packed byteObject
-- (2) arglist (args ignored in this function)
-- Return:
-- the entryList Tuple
-- ======================================================================
function UdfFunctionTable.unCompressTest4( b16, arglist )
  local meth = "unCompressTest4()";
  local rc = 0;
  GP=F and trace("[ENTER]: <%s:%s> packedB16(%s) ArgList(%s) \n",
                MOD, meth, tostring(b16), tostring(arglist));

  local entryList = list();
  entryList[1] = bytes.get_int32(b16, 1 ); -- 4 byte int
  entryList[2] = bytes.get_int32(b16, 5 ); -- 4 byte int
  entryList[3] = bytes.get_int32(b16, 9 ); -- 4 byte int
  entryList[4] = bytes.get_int32(b16, 13); -- 4 byte int

  GP=F and trace("[EXIT]:<%s:%s>Result(%s)", MOD, meth, tostring(entryList));
  return entryList;
end -- unCompressTest4()

-- ======================================================================
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ||                     Add New Functions Here.                      ||
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================

-- ======================================================================
-- Function testFilter1: 
-- ======================================================================
-- Test:  Print arguments and HELLO.
-- Parms (encased in arglist)
-- (1) Entry List
-- (2) Compression Field Parameters Table Index
-- ======================================================================
function UdfFunctionTable.testFilter1( arglist )
  local meth = "testFilter1()";
  GP=F and trace("[ENTER]: <%s:%s> ArgList(%s) \n",
                MOD, meth, tostring(arglist));

  local result = "Test Filter1 Hello";
  GP=F and trace("[DEBUG]: <%s:%s> Msg (%s) ArgList(%s) \n",
                MOD, meth, result, tostring(arglist));

  GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, result );

  return result;
end
-- ======================================================================

-- ======================================================================
-- Function compress4ByteInteger:
-- Compress a numeric value (8 byte lua floating point number) into a
-- 4 byte integer.  The lua value has a 56 byte mantissa, so we're ok to
-- move over the "bottom" four bytes.
-- (1) Lua Number (8 bytes in space, 56 bits mantissa)
-- (2) arglist (not used here)
-- Return:
-- The newly created Byte object, 4 bytes long
-- ======================================================================
function UdfFunctionTable.compress4ByteInteger( luaNumber, arglist )
  local meth = "compress4ByteInteger()";
  local rc = 0;
  GP=F and trace("[ENTER]: <%s:%s> Number(%s) ArgList(%s) \n",
                MOD, meth, tostring(luaNumber), tostring(arglist));

  local b4 = bytes(4);
  bytes.put_int32(b4, 1,  luaNumber[1] ); -- 4 byte int

  GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, tostring(b4));
  return b4;
end -- compress4ByteInteger()

-- ======================================================================
-- Function unCompress4ByteInteger: Uncompress a single 4 byte packed binary
-- object into an integer field.
-- (1) b4: the byteObject
-- (2) arglist (not used here)
-- Return:
-- the The Lua Number
-- ======================================================================
function UdfFunctionTable.unCompress4ByteInteger( b4, arglist )
  local meth = "unCompress4ByteInteger()";
  local rc = 0;
  -- protect against bad prints
  if arglist == nil then arglist = 0; end
  GP=F and trace("[ENTER]: <%s:%s> PackedNum(%s) ArgList(%s) \n",
                MOD, meth, tostring(b4), tostring(arglist));

  local luaNumber = bytes.get_int32(b4, 1 ); -- 4 byte int

  GP=F and trace("[EXIT]: <%s:%s> ResultNumber (%s) type(%s)\n",
                MOD, meth, tostring( luaNumber ));
  return luaNumber;
end -- unCompress4ByteInteger()

-- ======================================================================
-- Function listCompress4: Compress a 4 part tuple into a single 18 byte
-- value that we'll pack into storage.
-- The application creates a 4 part tuple, each part with
-- the following sizes: 4 bytes, 4 bytes, 8 bytes and 2 bytes.
-- (1) listTuple
-- (2) arglist
-- Return:
-- The newly created Byte object, 18 bytes long
-- ======================================================================
function UdfFunctionTable.listCompress_4_18( listTuple, arglist )
  local meth = "listCompress()";
  local rc = 0;
  GP=F and trace("[ENTER]: <%s:%s> tuple(%s) ArgList(%s) \n",
                MOD, meth, tostring(listTuple), tostring(arglist));

  local b18 = bytes(18);
  bytes.put_int32(b18, 1,  listTuple[1] ); -- 4 byte int
  bytes.put_int32(b18, 5,  listTuple[2] ); -- 4 byte int
  bytes.put_int64(b18, 9,  listTuple[3] ); -- 8 byte int
  bytes.put_int16(b18, 17, listTuple[4] ); -- 2 byte int

  GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, tostring(b18));
  return b18;
end -- listCompress_4_18( listTuple, arglist )

-- ======================================================================
-- Function listUnCompress_4_18: Uncompress a single 18 byte packed binary
-- object into 4 integer fields.
-- The application uses a 4 part tuple, each part with
-- the following sizes: 4 bytes, 4 bytes, 8 bytes and 2 bytes.
-- (1) b18: the byteObject
-- (2) arglist
-- Return:
-- the listTuple
-- ======================================================================
function UdfFunctionTable.listUnCompress_4_18( b18, arglist )
  local meth = "listUnCompress()";
  local rc = 0;
  -- protect against bad prints
  if arglist == nil then arglist = 0; end
  GP=F and trace("[ENTER]: <%s:%s> tuple(%s) Tuple Type(%s) ArgList(%s) \n",
                MOD, meth, tostring(b18), type(b18), tostring(arglist));

  local listTuple = list();
  listTuple[1] = bytes.get_int32(b18, 1 ); -- 4 byte int
  listTuple[2] = bytes.get_int32(b18, 5 ); -- 4 byte int
  listTuple[3] = bytes.get_int64(b18, 9 ); -- 8 byte int
  listTuple[4] = bytes.get_int16(b18, 17); -- 2 byte int

  GP=F and trace("[EXIT]: <%s:%s> Result(%s) type(%s)\n",
                MOD, meth, tostring(listTuple), type(listTuple ));
  return listTuple;
end -- listUnCompress_4_18
-- ======================================================================

-- ======================================================================
-- Function listCompress_5_18: Compress a 5 part tuple into a single 18 byte
-- value that we'll pack into storage.
-- The application creates a 5 part tuple, each part with
-- the following sizes: 4 bytes, 4 bytes, 4 bytes, 4 bytes and 2 bytes.
-- (1) listTuple
-- (2) arglist
-- Return:
-- The newly created Byte object, 18 bytes long
-- ====================================================================== 
function UdfFunctionTable.listCompress_5_18( listTuple, arglist )
  local meth = "listCompress_5_18()";
  local rc = 0;
  GP=F and trace("[ENTER]: <%s:%s> tuple(%s) ArgList(%s) ",
                MOD, meth, tostring(listTuple), tostring(arglist));

  local b18 = bytes(18);
  bytes.put_int32(b18, 1,  listTuple[1] ); -- 4 byte int
  bytes.put_int32(b18, 5,  listTuple[2] ); -- 4 byte int
  bytes.put_int32(b18, 9,  listTuple[3] ); -- 4 byte int
  bytes.put_int32(b18, 13, listTuple[4] ); -- 4 byte int
  bytes.put_int16(b18, 17, listTuple[5] ); -- 2 byte int

  GP=F and trace("[EXIT]: <%s:%s> BinaryResult(%s)", MOD, meth, tostring(b18));
  return b18;
end -- listCompress_5_18( listTuple, arglist )

-- ======================================================================
-- Function listUnCompress_5_18: Uncompress a single 18 byte packed binary
-- object into 5 integer fields.
-- The application uses a 4 part tuple, each part with
-- the following sizes: 4 bytes, 4 bytes, 4 bytes, 4 bytes and 2 bytes.
-- (1) b18: the byteObject
-- (2) arglist
-- Return:
-- the listTuple
-- ======================================================================
function UdfFunctionTable.listUnCompress_5_18( b18, arglist )
  local meth = "listUnCompress_5_18()";
  local rc = 0;
  -- protect against bad prints
  if arglist == nil then arglist = 0; end
  GP=F and trace("[ENTER]: <%s:%s> BinaryTuple(%s) TupleType(%s) ArgList(%s)",
              MOD, meth, tostring(b18), type(b18), tostring(arglist));

  local listTuple = list(5);
  -- NOTE: Must append.  Can't index directly into it.
  list.append( listTuple, bytes.get_int32(b18, 1 ));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b18, 5 ));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b18, 9 ));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b18, 13)); -- 4 byte int
  list.append( listTuple, bytes.get_int16(b18, 17));  -- 2 byte int

  --  conceptually -- this could also work:
  --  listTuple[1] = bytes.get_int32(b18, 1 );  -- 4 byte int
  --  listTuple[2] = bytes.get_int32(b18, 5 );  -- 4 byte int
  --  listTuple[3] = bytes.get_int32(b18, 9 );  -- 4 byte int
  --  listTuple[4] = bytes.get_int32(b18, 13 ); -- 4 byte int
  --  listTuple[5] = bytes.get_int16(b18, 17);  -- 2 byte int

  GP=F and trace("[EXIT]: <%s:%s> TupleResult(%s) type(%s)\n",
                MOD, meth, tostring(listTuple), type(listTuple ));
  return listTuple;
end -- listUnCompress_5_18()
-- ======================================================================


-- ======================================================================
-- Function listCompress_5_20: Compress a 5 part tuple into a single 20 byte
-- value that we'll pack into storage.
-- The application creates a 5 part tuple, each part with the
-- following sizes: 4 bytes, 4 bytes, 4 bytes, 4 bytes and 4 bytes.
-- (1) inputTuple
-- (2) arglist
-- Return:
-- The newly created Byte object, 20 bytes long
-- ====================================================================== 
function UdfFunctionTable.listCompress_5_20( inputTuple, arglist )
  local meth = "listCompress_5_20()";
  local rc = 0;
  GP=F and trace("[ENTER]: <%s:%s> tuple(%s) ArgList(%s) ",
                MOD, meth, tostring(listTuple), tostring(arglist));

  local b20 = bytes(20);
  bytes.put_int32(b20, 1,  inputTuple[1] ); -- 4 byte int
  bytes.put_int32(b20, 5,  inputTuple[2] ); -- 4 byte int
  bytes.put_int32(b20, 9,  inputTuple[3] ); -- 4 byte int
  bytes.put_int32(b20, 13, inputTuple[4] ); -- 4 byte int
  bytes.put_int32(b20, 17, inputTuple[5] ); -- 4 byte int

  GP=F and trace("[EXIT]: <%s:%s> BinaryResult(%s)", MOD, meth, tostring(b20));
  return b20;
end -- listCompress_5_20( listTuple, arglist )

-- ======================================================================
-- Function listUnCompress20: Uncompress a single 20 byte packed binary
-- object into 5 integer fields.
-- The application uses a 4 part tuple, each part with
-- the following sizes: 4 bytes, 4 bytes, 4 bytes, 4 bytes and 4 bytes.
-- (1) b20: the byteObject
-- (2) arglist
-- Return:
-- the listTuple
-- ======================================================================
function UdfFunctionTable.listUnCompress_5_20( b20, arglist )
  local meth = "listUnCompress_5_20()";
  local rc = 0;
  -- protect against bad prints
  if arglist == nil then arglist = 0; end
  GP=F and trace("[ENTER]<%s:%s> BinaryTuple(%s) TupleType(%s) ArgList(%s)",
                MOD, meth, tostring(b20), type(b20), tostring(arglist));

  local listTuple = list(5);
  -- NOTE: Must append.  Can't index directly into it.
  list.append( listTuple, bytes.get_int32(b20, 1 ));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b20, 5 ));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b20, 9 ));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b20, 13));  -- 4 byte int
  list.append( listTuple, bytes.get_int32(b20, 17));  -- 4 byte int

  GP=F and trace("[EXIT]: <%s:%s> TupleResult(%s) type(%s)\n",
                MOD, meth, tostring(listTuple), type(listTuple ));
  return listTuple;
end -- listUnCompress_5_20()
-- ======================================================================
--
-- ======================================================================
-- Extraction Functions (For Complex Objects)
-- ======================================================================
-- ======================================================================
-- Function keyExtract():  Return the simple "key" field.
-- For the simple key extraction, return the key value that is held in
-- the map key, "key".
-- Return:
-- (*) The value that is associated with the key "key".
-- ======================================================================
function UdfFunctionTable.keyExtract( objectValue )
   GP=F and trace("[ENTER] Extract Key from Object(%s)", tostring(objectValue));

  if objectValue == nil or objectValue["key"] == nil then
    return nil;
  else
    return objectValue.key;
  end
end -- keyExtract()
-- ======================================================================
--
-- ======================================================================
-- Compare Functions (For Sets and Lists)
-- ======================================================================

-- ======================================================================
-- Function keyCompareEqual():  Returns True or False
-- This a simple, default compare function that uses the KEY field in
-- a complex object (a map).  If the object is null or the KEY field
-- is not present, it returns NOT EQUAL.
-- (1) searchValue
-- (2) databaseValue
-- Return:
-- (*) true if the two objects are non-null and equal
-- (*) false otherwise.
-- ======================================================================
local KEY = 'KEY';
function UdfFunctionTable.keyCompareEqual( searchValue, databaseValue )
  local meth = "keyCompareEqual()";
  
  local result = true; -- be optimistic

  if searchValue == nil or databaseValue == nil or
     searchValue[KEY] == nil or databaseValue[KEY] == nil or
     searchValue[KEY] ~= databaseValue[KEY]
  then
    result = false;
  end

  GP=F and trace("[EXIT]: <%s:%s> SV(%s) == DV(%s) is Compare Result(%s) ",
      MOD, meth, tostring(searchValue), type(databaseValue),tostring(result));
  return result;
end -- keyCompareEqual()
-- ======================================================================

-- ======================================================================
-- Function debugListCompareEqual():  Returns True or False
-- This a simple list compare that just compares the FIRST element of
-- two lists -- to determine if they are equal or not.
-- (1) searchValue (a list)
-- (2) databaseValue (a list)
-- Return:
-- (*) true if the two objects are non-null and equal
-- (*) false otherwise.
-- NOTE that it will be easy to write a new function that looks at ALL
-- of the fields of the lists (also checks size) to do a true equal compare.
-- ======================================================================
local KEY = 'key';
function UdfFunctionTable.debugListCompareEqual( searchValue, databaseValue )
  local meth = "debugListCompareEqual()";
  
  local result = true; -- be optimistic

  -- Note: This might blow up if it's not a LIST type.  We'll have to add a
  -- check for that -- but type(SV) might only return "userdata".
  if searchValue == nil or databaseValue == nil or
    list.size( searchValue ) == 0 or list.size( databaseValue ) == 0 or 
    searchValue[1] ~= databaseValue[1]
  then
    result = false;
  end

  GP=F and trace("[EXIT]: <%s:%s> SV(%s) == DV(%s) is Compare Result(%s) ",
      MOD, meth, tostring(searchValue), type(databaseValue),tostring(result));
  return result;
end -- debugListCompareEqual()
-- ======================================================================

-- ======================================================================
-- Function keyHash():  Look at the Key type( number or string) and
-- perform the appropriate hash of this complex object
--
-- (1) complexObject
-- (2) modulo
-- Return:
-- a Number in the range: 0-modulo
-- NOTE: Must include the CRC32 module for this to work.
-- ======================================================================
function UdfFunctionTable.keyHash( complexObject, modulo )
  local meth = "keyHash()";

  local result = 0;
  if complexObject ~= nil and complexObject[KEY] ~= nil then
    result = CRC32.Hash( complexObject[KEY]) % modulo;
  end
  return result;
  
end -- keyHash()
-- ======================================================================

-- ======================================================================
-- Function compressNumber: Compress an 8 byte Lua number into a 2 byte
-- number.  We can do this because we know the values will be less than 
-- 2^16 (64k).
-- Parms:
-- (1) numberObject:
-- (2) arglist (args ignored in this function)
-- Return: the two byte (compressed) byte object.
-- ======================================================================
function UdfFunctionTable.compressNumber( numberObject, arglist )
local meth = "compressNumber()";
GP=F and trace("[ENTER]: <%s:%s> numberObject(%s) ArgList(%s) \n",
  MOD, meth, tostring(numberObject), tostring(arglist));

local b2 = bytes(2);
bytes.put_int16(b2, 1,  numberObject ); -- 2 byte int

GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, tostring(b2));
return b2;
end -- compressNumber()

-- ======================================================================
-- Function unCompressNumber:  Restore a Lua number from a compressed
-- 2 byte value.
-- Parms:
-- (1) b2: 2 byte number
-- (2) arglist (args ignored in this function)
-- Return: the regular Lua Number
-- ======================================================================
-- ======================================================================
function UdfFunctionTable.unCompressNumber( b2, arglist )
local meth = "unCompressNumber()";
GP=F and trace("[ENTER]: <%s:%s> packedB2(%s) ArgList(%s) \n",
              MOD, meth, tostring(b2), tostring(arglist));

local numberObject = bytes.get_int16(b2, 1 ); -- 2 byte int

GP=F and trace("[EXIT]<%s:%s>Result(%s)",MOD,meth,tostring(numberObject));
return numberObject;
end -- unCompressNumber()

-- ======================================================================
-- This is needed to export the function table for this module
-- Leave this statement at the end of the module.
-- ==> Define all functions before this end section.
-- ======================================================================
return UdfFunctionTable;
-- ======================================================================
--
-- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> --
