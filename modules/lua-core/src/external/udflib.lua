-- General UDF and LDT Library Functions
--
-- ======================================================================
-- Copyright [2014] Aerospike, Inc.. Portions may be licensed
-- to Aerospike, Inc. under one or more contributor license agreements.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--  http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ======================================================================

-- ======================================================================
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- || UDF LIBRARY ||           
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================
-- Track the latest change to this module:
local MOD="UdfLib_2014_05_27.A";

-- This module contains a Library of Functions that are used for general
-- operations in Aerospike.  The types of functions are:
-- (1) Range Predicate evaluation
-- (2) Object Compression
-- (3) ... TBD
--
-- These functions are EXTERNALLY defined, meaning they are visible to
-- be called as first class functions in the form: Module.function().
-- So, if I want to call the range_predicate function, I would call it as
-- udflib.range_predicate()
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
local GP=true; -- Leave this set to true.
local F=true; -- Set F (flag) to true to turn ON global print

-- Draw from the UdfFunctionTable, which may contain some useful inner
-- functions.
-- local UdfFunctionTable=require('ldt/UdfFunctionTable');
-- local udfe=require('udf/udf_errors');
--  Use Local Errors for now
local ERR_INTERNAL = -1500;

-- ======================================================================
-- Function Range Predicate: Performs a range query on one or more of the
-- entries in the list.
--
-- Current Limitations:
-- (*)  All predicates are implicitely ANDed together.
-- (*) Upper and Lower bounds INCLUDE the end point (>=, <=)
--
-- The range_predicate function will contain a LIST of MAPs (predicateMap)
-- where each map contains the data we need to evaluate each bin.
-- (*) map.BinName
-- (*) map.BottomValue
-- (*) map.TopValue
--
-- Parms (encased in arglist)
-- (1) as_rec: The Aerospike Record
-- (2) arglist (Should include comparison details and parms)
-- Return:
-- True if record satisfied predicate
-- False if record does NOT satisfy predicate
-- ======================================================================
function range_predicate( as_rec, arglist )
  local meth = "range_predicate()";
  local result = true;

  GP=F and trace("[ENTER]: <%s:%s> ArgList(%s)", MOD, meth, tostring(arglist));

  -- Check the "arglist" object -=- it must not be goofy.
  if( type( arglist ) ~= "userdata" ) then
    warn("[ERROR]<%s:%s> arglist is wrong type(%s)", MOD, meth, type(arglist));
    error( ERR_INTERNAL );
  end

  -- Iterate thru the parameters for each field
  local predicateMap;
  local binValue;
  for i = 1, list.size( arglist ), 1 do
    predicateMap = arglist[i];
    if( predicateMap.BinName == nil ) then
      warn("[ERROR]<%s:%s> BinName is nil, iteration(%d)", MOD, meth, i );
      error( ERR_INTERNAL );
    end
    binValue = as_rec[ predicateMap.BinName ];
    if( type(binValue) == "userdata" ) then
      warn("[ERROR]<%s:%s> Bin(%s) must contain an atomic val", MOD, meth,
        tostring( predicateMap.BinName ) )
      error( ERR_INTERNAL );
    end

    local lowVal = predicateMap.BottomValue;
    local lowResult = (lowVal == nil) or (binValue >= lowVal );
    local hiVal = predicateMap.TopValue;
    local hiResult = (hiVal == nil) or (binValue <= hiVal );

    if not( lowResult and hiResult ) then 
      result = false;
      break
    end
  end -- for each term in arglist
  
  GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, tostring(result));
  return result;

end -- range_predicate()

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
function keyCompareEqual( searchValue, databaseValue )
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
function debugListCompareEqual( searchValue, databaseValue )
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
function keyHash( complexObject, modulo )
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
function compressNumber( numberObject, arglist )
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
function unCompressNumber( b2, arglist )
local meth = "unCompressNumber()";
GP=F and trace("[ENTER]: <%s:%s> packedB2(%s) ArgList(%s) \n",
              MOD, meth, tostring(b2), tostring(arglist));

local numberObject = bytes.get_int16(b2, 1 ); -- 2 byte int

GP=F and trace("[EXIT]<%s:%s>Result(%s)",MOD,meth,tostring(numberObject));
return numberObject;
end -- unCompressNumber()

-- ======================================================================
-- Stream Functions (Filters, Maps and Reducers)
-- ======================================================================
--

-- ======================================================================
-- STREAM: Range Predicate
-- ======================================================================
-- Range Filter: Performs a range query on one or more of the
-- entries in the list.
--
-- Current Limitations:
-- (*)  All predicates are implicitely ANDed together.
-- (*) Upper and Lower bounds INCLUDE the end point (>=, <=)
--
-- The range_filter function will contain a LIST of MAPs (predicateMap)
-- where each map contains the data we need to evaluate each bin.
-- (*) map.BinName
-- (*) map.BottomValue
-- (*) map.TopValue
--
-- Parms:
-- (1) as_rec: The Aerospike Record
-- (2) predList (Should include comparison details and parms)
-- ======================================================================
-- Return:
-- True if record satisfied predicate
-- False if record does NOT satisfy predicate
-- ======================================================================
local function range_filter( as_rec, predList )
  local meth = "range_filter()";
  local result = true;

  GP=F and trace("[ENTER]: <%s:%s> Predicate List(%s)",
      MOD, meth, tostring(predList));

  -- Check the "predList" object -=- it must not be goofy.
  if( type( predList ) ~= "userdata" ) then
    warn("[ERROR]<%s:%s> Predicate List is wrong type(%s)",
      MOD, meth, type(predList));
    error( ERR_INTERNAL );
  end

  -- Iterate thru the parameters for each field
  local predicateMap;
  local binValue;
  for i = 1, list.size( predList ), 1 do
    predicateMap = predList[i];
    if( predicateMap.BinName == nil ) then
      warn("[ERROR]<%s:%s> BinName is nil, iteration(%d)", MOD, meth, i );
      error( ERR_INTERNAL );
    end
    binValue = as_rec[ predicateMap.BinName ];
    if( type(binValue) == "userdata" ) then
      warn("[ERROR]<%s:%s> Bin(%s) must contain an atomic val", MOD, meth,
        tostring( predicateMap.BinName ) )
      error( ERR_INTERNAL );
    end

    local lowVal = predicateMap.BottomValue;
    local lowResult = (lowVal == nil) or (binValue >= lowVal );
    local hiVal = predicateMap.TopValue;
    local hiResult = (hiVal == nil) or (binValue <= hiVal );

    if not( lowResult and hiResult ) then 
      result = false;
      break
    end
  end -- for each term in predList
  
  GP=F and trace("[EXIT]: <%s:%s> Result(%s) \n", MOD, meth, tostring(result));
  return result;

end -- range_filter()

-- ======================================================================
-- Apply Range Filter
-- ======================================================================
-- Call the predicate filter with a given predicate list that is
-- a list of maps, where each map applies a range filter to a bin.
-- ======================================================================
function apply_range_filter(s, predList)
  local meth = "range_filter()";
  local result = true;

  GP=F and trace("[ENTER]: <%s:%s> Predicate List(%s)",
      MOD, meth, tostring(predList));

  -- Process the Record Stream
  return s : filter( range_filter, predList )

end -- end apply_range_filter()

local MOD="2014_09_03.A";

-- ======================================================================
-- LMap Expire Filter
-- ======================================================================
-- This Filter is intended to sift thru LMAP objects and return all items
-- that have an expire number that is past the expiration date passed in.
--
-- Map Objects have the form:
-- (*) expire: Expire Time (in milliseconds) 
-- (*) name: User Name
-- (*) URL: Site Visited
-- (*) referrer: ??
-- (*) page_title: URL Page Title
-- (*) date: Operation Time (in milliseconds)

-- Parms:
-- (1) liveObject: The LMap Object
-- (2) expireValue: the expire number
-- ======================================================================
-- Return:
-- a resultMap of all items that satisfy the filter
-- Nil if nothing satisfies.
-- ======================================================================
function expire_filter( liveObject, expireValue )
  local meth = "expire_filter()";

  GP=F and trace("[ENTER]: <%s:%s> Object(%s) ExpireValue(%s)",
    MOD, meth, tostring(liveObject), tostring(expireValue));

  -- Check the "expireValue" object -=- it must be a valid number.
  if( not expireValue ) then
    warn("[ERROR]<%s:%s> Expire Value is NIL", MOD, meth);
    error("NIL Expire Value");
  end

  if( type( expireValue ) ~= "number" ) then
    warn("[ERROR]<%s:%s> Expire Value is wrong type(%s)",
      MOD, meth, type(expireValue));
    error("BAD Expire Value");
  end

  -- We expect that the "live object" is a map.  Validate that it is
  -- "userdata", specifically of type "Map", and has a field called "expire".
  -- Then, and ONLY then, we'll check the value.
  if( not liveObject ) then
    warn("[ERROR]<%s:%s> DB Object Value is NIL", MOD, meth);
    error("NIL DB Object");
  end

  if( type( liveObject ) ~= "userData" or
     getmetatable( liveObject ) ~= getmetatable( map() )) then
    warn("[ERROR]<%s:%s> Live Object NOT Map Type(%s)",
      MOD, meth, type(liveObject));
    error("BAD DB Object Type");
  end

  local objExpire = liveObject["expire"];
  if not objExpire then
    warn("[ERROR]<%s:%s> DB Object Value Has No Expire Value", MOD, meth);
    error("Object has Empty Expire Field");
  end

  info("[Value Check]<%s:%s> DB Expire(%d) Parm Expire(%d)", MOD, meth,
    objExpire, expireValue );
  if objExpire < expireValue then
    GP=F and trace("[EXIT]<%s:%s> Result(%s)", MOD, meth, tostring(liveObject));
    return liveObject;
  end

  GP=F and trace("[EXIT]<%s:%s> NIL Result", MOD, meth);
  return nil;
end -- range_filter()


-- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> --
