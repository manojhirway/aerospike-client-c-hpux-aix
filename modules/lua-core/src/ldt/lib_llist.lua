-- Large Ordered List (llist.lua)
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

-- Track the date and iteration of the last update:
local MOD="lib_llist_2014_11_25.J";

-- This variable holds the version of the code. It should match the
-- stored version (the version of the code that stored the ldtCtrl object).
-- If there's a mismatch, then some sort of upgrade is needed.
-- This number is currently an integer because that is all that we can
-- store persistently.  Ideally, we would store (Major.Minor), but that
-- will have to wait until later when the ability to store real numbers
-- is eventually added.
local G_LDT_VERSION = 2;

-- ======================================================================
-- || GLOBAL PRINT and GLOBAL DEBUG ||
-- ======================================================================
-- Use these flags to enable/disable global printing (the "detail" level
-- in the server).
-- Usage: GP=F and trace()
-- When "F" is true, the trace() call is executed.  When it is false,
-- the trace() call is NOT executed (regardless of the value of GP)
-- (*) "F" is used for general debug prints
-- (*) "E" is used for ENTER/EXIT prints
-- (*) "B" is used for BANNER prints
-- (*) "D" is used for Basic DEBUG prints
-- (*) DEBUG is used for larger structure content dumps.
-- ======================================================================
local GP;      -- Global Print/debug Instrument
local F=false; -- Set F (flag) to true to turn ON global print
local E=false; -- Set F (flag) to true to turn ON Enter/Exit print
local B=false; -- Set B (Banners) to true to turn ON Banner Print
local D=false; -- Set D (Detail) to get more Detailed Debug Output.
local DEBUG=false; -- turn on for more elaborate state dumps and checks.

-- ======================================================================
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- Large List (LLIST) Library Functions
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================
-- (*) Status = llist.add(topRec, ldtBinName, newValue, userModule, src)
-- (*) Status = llist.add_all(topRec, ldtBinName, valueList, userModule, src)
-- (*) Status = llist.update(topRec, ldtBinName, newValue, src)
-- (*) Status = llist.update_all(topRec, ldtBinName, valueList, src)
-- (*) List   = llist.find(topRec,ldtBinName,val,userModule,filter,fargs, src)
-- ( ) Object = llist.find_min(topRec,ldtBinName, src)
-- ( ) Object = llist.find_max(topRec,ldtBinName, src)
-- ( ) Number = llist.exists(topRec, ldtBinName, val, src)
-- ( ) List   = llist.take(topRec,ldtBinName,val,userModule,filter,fargs, src)
-- ( ) Object = llist.take_min(topRec,ldtBinName, src)
-- ( ) Object = llist.take_max(topRec,ldtBinName, src)
-- (*) List   = llist.range(tr,bin,loVal,hiVal, userModule,filter,fargs,src)
-- (*) List   = llist.filter(topRec,ldtBinName,userModule,filter,fargs,src)
-- (*) List   = llist.scan(topRec, ldtBinName, userModule, filter, fargs, src)
-- (*) Status = llist.remove(topRec, ldtBinName, searchValue  src) 
-- (*) Status = llist.remove_all(topRec, ldtBinName, valueList  src) 
-- (*) Status = llist.remove_range(topRec, ldtBinName, minKey, maxKey, src)
-- (*) Status = llist.destroy(topRec, ldtBinName, src)
-- (*) Number = llist.size(topRec, ldtBinName )
-- (*) Map    = llist.config(topRec, ldtBinName )
-- (*) Status = llist.set_capacity(topRec, ldtBinName, new_capacity)
-- (*) Status = llist.get_capacity(topRec, ldtBinName )
-- (*) Number = llist.ldt_exists(topRec, ldtBinName)
-- ======================================================================
-- The following functions under construction:
-- (-) Object = llist.find_min(topRec,ldtBinName, src)
-- (-) Object = llist.find_max(topRec,ldtBinName, src)
-- (-) List   = llist.take(topRec,ldtBinName,key,userModule,filter,fargs, src)
-- (-) Object = llist.take_min(topRec,ldtBinName, src)
-- (-) Object = llist.take_max(topRec,ldtBinName, src)
-- ======================================================================
--
-- Large List Design/Architecture
--
-- The Large Ordered List is a sorted list, organized according to a Key
-- value.  It is assumed that the stored object is more complex than just an
-- atomic key value -- otherwise one of the other Large Object mechanisms
-- (e.g. Large Stack, Large Set) would be used.  The cannonical form of a
-- LLIST object is a map, which includes a KEY field and other data fields.
--
-- In this first version, we may choose to use a FUNCTION to derrive the 
-- key value from the complex object (e.g. Map).
-- In the first iteration, we will use atomic values and the fixed KEY field
-- for comparisons.
--
-- Compared to Large Stack and Large Set, the Large Ordered List is managed
-- continuously (i.e. it is kept sorted), so there is some additional
-- overhead in the storage operation (to do the insertion sort), but there
-- is reduced overhead for the retieval operation, since it is doing a
-- binary search (order log(N)) rather than scan (order N).
-- ======================================================================
-- >> Please refer to ldt/doc_llist.md for architecture and design notes.
-- ======================================================================

-- ======================================================================
-- Aerospike Database Server Functions:
-- ======================================================================
-- Aerospike Record Functions:
-- status = aerospike:create( topRec )
-- status = aerospike:update( topRec )
-- status = aerospike:remove( topRec ) (not currently used)
--
-- Aerospike SubRecord Functions:
-- newRec = aerospike:create_subrec( topRec )
-- rec    = aerospike:open_subrec( topRec, digestString )
-- status = aerospike:update_subrec( childRec )
-- status = aerospike:close_subrec( childRec )
-- status = aerospike:remove_subrec( subRec ) 
--
-- Record Functions:
-- digest = record.digest( childRec )
-- status = record.set_type( topRec, recType )
-- status = record.set_flags( topRec, ldtBinName, binFlags )
-- ======================================================================

-- ======================================================================
-- FORWARD Function DECLARATIONS
-- ======================================================================
-- We have some circular (recursive) function calls, so to make that work
-- we have to predeclare some of them here (they look like local variables)
-- and then later assign the function body to them.
-- ======================================================================
local insertParentNode;
local nodeDelete;

-- ++==================++
-- || External Modules ||
-- ++==================++
-- Set up our "outside" links.
-- Get addressability to the Function Table: Used for compress/transform,
-- keyExtract, Filters, etc. 
local functionTable = require('ldt/UdfFunctionTable');

-- We import all of our error codes from "ldt_errors.lua" and we access
-- them by prefixing them with "ldte.XXXX", so for example, an internal error
-- return looks like this:
-- error( ldte.ERR_INTERNAL );
local ldte = require('ldt/ldt_errors');

-- We have a set of packaged settings for each LDT
local llistPackage = require('ldt/settings_llist');

-- We have recently moved a number of COMMON functions into the "ldt_common"
-- module, namely the subrec routines and some list management routines.
-- We will likely move some other functions in there as they become common.
local ldt_common = require('ldt/ldt_common');

-- These values should be "built-in" for our Lua, but it is either missing
-- or inconsistent, so we define it here.  We use this when we check to see
-- if a value is a LIST or a MAP.
local Map = getmetatable( map() );
local List = getmetatable( list() );

-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- || FUNCTION TABLE ||
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- Table of Functions: Used for Transformation and Filter Functions.
-- This is held in UdfFunctionTable.lua.  Look there for details.
-- ===========================================
-- || GLOBAL VALUES -- Local to this module ||
-- ===========================================
-- ++====================++
-- || INTERNAL BIN NAMES || -- Local, but global to this module
-- ++====================++
-- The Top Rec LDT bin is named by the user -- so there's no hardcoded name
-- for each used LDT bin.
--
-- In the main record, there is one special hardcoded bin -- that holds
-- some shared information for all LDTs.
-- Note the 14 character limit on Aerospike Bin Names.
-- >> (14 char name limit) >>12345678901234<<<<<<<<<<<<<<<<<<<<<<<<<
local REC_LDT_CTRL_BIN    = "LDTCONTROLBIN"; -- Single bin for all LDT in rec

-- There are THREE different types of (Child) subrecords that are associated
-- with an LLIST LDT:
-- (1) Internal Node Subrecord:: Internal nodes of the B+ Tree
-- (2) Leaf Node Subrecords:: Leaf Nodes of the B+ Tree
-- (3) Existence Sub Record (ESR) -- Ties all children to a parent LDT
-- Each Subrecord has some specific hardcoded names that are used
--
-- All LDT subrecords have a properties bin that holds a map that defines
-- the specifics of the record and the LDT.
-- NOTE: Even the TopRec has a property map -- but it's stashed in the
-- user-named LDT Bin
-- >> (14 char name limit) >>12345678901234<<<<<<<<<<<<<<<<<<<<<<<<<
local SUBREC_PROP_BIN     = "SR_PROP_BIN";
--
-- The Node SubRecords (NSRs) use the following bins:
-- The SUBREC_PROP_BIN mentioned above, plus 3 of 4 bins
-- >> (14 char name limit) >>12345678901234<<<<<<<<<<<<<<<<<<<<<<<<<
local NSR_CTRL_BIN        = "NsrControlBin";
local NSR_KEY_LIST_BIN    = "NsrKeyListBin"; -- For Var Length Keys
local NSR_KEY_BINARY_BIN  = "NsrBinaryBin";-- For Fixed Length Keys
local NSR_DIGEST_BIN      = "NsrDigestBin"; -- Digest List

-- The Leaf SubRecords (LSRs) use the following bins:
-- The SUBREC_PROP_BIN mentioned above, plus
-- >> (14 char name limit) >>12345678901234<<<<<<<<<<<<<<<<<<<<<<<<<
local LSR_CTRL_BIN        = "LsrControlBin";
local LSR_LIST_BIN        = "LsrListBin";
local LSR_BINARY_BIN      = "LsrBinaryBin";

-- The Existence Sub-Records (ESRs) use the following bins:
-- The SUBREC_PROP_BIN mentioned above (and that might be all)

-- ++==================++
-- || MODULE CONSTANTS ||
-- ++==================++
-- Each LDT defines its type in string form.
local LDT_TYPE = "LLIST";

-- For Map objects, we may look for a special KEY FIELD
local KEY_FIELD  = "key";

-- << DEFAULTS >>
-- Settings for the initial state
local DEFAULT = {
  -- Switch from a single list to B+ Tree after this amount
  THRESHOLD = 10;

  -- Switch Back to a Compact List if we drop below this amount.
  -- We want to maintain a little hysteresis so that we don't thrash
  -- back and forth between CompactMode and Regular Mode
  REV_THRESHOLD = 8;

  -- Starting value for a ROOT NODE (in terms of # of keys)
  ROOT_MAX = 100;

  -- Starting value for an INTERNAL NODE (in terms of # of keys)
  NODE_MAX = 200;

  -- Starting value for a LEAF NODE (in terms of # of objects)
  LEAF_MAX = 100;
};

-- Conventional Wisdom says that lists smaller than 20 are searched faster
-- with LINEAR SEARCH, and larger lists are searched faster with
-- BINARY SEARCH.   Experiment with this value.
local LINEAR_SEARCH_CUTOFF = 20;

-- Use this to test for LdtMap Integrity.  Every map should have one.
local MAGIC="MAGIC";     -- the magic value for Testing LLIST integrity

-- AS_BOOLEAN TYPE:
-- There are apparently either storage or conversion problems with booleans
-- and Lua and Aerospike, so rather than STORE a Lua Boolean value in the
-- LDT Control map, we're instead going to store an AS_BOOLEAN value, which
-- is a character (defined here).  We're using Characters rather than
-- numbers (0, 1) because a character takes ONE byte and a number takes EIGHT
local AS_TRUE='T';
local AS_FALSE='F';

-- StoreMode (SM) values (which storage Mode are we using?)
local SM_BINARY  ='B'; -- Using a Transform function to compact values
local SM_LIST    ='L'; -- Using regular "list" mode for storing values.

-- StoreState (SS) values (which "state" is the set in?)
local SS_COMPACT ='C'; -- Using "single bin" (compact) mode
local SS_REGULAR ='R'; -- Using "Regular Storage" (regular) mode

-- KeyType (KT) values
local KT_ATOMIC  ='A'; -- the set value is just atomic (number or string)
local KT_COMPLEX ='C'; -- the set value is complex. Use Function to get key.
local KT_NONE    ='N'; -- Start with "No Value", and set on first insert.

-- KeyDataType (KDT) value
local KDT = {
  NUMBER = 'N'; -- The key (or derived key) is a NUMBER
  STRING = 'S'; -- The key (or derived key) is a STRING
  BYTES  = 'B'; -- The key (or derived key) is a BYTE array
};

-- << Search Constants >>
-- Use Numbers so that it translates to our C conventions
local ST = {
  FOUND     =  0,
  NOT_FOUND = -1
};

-- Values used in Compare (CR = Compare Results)
local CR = {
  LESS_THAN      = -1,
  EQUAL          =  0,
  GREATER_THAN   =  1,
  ERROR          = -2,
  INTERNAL_ERROR = -3
};

-- Errors used in Local LDT Land (different from the Global LDT errors that
-- are managed in the ldte module).
local ERR = {
  OK            =  0, -- HEY HEY!!  Success
  GENERAL       = -1, -- General Error
  NOT_FOUND     = -2  -- Search Error
};

-- Scan Status:  Do we keep scanning, or stop?
local SCAN = {
  ERROR        = -1,  -- Error during Scanning
  DONE         =  0,  -- Done scanning
  CONTINUE     =  1   -- Keep Scanning
};

-- Record Types -- Must be numbers, even though we are eventually passing
-- in just a "char" (and int8_t).
-- NOTE: We are using these vars for TWO purposes:
-- (1) As a flag in record.set_type() -- where the index bits need to show
--     the TYPE of record (RT.LEAF NOT used in this context)
-- (2) As a TYPE in our own propMap[PM.RecType] field: CDIR *IS* used here.
local RT = {
  REG  = 0, -- 0x0: Regular Record (Here only for completeneness)
  LDT  = 1, -- 0x1: Top Record (contains an LDT)
  NODE = 2, -- 0x2: Regular Sub Record (Node, Leaf)
  SUB  = 2, -- 0x2: Regular Sub Record (Node, Leaf)::Used for set_type
  LEAF = 3, -- xxx: Leaf Nodes:: Not used for set_type() 
  ESR  = 4  -- 0x4: Existence Sub Record
};

-- Bin Flag Types -- to show the various types of bins.
-- NOTE: All bins will be labelled as either (1:RESTRICTED OR 2:HIDDEN)
-- We will not currently be using "Control" -- that is effectively HIDDEN
local BF = {
  LDT_BIN     = 1; -- Main LDT Bin (Restricted)
  LDT_HIDDEN  = 2; -- LDT Bin::Set the Hidden Flag on this bin
  LDT_CONTROL = 4; -- Main LDT Control Bin (one per record)
};

-- In order to tell the Server what's happening with LDT (and maybe other
-- calls), we call "set_context()" with various flags.  The server then
-- uses this to measure LDT call behavior.
local UDF_CONTEXT_LDT = 1;

-- ------------------------------------------------------------------------
-- Control Map Names: for Property Maps and Control Maps
-- ------------------------------------------------------------------------
-- Note:  All variables that are field names will be upper case.
-- It is EXTREMELY IMPORTANT that these field names ALL have unique char
-- values -- within any given map.  They do NOT have to be unique across
-- the maps (and there's no need -- they serve different purposes).
-- Note that we've tried to make the mapping somewhat cannonical where
-- possible. 
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Record Level Property Map (RPM) Fields: One RPM per record
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
local RPM = {
  LdtCount             = 'C';  -- Number of LDTs in this rec
  VInfo                = 'V';  -- Partition Version Info
  Magic                = 'Z';  -- Special Sauce
  SelfDigest           = 'D';  -- Digest of this record
};

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- LDT specific Property Map (PM) Fields: One PM per LDT bin:
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
local PM = {
  ItemCount             = 'I', -- (Top): Count of all items in LDT
  Version               = 'V', -- (Top): Code Version
  SubRecCount           = 'S', -- (Top): # of subrecs in the LDT
  LdtType               = 'T', -- (Top): Type: stack, set, map, list
  BinName               = 'B', -- (Top): LDT Bin Name
  Magic                 = 'Z', -- (All): Special Sauce
  CreateTime            = 'C', -- (All): Creation time of this rec
  EsrDigest             = 'E', -- (All): Digest of ESR
  RecType               = 'R', -- (All): Type of Rec:Top,Ldr,Esr,CDir
  SelfDigest            = 'D', -- (All): Digest of THIS Record
  ParentDigest          = 'P'  -- (Subrec): Digest of TopRec
  -- LogInfo    ....    = 'L', -- (All): Log Info (currently unused)
};

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Leaf and Node Fields (There is some overlap between nodes and leaves)
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
local LF_ListEntryCount       = 'L';-- # current list entries used
local LF_ListEntryTotal       = 'T';-- # total list entries allocated
local LF_ByteEntryCount       = 'B';-- # current bytes used
local LF_PrevPage             = 'P';-- Digest of Previous (left) Leaf Page
local LF_NextPage             = 'N';-- Digest of Next (right) Leaf Page

local ND_ListEntryCount       = 'L';-- # current list entries used
local ND_ListEntryTotal       = 'T';-- # total list entries allocated
local ND_ByteEntryCount       = 'B';-- # current bytes used

-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- Main LLIST LDT Record (root) Map Fields
-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- These Common Field Values must match ALL of the other LDTs
--
-- Fields Common to ALL LDTs (managed by the LDT COMMON routines)
-- (Ldt Common --> LC)
local LC = {
  UserModule          = 'P';-- User's Lua file for overrides
  KeyFunction         = 'F';-- Function to compute Key from Object
  KeyType             = 'k';-- Type of key (atomic, complex)
  StoreMode           = 'M';-- SM_LIST or SM_BINARY (applies to all nodes)
  StoreLimit          = 'L';-- Storage Capacity Limit
  Transform           = 't';-- Transform Object (from User to bin store)
  UnTransform         = 'u';-- Reverse transform (from storage to user)
  OverWrite           = 'o';-- Allow Overwrite (AS_TRUE or AS_FALSE)
                            -- Implicitly true for LLIST
};

-- Fields Specific to LLIST LDTs (Ldt Specific --> LS)
local LS = {
  -- Tree Level values
  -- TotalCount          = 'T';-- A count of all "slots" used in LLIST
  LeafCount           = 'c';-- A count of all Leaf Nodes
  NodeCount           = 'C';-- A count of all Nodes (including Leaves)
  TreeLevel           = 'l';-- Tree Level (Root::Inner nodes::leaves)
  KeyDataType         = 'd';-- Data Type of key (Number, Integer)
  KeyUnique           = 'U';-- Are Keys Unique? (AS_TRUE or AS_FALSE))
  StoreState          = 'S';-- Compact or Regular Storage
  Threshold           = 'H';-- After this#:Move from compact to tree mode
  RevThreshold        = 'V';-- Drop back into Compact Mode at this pt.
  KeyField            = 'f';-- Key Field to use as key
  -- Key and Object Sizes, when using fixed length (byte array stuff)
  KeyByteSize         = 'B';-- Fixed Size (in bytes) of Key
  ObjectByteSize      = 'b';-- Fixed Size (in bytes) of Object
  -- Top Node Tree Root Directory
  RootListMax         = 'R'; -- Length of Key List (page list is KL + 1)
  RootByteCountMax    = 'r';-- Max # of BYTES for keyspace in the root
  KeyByteArray        = 'J'; -- Byte Array, when in compressed mode
  DigestByteArray     = 'j'; -- DigestArray, when in compressed mode
  RootKeyList         = 'K';-- Root Key List, when in List Mode
  RootDigestList      = 'D';-- Digest List, when in List Mode
  CompactList         = 'Q';--Simple Compact List -- before "tree mode"
  -- LLIST Inner Node Settings
  NodeListMax         = 'X';-- Max # of items in a node (key+digest)
  NodeByteCountMax    = 'Y';-- Max # of BYTES for keyspace in a node
  -- LLIST Tree Leaves (Data Pages)
  LeafListMax         = 'x';-- Max # of items in a leaf node
  LeafByteCountMax    = 'y';-- Max # of BYTES for obj space in a leaf
  LeftLeafDigest      = 'A';-- Record Ptr of Left-most leaf
  RightLeafDigest     = 'Z';-- Record Ptr of Right-most leaf
};


-- ------------------------------------------------------------------------
-- Maintain the Field letter Mapping here, so that we never have a name
-- collision: Obviously -- only one name can be associated with a character.
-- We won't need to do this for the smaller maps, as we can see by simple
-- inspection that we haven't reused a character.
-- ----------------------------------------------------------------------
-- A:LS.LeftLeafDigest         a:                         0:
-- B:LS.KeyByteSize            b:LS.ObjectByteSize        1:
-- C:LS.NodeCount              c:LS.LeafCount             2:
-- D:LS.RootDigestList         d:LS.KeyDataType           3:
-- E:                          e:                         4:
-- F:LC.KeyFunction            f:LS.KeyField              5:
-- G:                          g:                         6:
-- H:LS.Threshold              h:                         7:
-- I:                          i:                         8:
-- J:LS.KeyByteArray           j:LS.DigestByteArray       9:
-- K:LS.RootKeyList            k:LC.KeyType         
-- L:                          l:LS.TreeLevel          
-- M:LC.StoreMode              m:                
-- N:SPECIAL(LBYTES)           n:SPECIAL(LBYTES)
-- O:SPECIAL(LBYTES)           o:SPECIAL(LBYTES)
-- P:LC.UserModule             p:
-- Q:LS.CompactList            q:
-- R:LS.RootListMax            r:LS.RootByteCountMax      
-- S:LS.StoreState             s:                        
-- T:LS.TotalCount (XXX)       t:LC.Transform
-- U:LS.KeyUnique              u:LC.UnTransform
-- V:LS.RevThreshold           v:
-- W:                          w:                        
-- X:LS.NodeListMax            x:LS.LeafListMax           
-- Y:LS.NodeByteCountMax       y:LS.LeafByteCountMax
-- Z:LS.RightLeafDigest        z:
-- -- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--
-- Key Compare Function for Complex Objects
-- By default, a complex object will have a "key" field (held in the KEY_FIELD
-- global constant) which the -- key_compare() function will use to compare.
-- If the user passes in something else, then we'll use THAT to perform the
-- compare, which MUST return -1, 0 or 1 for A < B, A == B, A > B.
-- UNLESS we are using a simple true/false equals compare.
-- ========================================================================
-- Actually -- the default will be EQUALS.  The >=< functions will be used
-- in the Ordered LIST implementation, not in the simple list implementation.
-- ========================================================================
local KC_DEFAULT="keyCompareEqual"; -- Key Compare used only in complex mode
local KH_DEFAULT="keyHash";         -- Key Hash used only in complex mode

-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- <><><><> <Initialize Control Maps> <Initialize Control Maps> <><><><>
-- There are three main Record Types used in the LLIST Package, and their
-- initialization functions follow.  The initialization functions
-- define the "type" of the control structure:
--
-- (*) TopRec: the top level user record that contains the LLIST bin,
--     including the Root Directory.
-- (*) InnerNodeRec: Interior B+ Tree nodes
-- (*) DataNodeRec: The Data Leaves
--
-- <+> Naming Conventions:
--   + All Field names (e.g. ldtMap[LC.StoreMode]) begin with Upper Case
--   + All variable names (e.g. ldtMap[LC.StoreMode]) begin with lower Case
--   + All Record Field access is done using brackets, with either a
--     variable or a constant (in single quotes).
--     (e.g. topRec[ldtBinName] or ldrRec['NodeCtrlBin']);

-- ======================================================================
-- <USER FUNCTIONS> - <USER FUNCTIONS> - <USER FUNCTIONS> - <USER FUNCTIONS>
-- ======================================================================
-- We have several different situations where we need to look up a user
-- defined function:
-- (*) Object Transformation (e.g. compression)
-- (*) Object UnTransformation
-- (*) Predicate Filter (perform additional predicate tests on an object)
--
-- These functions are passed in by name (UDF name, Module Name), so we
-- must check the existence/validity of the module and UDF each time we
-- want to use them.  Furthermore, we want to centralize the UDF checking
-- into one place -- so on entry to those LDT functions that might employ
-- these UDFs (e.g. insert, filter), we'll set up either READ UDFs or
-- WRITE UDFs and then the inner routines can call them if they are
-- non-nil.
-- ======================================================================
local G_Filter = nil;
local G_Transform = nil;
local G_UnTransform = nil;
local G_FunctionArgs = nil;
local G_KeyFunction = nil;

-- Special Function -- if supplied by the user in the "userModule", then
-- we call that UDF to adjust the LDT configuration settings.
local G_SETTINGS = "adjust_settings";

-- <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> 
-- -----------------------------------------------------------------------
-- resetPtrs()
-- -----------------------------------------------------------------------
-- Reset the UDF Ptrs to nil.
-- -----------------------------------------------------------------------
local function resetUdfPtrs()
  G_Filter = nil;
  G_Transform = nil;
  G_UnTransform = nil;
  G_FunctionArgs = nil;
  G_KeyFunction = nil;
end -- resetPtrs()

-- <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> <udf> 
-- -----------------------------------------------------------------------
-- -----------------------------------------------------------------------
-- ======================================================================
-- <USER FUNCTIONS> - <USER FUNCTIONS> - <USER FUNCTIONS> - <USER FUNCTIONS>
-- ======================================================================

-- ======================================================================
-- propMapSummary( resultMap, propMap )
-- ======================================================================
-- Add the propMap properties to the supplied resultMap.
-- ======================================================================
local function propMapSummary( resultMap, propMap )

  -- Fields common for all LDT's
  
  resultMap.PropItemCount        = propMap[PM.ItemCount];
  resultMap.PropVersion          = propMap[PM.Version];
  resultMap.PropSubRecCount      = propMap[PM.SubRecCount];
  resultMap.PropLdtType          = propMap[PM.LdtType];
  resultMap.PropBinName          = propMap[PM.BinName];
  resultMap.PropMagic            = propMap[PM.Magic];
  resultMap.PropCreateTime       = propMap[PM.CreateTime];
  resultMap.PropEsrDigest        = propMap[PM.EsrDigest];
  resultMap.PropRecType          = propMap[PM.RecType];
  resultMap.PropParentDigest     = propMap[PM.ParentDigest];
  resultMap.PropSelfDigest       = propMap[PM.SelfDigest];

end -- function propMapSummary()

-- ======================================================================
-- ldtMapSummary( resultMap, ldtMap )
-- ======================================================================
-- Add the ldtMap properties to the supplied resultMap.
-- ======================================================================
local function ldtMapSummary( resultMap, ldtMap )

  -- General Tree Settings
  resultMap.StoreMode         = ldtMap[LC.StoreMode];
  resultMap.StoreState        = ldtMap[LS.StoreState];
  resultMap.StoreLimit        = ldtMap[LC.StoreLimit];
  resultMap.TreeLevel         = ldtMap[LS.TreeLevel];
  resultMap.LeafCount         = ldtMap[LS.LeafCount];
  resultMap.NodeCount         = ldtMap[LS.NodeCount];
  resultMap.KeyType           = ldtMap[LC.KeyType];
  resultMap.TransFunc         = ldtMap[LC.Transform];
  resultMap.UnTransFunc       = ldtMap[LC.UnTransform];
  resultMap.KeyFunction       = ldtMap[LC.KeyFunction];
  resultMap.UserModule        = ldtMap[LC.UserModule];

  -- Top Node Tree Root Directory
  resultMap.RootListMax        = ldtMap[LS.RootListMax];
  resultMap.KeyByteArray       = ldtMap[LS.KeyByteArray];
  resultMap.DigestByteArray    = ldtMap[LS.DigestByteArray];
  resultMap.RootKeyList        = ldtMap[LS.RootKeyList];
  resultMap.RootDigestList     = ldtMap[LS.RootDigestList];
  resultMap.CompactList        = ldtMap[LS.CompactList];
  
  -- LLIST Inner Node Settings
  resultMap.NodeListMax            = ldtMap[LS.NodeListMax];
  resultMap.NodeKeyByteSize        = ldtMap[LS.KeyByteSize];
  resultMap.NodeObjectByteSize     = ldtMap[LS.ObjectByteSize];
  resultMap.NodeByteCountMax       = ldtMap[LS.NodeByteCountMax];

  -- LLIST Tree Leaves (Data Pages)
  resultMap.DataPageListMax        = ldtMap[LS.LeafListMax];
  resultMap.DataPageByteCountMax   = ldtMap[LS.LeafByteCountMax];
  resultMap.DataPageByteEntrySize  = ldtMap[LS.ObjectByteSize];

end -- ldtMapSummary()

-- ======================================================================
-- ldtMapSummaryString( ldtMap )
-- ======================================================================
-- Return a string with the full LDT Map
-- ======================================================================
local function ldtMapSummaryString( ldtMap )
  local resultMap = map();
  ldtMapSummary(resultMap, ldtMap);
  return tostring(resultMap);
end

-- ======================================================================
-- local function Tree Summary( ldtCtrl ) (DEBUG/Trace Function)
-- ======================================================================
-- For easier debugging and tracing, we will summarize the Tree Map
-- contents -- without printing out the entire thing -- and return it
-- as a string that can be printed.
-- ======================================================================
local function ldtSummary( ldtCtrl )

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  
  local resultMap             = map();
  resultMap.SUMMARY           = "LList Summary";

  -- General Properties (the Properties Bin
  propMapSummary( resultMap, propMap );

  -- General Tree Settings
  -- Top Node Tree Root Directory
  -- LLIST Inner Node Settings
  -- LLIST Tree Leaves (Data Pages)
  ldtMapSummary( resultMap, ldtMap );

  return  resultMap;
end -- ldtSummary()

-- ======================================================================
-- Do the summary of the LDT, and stringify it for internal use.
-- ======================================================================
local function ldtSummaryString( ldtCtrl )
  return tostring( ldtSummary( ldtCtrl ) );
end -- ldtSummaryString()

-- ======================================================================
-- ldtDebugDump()
-- ======================================================================
-- To aid in debugging, dump the entire contents of the ldtCtrl object
-- for LMAP.  Note that this must be done in several prints, as the
-- information is too big for a single print (it gets truncated).
-- ======================================================================
local function ldtDebugDump( ldtCtrl )
  local meth = "ldtDebugDump()";
  info("[ENTER]<%s:%s>", MOD, meth );
  info("\n\n <><><><><><><><><> [ LDT LLIST SUMMARY ] <><><><><><><><><> \n");

  -- Print MOST of the "TopRecord" contents of this LLIST object.
  local resultMap                = map();
  resultMap.SUMMARY              = "LLIST Summary";
  local meth = "ldtDebugDump()";

  if ( ldtCtrl == nil ) then
    info("[ERROR]: <%s:%s>: EMPTY LDT BIN VALUE", MOD, meth);
    resultMap.ERROR =  "EMPTY LDT BIN VALUE";
    info("<<<%s>>>", tostring(resultMap));
    return 0;
  end

  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  if( propMap[PM.Magic] ~= MAGIC ) then
    resultMap.ERROR =  "BROKEN LDT--No Magic";
    info("<<<%s>>>", tostring(resultMap));
    return 0;
  end;

  -- Load the common properties
  propMapSummary( resultMap, propMap );
  info("\n<<<%s>>>\n", tostring(resultMap));
  resultMap = nil;

  -- Reset for each section, otherwise the result would be too much for
  -- the info call to process, and the information would be truncated.
  resultMap = map();
  resultMap.SUMMARY              = "LLIST-SPECIFIC Values";

  -- Load the LLIST-specific properties
  ldtMapSummary( resultMap, ldtMap );
  info("\n<<<%s>>>\n", tostring(resultMap));
  resultMap = nil;

end -- function ldtDebugDump()

-- <><><><> <Initialize Control Maps> <Initialize Control Maps> <><><><>
-- ======================================================================
-- initializeLdtCtrl:
-- ======================================================================
-- Set up the LLIST control structure with the standard (default) values.
-- These values may later be overridden by the user.
-- The structure held in the Record's "LLIST BIN" is this map.  This single
-- structure contains ALL of the settings/parameters that drive the LLIST
-- behavior.  Thus this function represents the "type" LLIST MAP -- all
-- LLIST control fields are defined here.
-- The LListMap is obtained using the user's LLIST Bin Name:
-- ldtCtrl = topRec[ldtBinName]
-- local propMap = ldtCtrl[1];
-- local ldtMap  = ldtCtrl[2];
-- ======================================================================
local function
initializeLdtCtrl( topRec, ldtBinName )
  local meth = "initializeLdtCtrl()";
  GP=E and trace("[ENTER]<%s:%s>:: ldtBinName(%s)",
    MOD, meth, tostring(ldtBinName));

  local propMap = map();
  local ldtMap = map();
  local ldtCtrl = list();

  -- The LLIST control structure -- with Default Values.  Note that we use
  -- two maps -- a general propery map that is the same for all LDTS (in
  -- list position ONE), and then an LDT-specific map.  This design lets us
  -- look at the general property values more easily from the Server code.
  -- General LDT Parms(Same for all LDTs): Held in the Property Map
  propMap[PM.ItemCount] = 0; -- A count of all items in the stack
  propMap[PM.SubRecCount] = 0; -- No Subrecs yet
  propMap[PM.Version]    = G_LDT_VERSION ; -- Current version of the code
  propMap[PM.LdtType]    = LDT_TYPE; -- Validate the ldt type
  propMap[PM.Magic]      = MAGIC; -- Special Validation
  propMap[PM.BinName]    = ldtBinName; -- Defines the LDT Bin
  propMap[PM.RecType]    = RT.LDT; -- Record Type LDT Top Rec
  propMap[PM.EsrDigest]    = 0; -- not set yet.
  propMap[PM.CreateTime] = aerospike:get_current_time();
  propMap[PM.SelfDigest]  = record.digest( topRec );

  -- NOTE: We expect that these settings should match the settings found in
  -- settings_llist.lua :: package.ListMediumObject().
  -- General Tree Settings
  -- ldtMap[LS.TotalCount] = 0;    -- A count of all "slots" used in LLIST
  ldtMap[LS.LeafCount] = 0;     -- A count of all Leaf Nodes
  ldtMap[LS.NodeCount] = 0;     -- A count of all Nodes (incl leaves, excl root)
  ldtMap[LC.StoreMode] = SM_LIST; -- SM_LIST or SM_BINARY (applies to Leaves))
  ldtMap[LS.TreeLevel] = 1;     -- Start off Lvl 1: Root ONLY. Leaves Come l8tr
  ldtMap[LC.KeyType]   = KT_NONE; -- atomic or complex Key Type (start w/ None)
  ldtMap[LS.KeyUnique] = AS_TRUE; -- Keys ARE unique by default.
  -- ldtMap[LC.Transform];   -- (set later) transform Func (user to storage)
  -- ldtMap[LC.UnTransform]; -- (set later) Un-transform (storage to user)
  ldtMap[LS.StoreState] = SS_COMPACT; -- start in "compact mode"
  ldtMap[LC.StoreLimit] = 0; -- No Limit to start;

  -- We switch from compact list to tree when we cross LS.Threshold, and we
  -- switch from tree to compact list when we drop below LS.RevThreshold.
  ldtMap[LS.Threshold] = DEFAULT.THRESHOLD;
  ldtMap[LS.RevThreshold] = DEFAULT.REV_THRESHOLD;

  -- Fixed Key and Object sizes -- when using Binary Storage
  -- Do not set the byte counters .. UNTIL we are actually using them.
  -- ldtMap[LS.KeyByteSize] = 0;   -- Size of a fixed size key
  -- ldtMap[LS.ObjectByteSize] = 0;   -- Size of a fixed size key

  -- Top Node Tree Root Directory
  -- Length of Key List (page list is KL + 1)
  ldtMap[LS.RootListMax] = DEFAULT.ROOT_MAX;
  -- Do not set the byte counters .. UNTIL we are actually using them.
  -- ldtMap[LS.RootByteCountMax] = 0; -- Max bytes for key space in the root
  -- ldtMap[LS.KeyByteArray];    -- (UNSET) Byte Array, when in compressed mode
  -- ldtMap[LS.DigestByteArray]; -- (UNSET) DigestArray, when in compressed mode
  ldtMap[LS.RootKeyList] = list();    -- Key List, when in List Mode
  ldtMap[LS.RootDigestList] = list(); -- Digest List, when in List Mode
  ldtMap[LS.CompactList] = list();-- Simple Compact List -- before "tree mode"
  
  -- LLIST Inner Node Settings
  ldtMap[LS.NodeListMax] = DEFAULT.NODE_MAX;  -- Max # of items (key+digest)
  -- ldtMap[LS.NodeByteCountMax] = 0; -- Max # of BYTES

  -- LLIST Tree Leaves (Data Pages)
  ldtMap[LS.LeafListMax] = DEFAULT.LEAF_MAX;  -- Max # of items in a leaf
  -- ldtMap[LS.LeafByteCountMax] = 0; -- Max # of BYTES per data page

  -- If the topRec already has an LDT CONTROL BIN (with a valid map in it),
  -- then we know that the main LDT record type has already been set.
  -- Otherwise, we should set it. This function will check, and if necessary,
  -- set the control bin.
  -- This method also sets this toprec as an LDT type record.
  ldt_common.setLdtRecordType( topRec );
  
  -- Set the BIN Flag type to show that this is an LDT Bin, with all of
  -- the special priviledges and restrictions that go with it.
  GP=F and trace("[DEBUG]:<%s:%s>About to call record.set_flags(Bin(%s)F(%s))",
    MOD, meth, ldtBinName, tostring(BF.LDT_BIN) );

  -- Put our new map in the record, then store the record.
  list.append( ldtCtrl, propMap );
  list.append( ldtCtrl, ldtMap );
  topRec[ldtBinName] = ldtCtrl;
  record.set_flags( topRec, ldtBinName, BF.LDT_BIN );

  GP=F and trace("[DEBUG]: <%s:%s> Back from calling record.set_flags()",
  MOD, meth );

  GP=E and trace("[EXIT]: <%s:%s> : CTRL Map after Init(%s)",
      MOD, meth, ldtSummaryString(ldtCtrl));

  return ldtCtrl;
end -- initializeLdtCtrl()


-- -- ======================================================================
-- NOTE: We no longer call this local function.  We now call the common
-- function: ldt_common.adjustLdtMap( ldtCtrl, argListMap, ldtSpecificPackage)
-- -- ======================================================================
-- -- adjustLdtMap:
-- -- NOTE: This should not be called -- we should be using the adjustLdtMap()
-- -- in ldt_common.
-- -- ======================================================================
-- -- Using the settings supplied by the caller in the LDT Create call,
-- -- we adjust the values in the LdtMap:
-- -- Parms:
-- -- (*) ldtCtrl: the main LDT Bin value (propMap, ldtMap)
-- -- (*) argListMap: Map of LDT Settings 
-- -- Return: The updated LdtList
-- -- ======================================================================
-- local function adjustLdtMap( ldtCtrl, argListMap )
--   local meth = "adjustLdtMap()";
--   local propMap = ldtCtrl[1];
--   local ldtMap = ldtCtrl[2];
-- 
--   GP=E and trace("[ENTER]: <%s:%s>:: LdtCtrl(%s)::\n ArgListMap(%s)",
--   MOD, meth, tostring(ldtCtrl), tostring( argListMap ));
-- 
--   -- Iterate thru the argListMap and adjust (override) the map settings 
--   -- based on the settings passed in during the stackCreate() call.
--   GP=F and trace("[DEBUG]: <%s:%s> : Processing Arguments:(%s)",
--   MOD, meth, tostring(argListMap));
-- 
--   -- We now have a better test for seeing if something is a map
--   if (getmetatable(argListMap) == Map ) then
-- 
--     -- For the old style -- we'd iterate thru ALL arguments and change
--     -- many settings.  Now we process only packages this way.
--     for name, value in map.pairs( argListMap ) do
--       GP=F and trace("[DEBUG]: <%s:%s> : Processing Arg: Name(%s) Val(%s)",
--       MOD, meth, tostring( name ), tostring( value ));
-- 
--       -- Process our "prepackaged" settings.  These now reside in the
--       -- settings file.  All of the packages are in a table, and thus are
--       -- looked up dynamically.
--       -- Notice that this is the old way to change settings.  The new way is
--       -- to use a "user module", which contains UDFs that control LDT settings.
--       if name == "Package" and type( value ) == "string" then
--         local ldtPackage = llistPackage[value];
--         if( ldtPackage ~= nil ) then
--           ldtPackage( ldtMap );
--         end
--       end
--     end -- for each argument
--   end -- if the arglist is really a Map
-- 
--   GP=E and trace("[EXIT]:<%s:%s>:LdtCtrl after Init(%s)",
--   MOD,meth,tostring(ldtCtrl));
--   return ldtCtrl;
-- end -- adjustLdtMap
-- 
-- ======================================================================
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- || B+ Tree Data Page Record |||||||||||||||||||||||||||||||||||||||||||
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================
-- Records used for B+ Tree Leaf Nodes have four bins:
-- Each LDT Data Record (LDR) holds a small amount of control information
-- and a list.  A LDR will have four bins:
-- (1) A Property Map Bin (the same for all LDT subrecords)
-- (2) The Control Bin (a Map with the various control data)
-- (3) The Data List Bin -- where we hold Object "list entries"
-- (4) The Binary Bin -- (Optional) where we hold compacted binary entries
--    (just the as bytes values)
--
-- Records used for B+ Tree Inner Nodes have five bins:
-- (1) A Property Map Bin (the same for all LDT subrecords)
-- (2) The Control Bin (a Map with the various control data)
-- (3) The key List Bin -- where we hold Key "list entries"
-- (4) The Digest List Bin -- where we hold the digests
-- (5) The Binary Bin -- (Optional) where we hold compacted binary entries
--    (just the as bytes values)
-- (*) Although logically the Directory is a list of pairs (Key, Digest),
--     in fact it is two lists: Key List, Digest List, where the paired
--     Key/Digest have the same index entry in the two lists.
-- (*) Note that ONLY ONE of the two content bins will be used.  We will be
--     in either LIST MODE (bin 3) or BINARY MODE (bin 5)
-- ==> 'ldtControlBin' Contents (a Map)
--    + 'TopRecDigest': to track the parent (root node) record.
--    + 'Digest' (the digest that we would use to find this chunk)
--    + 'ItemCount': Number of valid items on the page:
--    + 'TotalCount': Total number of items (valid + deleted) used.
--    + 'Bytes Used': Number of bytes used, but ONLY when in "byte mode"
--    + 'Design Version': Decided by the code:  DV starts at 1.0
--    + 'Log Info':(Log Sequence Number, for when we log updates)
--
--  ==> 'ldtListBin' Contents (A List holding entries)
--  ==> 'ldtBinaryBin' Contents (A single BYTE value, holding packed entries)
--    + Note that the Size and Count fields are needed for BINARY and are
--      kept in the control bin (EntrySize, ItemCount)
--
--    -- Entry List (Holds entry and, implicitly, Entry Count)
  
-- ======================================================================
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- || Initialize Interior B+ Tree Nodes  (Records) |||||||||||||||||||||||
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================
-- ======================================================================
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- || B+ Tree Data Page Record |||||||||||||||||||||||||||||||||||||||||||
-- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- ======================================================================
-- Records used for B+ Tree modes have three bins:
-- Chunks hold the actual entries. Each LDT Data Record (LDR) holds a small
-- amount of control information and a list.  A LDR will have three bins:
-- (1) The Control Bin (a Map with the various control data)
-- (2) The Data List Bin ('DataListBin') -- where we hold "list entries"
-- (3) The Binary Bin -- where we hold compacted binary entries (just the
--     as bytes values)
-- (*) Although logically the Directory is a list of pairs (Key, Digest),
--     in fact it is two lists: Key List, Digest List, where the paired
--     Key/Digest have the same index entry in the two lists.
-- (*) Note that ONLY ONE of the two content bins will be used.  We will be
--     in either LIST MODE (bin 2) or BINARY MODE (bin 3)
-- ==> 'LdtControlBin' Contents (a Map)
--    + 'TopRecDigest': to track the parent (root node) record.
--    + 'Digest' (the digest that we would use to find this chunk)
--    + 'ItemCount': Number of valid items on the page:
--    + 'TotalCount': Total number of items (valid + deleted) used.
--    + 'Bytes Used': Number of bytes used, but ONLY when in "byte mode"
--    + 'Design Version': Decided by the code:  DV starts at 1.0
--    + 'Log Info':(Log Sequence Number, for when we log updates)
--
--  ==> 'LdtListBin' Contents (A List holding entries)
--  ==> 'LdtBinaryBin' Contents (A single BYTE value, holding packed entries)
--    + Note that the Size and Count fields are needed for BINARY and are
--      kept in the control bin (EntrySize, ItemCount)
--
--    -- Entry List (Holds entry and, implicitly, Entry Count)
-- ======================================================================
-- <><><><><> -- <><><><><> -- <><><><><> -- <><><><><> -- <><><><><> --
--           Large Ordered List (LLIST) Utility Functions
-- <><><><><> -- <><><><><> -- <><><><><> -- <><><><><> -- <><><><><> --
-- ======================================================================
-- These are all local functions to this module and serve various
-- utility and assistance functions.
-- ======================================================================

-- ======================================================================
-- Convenience function to return the Control Map given a subrec
-- ======================================================================
local function getLeafMap( leafSubRec )
  -- local meth = "getLeafMap()";
  -- GP=E and trace("[ENTER]<%s:%s> ", MOD, meth );
  return leafSubRec[LSR_CTRL_BIN]; -- this should be a map.
end -- getLeafMap

-- ======================================================================
-- Convenience function to return the Control Map given a subrec
-- ======================================================================
local function getNodeMap( nodeSubRec )
  -- local meth = "getNodeMap()";
  -- GP=E and trace("[ENTER]<%s:%s> ", MOD, meth );
  return nodeSubRec[NSR_CTRL_BIN]; -- this should be a map.
end -- getNodeMap

-- ======================================================================
-- validateRecBinAndMap():
-- Check that the topRec, the BinName and CrtlMap are valid, otherwise
-- jump out with an error() call. Notice that we look at different things
-- depending on whether or not "mustExist" is true.
-- Parms:
-- (*) topRec: the Server record that holds the Large Map Instance
-- (*) ldtBinName: The name of the bin for the Large Map
-- (*) mustExist: if true, complain if the ldtBin  isn't perfect.
-- Result:
--   If mustExist == true, and things Ok, return ldtCtrl.
-- ======================================================================
local function validateRecBinAndMap( topRec, ldtBinName, mustExist )
  local meth = "validateRecBinAndMap()";
  GP=E and trace("[ENTER]:<%s:%s> BinName(%s) ME(%s)",
    MOD, meth, tostring( ldtBinName ), tostring( mustExist ));

  -- Start off with validating the bin name -- because we might as well
  -- flag that error first if the user has given us a bad name.
  ldt_common.validateBinName( ldtBinName );

  local ldtCtrl;
  local propMap;

  -- If "mustExist" is true, then several things must be true or we will
  -- throw an error.
  -- (*) Must have a record.
  -- (*) Must have a valid Bin
  -- (*) Must have a valid Map in the bin.
  --
  -- Otherwise, If "mustExist" is false, then basically we're just going
  -- to check that our bin includes MAGIC, if it is non-nil.
  -- TODO : Flag is true for get, config, size, delete etc 
  -- Those functions must be added b4 we validate this if section 

  if mustExist then
    -- Check Top Record Existence.
    if( not aerospike:exists( topRec ) ) then
      debug("[ERROR EXIT]:<%s:%s>:Missing Top Record. Exit", MOD, meth );
      error( ldte.ERR_TOP_REC_NOT_FOUND );
    end
     
    -- Control Bin Must Exist, in this case, ldtCtrl is what we check.
    if ( not  topRec[ldtBinName] ) then
      debug("[ERROR EXIT]<%s:%s> LDT BIN (%s) DOES NOT Exists",
            MOD, meth, tostring(ldtBinName) );
      error( ldte.ERR_BIN_DOES_NOT_EXIST );
    end
    -- This will "error out" if anything is wrong.
    ldtCtrl, propMap = ldt_common.validateLdtBin(topRec, ldtBinName, LDT_TYPE);

    -- Ok -- all done for the Must Exist case.
  else
    -- OTHERWISE, we're just checking that nothing looks bad, but nothing
    -- is REQUIRED to be there.  Basically, if a control bin DOES exist
    -- then it MUST have magic.
    if ( topRec and topRec[ldtBinName] ) then
      ldtCtrl, propMap = ldt_common.validateLdtBin(topRec,ldtBinName,LDT_TYPE);
    end -- if worth checking
  end -- else for must exist

  -- Finally -- let's check the version of our code against the version
  -- in the data.  If there's a mismatch, then kick out with an error.
  -- Although, we check this in the "must exist" case, or if there's 
  -- a valid propMap to look into.
  if ( mustExist or propMap ) then
    local dataVersion = propMap[PM.Version];
    if ( not dataVersion or type(dataVersion) ~= "number" ) then
      dataVersion = 0; -- Basically signals corruption
    end

    if( G_LDT_VERSION > dataVersion ) then
      warn("[ERROR EXIT]<%s:%s> Code Version (%d) <> Data Version(%d)",
        MOD, meth, G_LDT_VERSION, dataVersion );
      warn("[Please reload data:: Automatic Data Upgrade not yet available");
      error( ldte.ERR_VERSION_MISMATCH );
    end
  end -- final version check

  GP=E and trace("[EXIT]<%s:%s> OK", MOD, meth);
  return ldtCtrl; -- Save the caller the effort of extracting the map.
end -- validateRecBinAndMap()

-- ======================================================================
-- Summarize the List (usually ResultList) so that we don't create
-- huge amounts of crap in the console.
-- Show Size, First Element, Last Element
-- ======================================================================
local function summarizeList( myList )
  local resultMap = map();
  resultMap.Summary = "Summary of the List";
  local listSize  = list.size( myList );
  resultMap.ListSize = listSize;
  if resultMap.ListSize == 0 then
    resultMap.FirstElement = "List Is Empty";
    resultMap.LastElement = "List Is Empty";
  else
    resultMap.FirstElement = tostring( myList[1] );
    resultMap.LastElement =  tostring( myList[listSize] );
  end

  return tostring( resultMap );
end -- summarizeList()

-- ======================================================================
-- printRoot( topRec, ldtCtrl )
-- ======================================================================
-- Dump the Root contents for Debugging/Tracing purposes
-- ======================================================================
local function printRoot( topRec, ldtCtrl )
  -- Extract the property map and control map from the ldt bin list.
  local propMap       = ldtCtrl[1];
  local ldtMap       = ldtCtrl[2];
  local keyList    = ldtMap[LS.RootKeyList];
  local digestList = ldtMap[LS.RootDigestList];
  local ldtBinName    = propMap[PM.BinName];

  -- Remember that "print()" goes ONLY to the console, NOT to the log.
  info("\n RRRRRRRRRRRRRRRRRRRRRR  <Root Start>  RRRRRRRRRRRRRRRRRRRRRRR\n");
  info("\n ROOT::Bin(%s)", ldtBinName );
  info("\n ROOT::PropMAP(%s)\n", tostring( propMap ) );
  info("\n ROOT::LdtMAP(%s)\n", tostring( ldtMap ) );
  info("\n ROOT::KeyList(%s)\n", tostring( keyList ) );
  info("\n ROOT::DigestList(%s)\n", tostring( digestList ) );
  info("\n RRRRRRRRRRRRRRRRRRRRRR  <Root End>  RRRRRRRRRRRRRRRRRRRRRRRRR\n");
end -- printRoot()

-- ======================================================================
-- printNode( topRec, ldtCtrl )
-- ======================================================================
-- Dump the Node contents for Debugging/Tracing purposes
-- ======================================================================
local function printNode( nodeSubRec )
  local nodePropMap        = nodeSubRec[SUBREC_PROP_BIN];
  local nodeLdtMap        = nodeSubRec[NSR_CTRL_BIN];
  local keyList     = nodeSubRec[NSR_KEY_LIST_BIN];
  local digestList  = nodeSubRec[NSR_DIGEST_BIN];

  -- Remember that "print()" goes ONLY to the console, NOT to the log.
  info("\n NNNNNNNNNNNNNNNNNNNNN  <Node Start>  NNNNNNNNNNNNNNNNNNNNNNNN");
  info("\n NODE::Digest(%s)", tostring(record.digest(nodeSubRec)));
  info("\n NODE::PropMAP(%s)", tostring( nodePropMap ) );
  info("\n NODE::LdtMAP(%s)", tostring( nodeLdtMap ) );
  info("\n NODE::KeyList(%s)", tostring( keyList ) );
  info("\n NODE::DigestList(%s)", tostring( digestList ) );
  info("\n NNNNNNNNNNNNNNNNNNNNN  <Node End>  NNNNNNNNNNNNNNNNNNNNNNNNNN");
end -- printNode()

-- ======================================================================
-- printLeaf( topRec, ldtCtrl )
-- ============================================leafP=========================
-- Dump the Leaf contents for Debugging/Tracing purposes
-- ======================================================================
local function printLeaf( leafSubRec )
  local leafPropMap     = leafSubRec[SUBREC_PROP_BIN];
  local LeafLdtMap     = leafSubRec[LSR_CTRL_BIN];
  local objList  = leafSubRec[LSR_LIST_BIN];

  -- Remember that "print()" goes ONLY to the console, NOT to the log.
  info("\n LLLLLLLLLLLLLLLLLLLL <Leaf Start> LLLLLLLLLLLLLLLLLLLLLLLLLLL\n");
  info("\n LEAF::Digest(%s)", tostring(record.digest(leafSubRec)));
  info("\n LEAF::PropMAP(%s)\n", tostring( leafPropMap ) );
  info("\n LEAF::LdtMAP(%s)\n", tostring( LeafLdtMap ) );
  info("\n LEAF::ObjectList(%s)\n", tostring( objList ) );
  info("\n LLLLLLLLLLLLLLLLLLLLL <Leaf End > LLLLLLLLLLLLLLLLLLLLLLLLLLL\n");
  -- end
end -- printLeaf()

-- ======================================================================
-- rootNodeSummary( ldtCtrl )
-- ======================================================================
-- Print out interesting stats about this B+ Tree Root
-- ======================================================================
local function rootNodeSummary( ldtCtrl )
  local resultMap = ldtCtrl;

  -- Finish this -- move selected fields into resultMap and return it.

  return tostring( ldtSummary( ldtCtrl )  );
end -- rootNodeSummary()

-- ======================================================================
-- nodeSummary( nodeSubRec )
-- nodeSummaryString( nodeSubRec )
-- ======================================================================
-- Print out interesting stats about this Interior B+ Tree Node
-- ======================================================================
local function nodeSummary( nodeSubRec )
  local meth = "nodeSummary()";
  local resultMap = map();
  local nodePropMap  = nodeSubRec[SUBREC_PROP_BIN];
  local nodeCtrlMap  = nodeSubRec[NSR_CTRL_BIN];
  local keyList = nodeSubRec[NSR_KEY_LIST_BIN];
  local digestList = nodeSubRec[NSR_DIGEST_BIN];

  -- General Properties (the Properties Bin)
  resultMap.SUMMARY           = "NODE Summary";
  resultMap.PropMagic         = nodePropMap[PM.Magic];
  resultMap.PropCreateTime    = nodePropMap[PM.CreateTime];
  resultMap.PropEsrDigest     = nodePropMap[PM.EsrDigest];
  resultMap.PropRecordType    = nodePropMap[PM.RecType];
  resultMap.PropParentDigest  = nodePropMap[PM.ParentDigest];
  
  -- Node Control Map
  resultMap.ListEntryCount = nodeCtrlMap[ND_ListEntryCount];
  resultMap.ListEntryTotal = nodeCtrlMap[ND_ListEntryTotal];

  -- Node Contents (Object List)
  resultMap.KEY_LIST              = keyList;
  resultMap.DIGEST_LIST           = digestList;

  return resultMap;
end -- nodeSummary()

-- ======================================================================
-- ======================================================================
local function nodeSummaryString( nodeSubRec )
  return tostring( nodeSummary( nodeSubRec ) );
end -- nodeSummaryString()

-- ======================================================================
-- leafSummary( leafSubRec )
-- leafSummaryString( leafSubRec )
-- ======================================================================
-- Print out interesting stats about this B+ Tree Leaf (Data) node
-- ======================================================================
local function leafSummary( leafSubRec )
  GP=E and info("[ENTER] LeafSummary(%s)", tostring(leafSubRec));

  if( leafSubRec == nil ) then
    return "NIL Leaf Record";
  end

  local resultMap = map();
  local leafPropMap   = leafSubRec[SUBREC_PROP_BIN];
  local leafCtrlMap   = leafSubRec[LSR_CTRL_BIN];
  local leafList  = leafSubRec[LSR_LIST_BIN];
  GP=DEBUG and info("[LEAF DUMP] PropMap(%s) LeafMap(%s) LeafList(%s)",
    tostring(leafPropMap), tostring(leafCtrlMap), tostring(leafList));

  resultMap.SUMMARY           = "LEAF Summary";

  -- General Properties (the Properties Bin)
  if leafPropMap == nil then
    resultMap.ERROR = "NIL Leaf PROP MAP";
  else
    resultMap.PropMagic         = leafPropMap[PM.Magic];
    resultMap.PropCreateTime    = leafPropMap[PM.CreateTime];
    resultMap.PropEsrDigest     = leafPropMap[PM.EsrDigest];
    resultMap.PropSelfDigest    = leafPropMap[PM.SelfDigest];
    resultMap.PropRecordType    = leafPropMap[PM.RecType];
    resultMap.PropParentDigest  = leafPropMap[PM.ParentDigest];
  end

  trace("[LEAF PROPS]: %s", tostring(resultMap));
  
  -- Leaf Control Map
  resultMap.LF_ListEntryCount = leafCtrlMap[LF_ListEntryCount];
  resultMap.LF_ListEntryTotal = leafCtrlMap[LF_ListEntryTotal];
  resultMap.LF_PrevPage       = leafCtrlMap[LF_PrevPage];
  resultMap.LF_NextPage       = leafCtrlMap[LF_NextPage];

  -- Leaf Contents (Object List)
  resultMap.LIST              = leafList;

  return resultMap;
end -- leafSummary()

-- ======================================================================
-- ======================================================================
local function leafSummaryString( leafSubRec )
  return tostring( leafSummary( leafSubRec ) );
end

-- ======================================================================
-- ======================================================================
local function showRecSummary( nodeSubRec, propMap )
  local meth = "showRecSummary()";
  -- Debug/Tracing to see what we're putting in the SubRec Context
  if( propMap == nil ) then
    info("[ERROR]<%s:%s>: propMap value is NIL", MOD, meth );
    error( ldte.ERR_SUBREC_DAMAGED );
  end
    GP=F and trace("\n[SUBREC DEBUG]:: SRC Contents \n");
    local recType = propMap[PM.RecType];
    if( recType == RT.LEAF ) then
      GP=F and trace("\n[Leaf Record Summary] %s\n",leafSummaryString(nodeSubRec));
    elseif( recType == RT.NODE ) then
      GP=F and trace("\n[Node Record Summary] %s\n",nodeSummaryString(nodeSubRec));
    else
      GP=F and trace("\n[OTHER Record TYPE] (%s)\n", tostring( recType ));
    end
end -- showRecSummary()

-- ======================================================================
-- SUB RECORD CONTEXT DESIGN NOTE:
-- All "outer" functions, like insert(), search(), remove(),
-- will employ the "subrecContext" object, which will hold all of the
-- subrecords that were opened during processing.  Note that with
-- B+ Trees, operations like insert() can potentially involve many subrec
-- operations -- and can also potentially revisit pages.  In addition,
-- we employ a "compact list", which gets converted into tree inserts when
-- we cross a threshold value, so that will involve MANY subrec "re-opens"
-- that would confuse the underlying infrastructure.
--
-- SubRecContext Design:
-- The key will be the DigestString, and the value will be the subRec
-- pointer.  At the end of an outer call, we will iterate thru the subrec
-- context and close all open subrecords.  Note that we may also need
-- to mark them dirty -- but for now we'll update them in place (as needed),
-- but we won't close them until the end.
-- ======================================================================
-- NOTE: We are now using ldt_common.createSubRecContext()
-- ======================================================================

-- ======================================================================
-- Produce a COMPARABLE value (our overloaded term here is "key") from
-- the user's value.
-- The value is either simple (atomic), in which case we just return the
-- value, or an object (complex), in which case we must perform some operation
-- to extract an atomic value that can be compared.  For LLIST, we do one
-- additional thing, which is to look for a field in the complex object
-- called "key" (lower case "key") if no other KeyFunction is supplied.
--
-- NOTE: This function assumes that the "value" is a "Live Object", which
-- means it is in its UNTRANSFORMED state.
--
-- Parms:
-- (*) ldtMap: The basic LDT Control structure
-- (*) value: The value from which we extract a "keyValue" that can be
--            compared in an ordered compare operation.
-- Return a comparable keyValue:
-- ==> The original value, if it is an atomic type
-- ==> A Unique Identifier subset (that is atomic)
-- ==> The entire object, in string form.
-- ======================================================================
local function getKeyValue( ldtMap, value )
  local meth = "getKeyValue()";
  GP=D and trace("[ENTER]<%s:%s> KeyType(%s) value(%s)",
    MOD, meth, tostring(ldtMap[LC.KeyType]), tostring(value));

  if( value == nil ) then
    GP=E and trace("[Early EXIT]<%s:%s> Value is nil", MOD, meth );
    return nil;
  end

  -- Do some lengthy type checks to see what was passed in.
  if DEBUG then
    debug("[DEBUG]<%s:%s> >>>>>  Value TYPE Check <<<<<<", MOD, meth );
    debug("[DEBUG]<%s:%s> Value type(%s)", MOD, meth, tostring( type(value)));
    debug("[DEBUG]<%s:%s> Map Check(%s)", MOD, meth,
           tostring( getmetatable(value) == Map ));
    debug("[DEBUG]<%s:%s> List Check(%s)", MOD, meth, 
           tostring( getmetatable(value) == List));
  end

  -- Set the Key value.  If type is atomic (KT_ATOMIC) then it's the value
  -- itself.  If type is complex (KT_COMPLEX), then we have to find a way
  -- to extract the key (with either the "key" field, or a key function).
  local keyValue;
  if( ldtMap[LC.KeyType] == KT_ATOMIC ) then
    keyValue = value;
  else
    if( G_KeyFunction ~= nil ) then
      -- Employ the user's supplied function (keyFunction) and if that's not
      -- there, look for the special case where the object has a field
      -- called "key".  If not, then, well ... tough.  We tried.
      debug("[DEBUG]<%s:%s> Employ Key Function (%s)",
        MOD, meth, tostring(G_KeyFunction));
      keyValue = G_KeyFunction( value );
    elseif getmetatable(value) == Map and value[KEY_FIELD] ~= nil then
      -- Use the default action of using the object's KEY field
      keyValue = value[KEY_FIELD];
    else
      -- It's an ERROR in Large List to have a Complex Object and NOT
      -- define either a KeyFunction or a Key Field.  Complain.
      warn("[WARNING]<%s:%s> LLIST requires a KeyFunction for Objects",
        MOD, meth );
      error( ldte.ERR_KEY_FUN_NOT_FOUND );
    end
  end

  GP=D and trace("[EXIT]<%s:%s> Result(%s)", MOD, meth,tostring(keyValue));
  return keyValue;
end -- getKeyValue();

-- ======================================================================
-- keyCompare: (Compare ONLY Key values, not Object values)
-- ======================================================================
-- Compare Search Key Value with KeyList, following the protocol for data
-- compare types.  Since compare uses only atomic key types (the value
-- that would be the RESULT of the extractKey() function), we can do the
-- simple compare here, and we don't need "keyType".
-- CR.LESS_THAN    (-1) for searchKey <  dataKey,
-- CR.EQUAL        ( 0) for searchKey == dataKey,
-- CR.GREATER_THAN ( 1) for searchKey >  dataKey
-- Return CR.ERROR (-2) if either of the values is null (or other error)
-- Return CR.INTERNAL_ERROR(-3) if there is some (weird) internal error
-- ======================================================================
local function keyCompare( searchKey, dataKey )
  local meth = "keyCompare()";
  GP=D and trace("[ENTER]<%s:%s> searchKey(%s) data(%s)",
    MOD, meth, tostring(searchKey), tostring(dataKey));

  local result = CR.INTERNAL_ERROR; -- we should never be here.
  -- First check
  if ( dataKey == nil ) then
    warn("[WARNING]<%s:%s> DataKey is nil", MOD, meth );
    result = CR.ERROR;
  elseif( searchKey == nil ) then
    -- a nil search key is always LESS THAN everything.
    result = CR.LESS_THAN;
  else
    if searchKey == dataKey then
      result = CR.EQUAL;
    elseif searchKey < dataKey then
      result = CR.LESS_THAN;
    else
      result = CR.GREATER_THAN;
    end
  end

  GP=D and trace("[EXIT]:<%s:%s> Result(%d)", MOD, meth, result );
  return result;
end -- keyCompare()

-- ======================================================================
-- objectCompare: Compare a key with a complex object
-- ======================================================================
-- Compare Search Value with data, following the protocol for data
-- compare types.
-- Parms:
-- (*) ldtMap: control map for LDT
-- (*) searchKey: Key value we're comparing (if nil, always true)
-- (*) objectValue: Atomic or Complex Object (the LIVE object)
-- Return:
-- CR.LESS_THAN    (-1) for searchKey <   objectKey
-- CR.EQUAL        ( 0) for searchKey ==  objectKey,
-- CR.GREATER_THAN ( 1) for searchKey >   objectKey
-- Return CR.ERROR (-2) if Key or Object is null (or other error)
-- Return CR.INTERNAL_ERROR(-3) if there is some (weird) internal error
-- ======================================================================
local function objectCompare( ldtMap, searchKey, objectValue )
  local meth = "objectCompare()";
  local keyType = ldtMap[LC.KeyType];

  GP=D and trace("[ENTER]<%s:%s> keyType(%s) searchKey(%s) data(%s)",
    MOD, meth, tostring(keyType), tostring(searchKey), tostring(objectValue));

  local result = CR.INTERNAL_ERROR; -- Expect result to be reassigned.

  -- First check
  if ( objectValue == nil ) then
    warn("[WARNING]<%s:%s> ObjectValue is nil", MOD, meth );
    result = CR.ERROR;
  elseif( searchKey == nil ) then
    GP=F and trace("[INFO]<%s:%s> searchKey is nil:Free Pass", MOD, meth );
    result = CR.EQUAL;
  else
    -- Get the key value for the object -- this could either be the object 
    -- itself (if atomic), or the result of a function that computes the
    -- key from the object.
    local objectKey = getKeyValue( ldtMap, objectValue );
    if( type(objectKey) ~= type(searchKey) ) then
      warn("[INFO]<%s:%s> ObjectValue::SearchKey TYPE Mismatch", MOD, meth );
      warn("[INFO] TYPE ObjectValue(%s) TYPE SearchKey(%s)",
        type(objectKey), type(searchKey) );
      -- Generate the error here for mismatched types.
      error(ldte.ERR_TYPE_MISMATCH);
    end

    -- For atomic types (keyType == 0), compare objects directly
    if searchKey == objectKey then
      result = CR.EQUAL;
    elseif searchKey < objectKey then
      result = CR.LESS_THAN;
    else
      result = CR.GREATER_THAN;
    end
  end -- else compare

  GP=D and trace("[EXIT]:<%s:%s> Result(%d)", MOD, meth, result );
  return result;
end -- objectCompare()

-- =======================================================================
--     Node (key) Searching:
-- =======================================================================
--        Index:   1   2   3   4 (node pointers, i.e. Sub-Rec digest values)
--     Key List: [10, 20, 30]
--     Dig List: [ A,  B,  C,  D]
--     +--+--+--+                        +--+--+--+
--     |10|20|30|                        |40|50|60| 
--     +--+--+--+                        +--+--+--+
--   1/  2|  |3  \4 (index)             /   |  |   \
--   A    B  C    D (Digest Ptr)       E    F  G    H
--
--   Child A: all values < 10
--   Child B: all values >= 10 and < 20
--   Child C: all values >= 20 and < 30
--   Child D: all values >= 30
--   (1) Looking for value 15:  (SV=15, Obj=x)
--       : 15 > 10, keep looking
--       : 15 < 20, want Child B (same index ptr as value (2)
--   (2) Looking for value 30:  (SV=30, Obj=x)
--       : 30 > 10, keep looking
--       : 30 > 20, keep looking
--       : 30 = 30, want Child D (same index ptr as value (2)
--   (3) Looking for value 31:  (SV=31, Obj=x)
--       : 31 > 10, keep looking
--       : 31 > 20, keep looking
--       : 31 > 30, At End = want child D
--   (4) Looking for value 5:  (SV=5, Obj=x)
--       : 5 < 10, Want Child A


-- THIS FUNCTION APPEARS TO NOT BE USED.
-- ======================================================================
-- initPropMap( propMap, esrDigest, selfDigest, topDigest, rtFlag, topPropMap )
-- ======================================================================
-- -- Set up the LDR Property Map (one PM per LDT)
-- Parms:
-- (*) propMap: 
-- (*) esrDigest:
-- (*) selfDigest:
-- (*) topDigest:
-- (*) rtFlag:
-- (*) topPropMap:
-- ======================================================================
local function
initPropMap( propMap, esrDigest, selfDigest, topDigest, rtFlag, topPropMap )
  local meth = "initPropMap()";
  GP=E and trace("[ENTER]<%s:%s>", MOD, meth );

  -- Remember the ESR in the Top Record
  topPropMap[PM.EsrDigest] = esrDigest;

  -- Initialize the PropertyMap of the new ESR
  propMap[PM.EsrDigest]    = esrDigest;
  propMap[PM.RecType  ]    = rtFlag;
  propMap[PM.Magic]        = MAGIC;
  propMap[PM.ParentDigest] = topDigest;
  propMap[PM.SelfDigest]   = selfDigest;
  -- For subrecs, set create time to ZERO.
  propMap[PM.CreateTime]   = 0;

  GP=E and trace("[EXIT]: <%s:%s>", MOD, meth );
end -- initPropMap()

-- ======================================================================
-- searchKeyListLinear(): Search the Key list in a Root or Inner Node
-- ======================================================================
-- Search the key list, return the index of the value that represents the
-- child pointer that we should follow.  Notice that this is DIFFERENT
-- from the Leaf Search, which treats the EQUAL case differently.
-- ALSO -- the Objects in the Leaves may be TRANSFORMED (e.g. compressed),
-- so they potentially need to be UN-TRANSFORMED before they can be
-- read.
--
-- For this example:
--              +---+---+---+---+
-- KeyList      |111|222|333|444|
--              +---+---+---+---+
-- DigestList   A   B   C   D   E
--
-- Search Key 100:  Position 1 :: Follow Child Ptr A
-- Search Key 111:  Position 2 :: Follow Child Ptr B
-- Search Key 200:  Position 2 :: Follow Child Ptr B
-- Search Key 222:  Position 2 :: Follow Child Ptr C
-- Search Key 555:  Position 5 :: Follow Child Ptr E
-- Parms:
-- (*) ldtMap: Main control Map
-- (*) keyList: The list of keys (from root or inner node)
-- (*) searchKey: if nil, then is always LESS THAN the list
-- Return:
-- OK: Return the Position of the Digest Pointer that we want
-- ERRORS: Return ERR.GENERAL (bad compare)
-- ======================================================================
local function searchKeyListLinear( ldtMap, keyList, searchKey )
  local meth = "searchKeyListLinear()";
  GP=E and trace("[ENTER]<%s:%s>searchKey(%s)", MOD,meth,tostring(searchKey));

  -- Note that the parent caller has already checked for nil search key.
  
  -- Linear scan of the KeyList.  Find the appropriate entry and return
  -- the index.
  local resultIndex = 0;
  local compareResult = 0;
  -- Do the List page mode search here
  local listSize = list.size( keyList );
  local entryKey;
  for i = 1, listSize, 1 do
    GP=F and trace("[DEBUG]<%s:%s>searchKey(%s) i(%d) keyList(%s)",
    MOD, meth, tostring(searchKey), i, tostring(keyList));

    entryKey = keyList[i];
    compareResult = keyCompare( searchKey, entryKey );
    if compareResult == CR.ERROR then
      return ERR.GENERAL; -- error result.
    end
    if compareResult  == CR.LESS_THAN then
      -- We want the child pointer that goes with THIS index (left ptr)
      GP=F and trace("[Stop Search: Key < Data]: <%s:%s> : SK(%s) EK(%s) I(%d)",
        MOD, meth, tostring(searchKey), tostring( entryKey ), i );
        return i; -- Left Child Pointer
    elseif compareResult == CR.EQUAL then
      -- Found it -- return the "right child" index (right ptr)
      GP=F and trace("[FOUND KEY]: <%s:%s> : SrchValue(%s) Index(%d)",
        MOD, meth, tostring(searchKey), i);
      return i + 1; -- Right Child Pointer
    end
    -- otherwise, keep looking.  We haven't passed the spot yet.
  end -- for each list item

  -- Remember: Can't use "i" outside of Loop.   
  GP=F and trace("[FOUND GREATER THAN]: <%s:%s> SKey(%s) EKey(%s) Index(%d)",
    MOD, meth, tostring(searchKey), tostring(entryKey), listSize + 1 );

  GP=F and trace("[FOUND Insert Point]: <%s:%s> SKey(%s) KeyList(%s) PT(%d)", 
    MOD, meth, tostring(searchKey), tostring(keyList), listSize + 1);

  return listSize + 1; -- return furthest right child pointer
end -- searchKeyListLinear()

-- ======================================================================
-- searchKeyListBinary(): Search the Key list in a Root or Inner Node
-- ======================================================================
-- Search the key list, return the index of the value that represents the
-- child pointer that we should follow.  Notice that this is DIFFERENT
-- from the Leaf Search, which treats the EQUAL case differently.
-- ALSO -- the Objects in the Leaves may be TRANSFORMED (e.g. compressed),
-- so they potentially need to be UN-TRANSFORMED before they can be
-- read.
--
-- For this example:
--              +---+---+---+---+
-- KeyList      |111|222|333|444|
--              +---+---+---+---+
-- DigestList   A   B   C   D   E
--
-- Search Key 100:  Digest List Position 1 :: Follow Child Ptr A
-- Search Key 111:  Digest List Position 2 :: Follow Child Ptr B
-- Search Key 200:  Digest List Position 2 :: Follow Child Ptr B
-- Search Key 222:  Digest List Position 3 :: Follow Child Ptr C
-- Search Key 555:  Digest List Position 5 :: Follow Child Ptr E
--
-- Note that in the case of Duplicate values (and some of the dups may make
-- it up into the parent node key lists), we have to ALWAYS get the LEFT-MOST
-- value (regardless of ascending/descending values) so that we get ALL of
-- them (in case we're searching for a set of values).
--
-- Parms:
-- (*) ldtMap: Main control Map
-- (*) keyList: The list of keys (from root or inner node)
-- (*) searchKey: if nil, then is always LESS THAN the list
-- Return:
-- OK: Return the Position of the Digest Pointer that we want
-- ERRORS: Return ERR.GENERAL (bad compare)
-- ======================================================================
local function searchKeyListBinary( ldtMap, keyList, searchKey )
  local meth = "searchKeyListBinary()";
  GP=E and trace("[ENTER]<%s:%s>searchKey(%s)", MOD,meth,tostring(searchKey));

  GP=D and trace("[DEBUG]<%s:%s>KeyList(%s)", MOD,meth,tostring(keyList));

  -- Note that the parent caller has already checked for nil search key.

  -- Binary Search of the KeyList.  Find the appropriate entry and return
  -- the index.  Note that we're assuming ASCENDING values first, then will
  -- generalize later for ASCENDING and DESCENDING (a dynamic compare function
  -- will help us make that pluggable).
  local resultIndex = 0;
  local compareResult = 0;
  local listSize = list.size( keyList );
  local entryKey;
  local foundStart = 0; -- shows where the value chain started, or zero

  --  Initialize the Start, Middle and End numbers
  local iStart,iEnd,iMid = 1,listSize,0
  local finalState = 0; -- Shows where iMid ends up pointing.
  while iStart <= iEnd do
    -- calculate middle
    iMid = math.floor( (iStart+iEnd)/2 );
    -- get compare value from the DB List (no translate for keys)
    local entryKey = keyList[iMid];
    compareResult = keyCompare( searchKey, entryKey );

    GP=F and trace("[Loop]<%s:%s>Key(%s) S(%d) M(%d) E(%d) EK(%s) CR(%d)",
      MOD, meth, tostring(searchKey), iStart, iMid, iEnd, tostring(entryKey),
      compareResult);

    if compareResult == CR.EQUAL then
      foundStart = iMid;
      -- If we're UNIQUE, then we're done. Otherwise, we have to look LEFT
      -- to find the first NON-matching position.
      if( ldtMap[LS.KeyUnique] == AS_TRUE ) then
        GP=F and trace("[FOUND KEY]: <%s:%s> : SrchValue(%s) Index(%d)",
          MOD, meth, tostring(searchKey), iMid);
      else
        -- There might be duplicates.  Scan left to find left-most matching
        -- key.  Note that if we fall off the front, keyList[0] should
        -- (in theory) be defined to be NIL, so the compare just fails and
        -- we stop.
        entryKey = keyList[iMid - 1];
        while searchKey == entryKey do
          iMid = iMid - 1;
          entryKey = keyList[iMid - 1];
        end
        GP=F and trace("[FOUND DUP KEY]: <%s:%s> : SrchValue(%s) Index(%d)",
          MOD, meth, tostring(searchKey), iMid);
      end
      return iMid + 1; -- Right Child Pointer that goes with iMid
    end -- if found, we've returned.

    -- Keep Searching
    if compareResult == CR.LESS_THAN then
      iEnd = iMid - 1;
      finalState = 0; -- At the end, iMid points at the Insert Point.
    else
      iStart = iMid + 1;
      finalState = 1; -- At the end, iMid points BEFORE the Insert Point.
    end
  end -- while binary search


  -- If we're here, then iStart > iEnd, so we have to return the index of
  -- the correct child pointer that matches the search.
  -- Final state shows us where we are relative to the last compare.  If our
  -- last compare:: Cmp(searchKey, entryKey) shows SK < EK, then the value
  -- of iMid 
  resultIndex = iMid + finalState;

  GP=F and trace("[Result]<%s:%s> iStart(%d) iMid(%d) iEnd(%d)", MOD, meth,
    iStart, iMid, iEnd );
  GP=F and trace("[Result]<%s:%s> Final(%d) ResultIndex(%d)",
    MOD, meth, finalState, resultIndex);

  if DEBUG then
    entryKey = keyList[iMid + finalState];
    GP=F and trace("[Result]<%s:%s> ResultIndex(%d) EntryKey at RI(%s)",
      MOD, meth, resultIndex, tostring(entryKey));
  end

  GP=F and trace("[FOUND Insert Point]: <%s:%s> SKey(%s) KeyList(%s)", 
    MOD, meth, tostring(searchKey), tostring(keyList));

  return resultIndex;
end -- searchKeyListBinary()
  
-- ======================================================================
-- searchKeyList(): Search the Key list in a Root or Inner Node
-- ======================================================================
-- Search the key list, return the index of the value that represents the
-- child pointer that we should follow.  Notice that this is DIFFERENT
-- from the Leaf Search, which treats the EQUAL case differently.
-- ALSO -- the Objects in the Leaves may be TRANSFORMED (e.g. compressed),
-- so they potentially need to be UN-TRANSFORMED before they can be
-- read.
--
-- For this example:
--              +---+---+---+---+
-- KeyList      |111|222|333|444|
--              +---+---+---+---+
-- DigestList   A   B   C   D   E
--
-- Search Key 100:  Digest List Position 1 :: Follow Child Ptr A
-- Search Key 111:  Digest List Position 2 :: Follow Child Ptr B
-- Search Key 200:  Digest List Position 2 :: Follow Child Ptr B
-- Search Key 222:  Digest List Position 3 :: Follow Child Ptr C
-- Search Key 555:  Digest List Position 5 :: Follow Child Ptr E
--
-- The KEY LIST is an UNTRANSFORMED List of KEYS (not objects), so it does
-- NOT need to be untransformed, nor does it need key extraction.
--
-- The Key List is ordered, so it can be searched with either linear (simple
-- but slow) or binary search (more complicated, but faster).  We have both
-- here due to the evolution of the code (simple first, complex second).
--
-- Parms:
-- (*) ldtMap: Main control Map
-- (*) keyList: The list of keys (from root or inner node)
-- (*) searchKey: if nil, then is always LESS THAN the list
-- Return:
-- OK: Return the Position of the Digest Pointer that we want
-- ERRORS: Return ERR.GENERAL (bad compare)
-- ======================================================================
local function searchKeyList( ldtMap, keyList, searchKey )
  local meth = "searchKeyList()";
  GP=E and trace("[ENTER]<%s:%s>searchKey(%s)", MOD,meth,tostring(searchKey));

  -- We can short-cut this.  If searchKey is nil, then we automatically
  -- return 1 (the first index position).
  if( searchKey == nil ) then
    return 1;
  end

  -- Depending on the state of the code, pick either the LINEAR search method
  -- or the BINARY search method.
  -- Rule of thumb is that linear is the better search for lists shorter than
  -- 10, and after that binary search is better.
  local listSize = list.size(keyList);
  if( listSize <= LINEAR_SEARCH_CUTOFF ) then
    return searchKeyListLinear( ldtMap, keyList, searchKey );
  else
    return searchKeyListBinary( ldtMap, keyList, searchKey );
  end
end --searchKeyList()

-- ======================================================================
-- searchObjectListLinear(): LINEAR Search the Object List in a Leaf Node
-- ======================================================================
-- Search the Object list, return the index of the value that is THE FIRST
-- object to match the search Key. Notice that this method is different
-- from the searchKeyList() -- since that is only looking for the right
-- leaf.  In searchObjectList() we're looking for the actual value.
-- NOTE: Later versions of this method will probably return a location
-- of where to start scanning (for value ranges and so on).  But, for now,
-- we're just looking for an exact match.
-- For this example:
--              +---+---+---+---+
-- ObjectList   |111|222|333|444|
--              +---+---+---+---+
-- Index:         1   2   3   4
--
-- Search Key 100:  Position 1 :: Insert at index location 1
-- Search Key 111:  Position 1 :: Insert at index location 1
-- Search Key 200:  Position 2 :: Insert at index location 2
-- Search Key 222:  Position 2 :: Insert at index location 2
-- Parms:
-- (*) ldtMap: Main control Map
--
-- Parms:
-- (*) ldtMap: Main control Map
-- (*) objectList: The list of keys (from root or inner node)
-- (*) searchKey: if nil, then it compares LESS than everything.
-- Return: Returns a STRUCTURE (a map)
-- (*) POSITION: (where we found it if true, or where we would insert if false)
-- (*) FOUND RESULTS (true, false)
-- (*) ERROR Status: Ok, or Error
--
-- OK: Return the Position of the first matching value.
-- ERRORS:
-- ERR.GENERAL   (-1): Trouble
-- ERR.NOT_FOUND (-2): Item not found.
-- ======================================================================
local function searchObjectListLinear( ldtMap, objectList, searchKey )
  local meth = "searchObjectListLinear()";
  local keyType = ldtMap[LC.KeyType];
  GP=D and trace("[ENTER]<%s:%s>searchKey(%s) keyType(%s) ObjList(%s)",
    MOD, meth, tostring(searchKey), tostring(keyType), tostring(objectList));

  local resultMap = map();
  resultMap.Status = ERR.OK;

  -- NOTE: The caller checks for a NULL search key, so we can bypass that setep.

  resultMap.Found = false;
  resultMap.Position = 0;

  -- Linear scan of the ObjectList.  Find the appropriate entry and return
  -- the index.
  local resultIndex = 0;
  local compareResult = 0;
  local objectKey;
  local storeObject; -- the stored (transformed) representation of the object
  local liveObject; -- the live (untransformed) representation of the object

  -- Do the List page mode search here
  local listSize = list.size( objectList );

  GP=F and trace("[Starting LOOP]<%s:%s>", MOD, meth );

  for i = 1, listSize, 1 do
    -- If we have a transform/untransform, do that here.
    storeObject = objectList[i];
    if( G_UnTransform ~= nil ) then
      liveObject = G_UnTransform( storeObject );
    else
      liveObject = storeObject;
    end

    compareResult = objectCompare( ldtMap, searchKey, liveObject );
    if compareResult == CR.ERROR then
      resultMap.Status = ERR.GENERAL;
      return resultMap;
    end
    if compareResult  == CR.LESS_THAN then
      -- We want the child pointer that goes with THIS index (left ptr)
      GP=D and debug("[NOT FOUND LESS THAN]<%s:%s> : SV(%s) Obj(%s) I(%d)",
        MOD, meth, tostring(searchKey), tostring(liveObject), i );
      resultMap.Position = i;
      return resultMap;
    elseif compareResult == CR.EQUAL then
      -- Found it -- return the index of THIS value
      GP=D and trace("[FOUND KEY]: <%s:%s> :Key(%s) Value(%s) Index(%d)",
        MOD, meth, tostring(searchKey), tostring(liveObject), i );
      resultMap.Position = i; -- Index of THIS value.
      resultMap.Found = true;
      return resultMap;
    end
    -- otherwise, keep looking.  We haven't passed the spot yet.
  end -- for each list item

  -- Remember: Can't use "i" outside of Loop.   
  GP=F and debug("[NOT FOUND: EOL]: <%s:%s> :Key(%s) Final Index(%d)",
    MOD, meth, tostring(searchKey), listSize );

  resultMap.Position = listSize + 1;
  resultMap.Found = false;

  GP=E and trace("[EXIT]<%s:%s>ResultMap(%s)", MOD,meth,tostring(resultMap));
  return resultMap;
end -- searchObjectListLinear()

-- ======================================================================
-- searchObjectListBinary(): BINARY Search the Object List in a Leaf Node
-- ======================================================================
-- Search the Object list, return the index of the value that is THE FIRST
-- object to match the search Key. Notice that this method is different
-- from the searchKeyList() -- since that is only looking for the right
-- leaf.  In searchObjectList() we're looking for the actual value.
-- NOTE: Later versions of this method will probably return a location
-- of where to start scanning (for value ranges and so on).  But, for now,
-- we're just looking for an exact match.
-- For this example:
--              +---+---+---+---+
-- ObjectList   |111|222|333|444|
--              +---+---+---+---+
-- Index:         1   2   3   4
--
-- Search Key 100:  Position 1 :: Insert at index location 1
-- Search Key 111:  Position 1 :: Insert at index location 1
-- Search Key 200:  Position 2 :: Insert at index location 2
-- Search Key 222:  Position 2 :: Insert at index location 2
-- Parms:
-- (*) ldtMap: Main control Map
--
-- Parms:
-- (*) ldtMap: Main control Map
-- (*) objectList: The list of keys (from root or inner node)
-- (*) searchKey: if nil, then it compares LESS than everything.
-- Return: Returns a STRUCTURE (a map)
-- (*) POSITION: (where we found it if true, or where we would insert if false)
-- (*) FOUND RESULTS (true, false)
-- (*) ERROR Status: Ok, or Error
--
-- OK: Return the Position of the first matching value.
-- ERRORS:
-- ERR.GENERAL   (-1): Trouble
-- ERR.NOT_FOUND (-2): Item not found.
-- ======================================================================
local function searchObjectListBinary( ldtMap, objectList, searchKey )
  local meth = "searchObjectListBinary()";
  local keyType = ldtMap[LC.KeyType];
  GP=D and trace("[ENTER]<%s:%s>searchKey(%s) keyType(%s) ObjList(%s)",
    MOD, meth, tostring(searchKey), tostring(keyType), tostring(objectList));

  local resultMap = map();
  resultMap.Status = ERR.OK;

  -- NOTE: The caller checks for a NULL search key, so we can bypass that setep.

  resultMap.Found = false;
  resultMap.Position = 0;

  -- BINARY SEARCH of the ObjectList.  Find the appropriate entry and return
  -- the index.
  local resultIndex = 0;
  local compareResult = 0;
  local objectKey;
  local storeObject; -- the stored (transformed) representation of the object
  local liveObject; -- the live (untransformed) representation of the object
  local listSize = list.size( objectList );
  local foundStart = 0; -- shows where the Dup value chain started, or zero

  --  Initialize the Start, Middle and End numbers
  local iStart,iEnd,iMid = 1,listSize,0
  local finalState = 0; -- Shows where iMid ends up pointing.
  while iStart <= iEnd do
    -- calculate middle
    iMid = math.floor( (iStart+iEnd)/2 );
    -- If we have a transform/untransform, do that here.
    storeObject = objectList[iMid];
    liveObject = G_UnTransform and G_UnTransform(storeObject) or storeObject;

    -- Do the Compare, employing the KeyFunction if needed.
    compareResult = objectCompare( ldtMap, searchKey, liveObject );

    GP=F and trace("[Loop]<%s:%s>Key(%s) S(%d) M(%d) E(%d) Obj(%s) CR(%d)",
      MOD, meth, tostring(searchKey), iStart, iMid, iEnd,
      tostring(liveObject), compareResult);

    if compareResult == CR.EQUAL then
      foundStart = iMid;
      -- If we're UNIQUE, then we're done. Otherwise, we have to look LEFT
      -- to find the first NON-matching position.
      if( ldtMap[LS.KeyUnique] == AS_TRUE ) then
        GP=F and trace("[FOUND OBJECT]: <%s:%s> : SrchValue(%s) Index(%d)",
          MOD, meth, tostring(searchKey), iMid);
      else
        -- There might be duplicates.  Scan left to find left-most matching
        -- key.  Note that if we fall off the front, keyList[0] should
        -- (in theory) be defined to be NIL, so the compare just fails and
        -- we stop.
        -- If we have a transform/untransform, do that here.
        while true do
          storeObject = objectList[iMid - 1];
          liveObject =
            G_UnTransform and G_UnTransform(storeObject) or storeObject;
          compareResult = objectCompare( ldtMap, searchKey, liveObject );
          if compareResult ~= CR.EQUAL then
            break;
          end
          iMid = iMid - 1;
        end -- done looking (left) for duplicates

        GP=F and trace("[FOUND DUP KEY]: <%s:%s> : SrchValue(%s) Index(%d)",
          MOD, meth, tostring(searchKey), iMid);
      end
      -- Return the index of THIS location.
      resultMap.Position = iMid;
      resultMap.Found = true;
      return resultMap;
    end -- if found, we've returned.

    -- Keep Searching
    if compareResult == CR.LESS_THAN then
      iEnd = iMid - 1;
      finalState = 0; -- At the end, iMid points at the Insert Point.
    else
      iStart = iMid + 1;
      finalState = 1; -- At the end, iMid points BEFORE the Insert Point.
    end
  end -- while binary search

  -- If we're here, then iStart > iEnd, so we have to return the index of
  -- the correct child pointer that matches the search.
  -- Final state shows us where we are relative to the last compare.  If our
  -- last compare:: Cmp(searchKey, entryKey) shows SK < EK, then the value
  -- of iMid 
  resultMap.Position = iMid + finalState;
  resultMap.Found = false;

  GP=F and debug("[NOT FOUND]: <%s:%s> SKey(%s) KeyList(%s)", 
    MOD, meth, tostring(searchKey), tostring(objectList));
  GP=F and trace("[Result]<%s:%s> iStart(%d) iMid(%d) iEnd(%d)", MOD, meth,
    iStart, iMid, iEnd );
  GP=F and trace("[Result]<%s:%s> Final(%d) INSERT HERE: ResultIndex(%d)",
    MOD, meth, finalState, resultMap.Position);

  GP=E and trace("[EXIT]<%s:%s>ResultMap(%s)", MOD,meth,tostring(resultMap));
  return resultMap;
end -- searchObjectListBinary()

-- ======================================================================
-- searchObjectList(): Search the Object List in a Leaf Node
-- ======================================================================
-- Search the Object list, return the index of the value that is THE FIRST
-- object to match the search Key. Notice that this method is different
-- from the searchKeyList() -- since that is only looking for the right
-- leaf.  In searchObjectList() we're looking for the actual value.
-- NOTE: Later versions of this method will probably return a location
-- of where to start scanning (for value ranges and so on).  But, for now,
-- we're just looking for an exact match.
-- For this example:
--              +---+---+---+---+
-- ObjectList   |111|222|333|444|
--              +---+---+---+---+
-- Index:         1   2   3   4
--
-- Search Key 100:  Position 1 :: Insert at index location 1
-- Search Key 111:  Position 1 :: Insert at index location 1
-- Search Key 200:  Position 2 :: Insert at index location 2
-- Search Key 222:  Position 2 :: Insert at index location 2
-- Parms:
-- (*) ldtMap: Main control Map
--
-- Parms:
-- (*) ldtMap: Main control Map
-- (*) objectList: The list of keys (from root or inner node)
-- (*) searchKey: if nil, then it compares LESS than everything.
-- Return: Returns a STRUCTURE (a map)
-- (*) POSITION: (where we found it if true, or where we would insert if false)
-- (*) FOUND RESULTS (true, false)
-- (*) ERROR Status: Ok, or Error
--
-- OK: Return the Position of the first matching value.
-- ERRORS:
-- ERR.GENERAL   (-1): Trouble
-- ERR.NOT_FOUND (-2): Item not found.
-- ======================================================================
local function searchObjectList( ldtMap, objectList, searchKey )
  local meth = "searchObjectList()";
  local keyType = ldtMap[LC.KeyType];
  GP=D and trace("[ENTER]<%s:%s>searchKey(%s) keyType(%s) ObjList(%s)",
    MOD, meth, tostring(searchKey), tostring(keyType), tostring(objectList));

  local resultMap = map();
  resultMap.Status = ERR.OK;

  -- If we're given a nil searchKey, then we say "found" and return
  -- position 1 -- basically, to set up Scan.
  -- TODO: Must also check for EMPTY LIST -- Perhaps the caller does that?
  if( searchKey == nil ) then
    resultMap.Found = true;
    resultMap.Position = 1;
    GP=E and trace("[EARLY EXIT]<%s:%s> SCAN: Nil Key", MOD, meth );
    return resultMap;
  end

  -- Depending on the state of the code, pick either the LINEAR search method
  -- or the BINARY search method.
  -- Rule of thumb is that linear is the better search for lists shorter than
  -- 10, and after that binary search is better.
  local listSize = list.size(objectList);
  if( listSize <= LINEAR_SEARCH_CUTOFF ) then
    return searchObjectListLinear( ldtMap, objectList, searchKey );
  else
    return searchObjectListBinary( ldtMap, objectList, searchKey );
  end

end -- searchObjectList()

-- ======================================================================
-- For debugging purposes, print the tree, starting with the root and
-- then each level down.
-- Root
-- ::Root Children
-- ::::Root Grandchildren
-- :::...::: Leaves
-- ======================================================================
local function printTree( src, topRec, ldtBinName )
  local meth = "printTree()";
  GP=E and trace("[ENTER]<%s:%s> BinName(%s) SRC(%s)",
    MOD, meth, ldtBinName, tostring(src));
  -- Start with the top level structure and descend from there.
  -- At each level, create a new child list, which will become the parent
  -- list for the next level down (unless we're at the leaves).
  -- The root is a special case of a list of parents with a single node.
  local ldtCtrl = topRec[ldtBinName];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local nodeList = list();
  local childList = list();
  local digestString;
  local nodeSubRec;
  local treeLevel = ldtMap[LS.TreeLevel];
  local rc = 0;

  -- Remember that "print()" just goes to the console, and does NOT
  -- print out in the log.
  info("\n<><> ");
  info("\n===========================================================");
  info("\n<PT>begin <PT> <PT> :::::::::::::::::::::::: <PT> <PT> <PT>");
  info("\n<PT> <PT> <PT> :::::   P R I N T   T R E E  ::::: <PT> <PT>");
  info("\n<PT> <PT> <PT> <PT> :::::::::::::::::::::::: <PT> <PT> <PT>");
  info("\n===========================================================");

  info("\n======  ROOT SUMMARY ======(%s)", rootNodeSummary( ldtCtrl ));

  printRoot( topRec, ldtCtrl );

  nodeList = ldtMap[LS.RootDigestList];

  -- The Root is already printed -- now print the rest.
  for lvl = 2, treeLevel, 1 do
    local listSize = nodeList == nil and 0 or list.size( nodeList );
    for n = 1, listSize, 1 do
      digestString = tostring( nodeList[n] );
      GP=F and trace("[SUBREC]<%s:%s> OpenSR(%s)", MOD, meth, digestString );
      nodeSubRec = ldt_common.openSubRec( src, topRec, digestString );
      if( lvl < treeLevel ) then
        -- This is an inner node -- remember all children
        local digestList  = nodeSubRec[NSR_DIGEST_BIN];
        local digestListSize = list.size( digestList );
        for d = 1, digestListSize, 1 do
          list.append( childList, digestList[d] );
        end -- end for each digest in the node
        printNode( nodeSubRec );
      else
        -- This is a leaf node -- just print contents of each leaf
        printLeaf( nodeSubRec );
      end
      GP=F and trace("[SUBREC]<%s:%s> CloseSR(%s)", MOD, meth, digestString );
      -- Mark the SubRec as "done" (available).
      ldt_common.closeSubRec( src, nodeSubRec, false); -- Mark it as available
    end -- for each node in the list
    -- If we're going around again, then the old childList is the new
    -- ParentList (as in, the nodeList for the next iteration)
    nodeList = childList;
  end -- for each tree level

  info("\n ===========================================================\n");
  info("\n <PT> <PT> <PT> <PT> <PT>   E N D   <PT> <PT> <PT> <PT> <PT>\n");
  info("\n ===========================================================\n");
 
  -- Release ALL of the read-only subrecs that might have been opened.
  rc = ldt_common.closeAllSubRecs( src );
  if( rc < 0 ) then
    info("[EARLY EXIT]<%s:%s> Problem closing subrec in search", MOD, meth );
    error( ldte.ERR_SUBREC_CLOSE );
  end

  GP=E and trace("[EXIT]<%s:%s> ", MOD, meth );
end -- printTree()

-- ======================================================================
-- Update the Leaf Page pointers for a leaf -- used on initial create
-- and leaf splits.  Each leaf has a left and right pointer (digest).
-- Parms:
-- (*) leafSubRec:
-- (*) leftDigest:  Set PrevPage ptr, if not nil
-- (*) rightDigest: Set NextPage ptr, if not nil
-- ======================================================================
local function setLeafPagePointers( src, leafSubRec, leftDigest, rightDigest )
  local meth = "setLeafPagePointers()";
  GP=E and trace("[ENTER]<%s:%s> left(%s) right(%s)",
    MOD, meth, tostring(leftDigest), tostring(rightDigest) );

  local leafCtrlMap = leafSubRec[LSR_CTRL_BIN];
  if( leftDigest ~= nil ) then
    leafCtrlMap[LF_PrevPage] = leftDigest;
  end
  if( leftDigest ~= nil ) then
    leafCtrlMap[LF_NextPage] = rightDigest;
  end
  leafSubRec[LSR_CTRL_BIN] = leafCtrlMap;
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leafSubRec );

  GP=E and trace("[EXIT]<%s:%s> ", MOD, meth );
end -- setLeafPagePointers()

-- ======================================================================
-- adjustLeafPointersAfterInsert()
-- ======================================================================
-- We've just done a Leaf split, so now we have to update the page pointers
-- so that the doubly linked leaf page chain remains intact.
-- When we create pages -- we ALWAYS create a new left page (the right one
-- is the previously existing page).  So, the Next Page ptr of the right
-- page is correct (and its right neighbors are correct).  The only thing
-- to change are the LEFT record ptrs -- the new left and the old left.
--      +---+==>+---+==>+---+==>+---+==>
--      | Xi|   |OL |   | R |   | Xj| Leaves Xi, OL, R and Xj
--   <==+---+<==+---+<==+---+<==+---+
--              +---+
--              |NL | Add in this New Left Leaf to be "R"s new left neighbor
--              +---+
--      +---+==>+---+==>+---+==>+---+==>+---+==>
--      | Xi|   |OL |   |NL |   | R |   | Xj| Leaves Xi, OL, NL, R, Xj
--   <==+---+<==+---+<==+---+<==+---+<==+---+
-- Notice that if "OL" exists, then we'll have to open it just for the
-- purpose of updating the page pointer.  This is a pain, BUT, the alternative
-- is even more annoying, which means a tree traversal for scanning.  So
-- we pay our dues here -- and suffer the extra I/O to open the left leaf,
-- so that our leaf page scanning (in both directions) is easy and sane.
-- We are guaranteed that we'll always have a left leaf and a right leaf,
-- so we don't need to check for that.  However, it is possible that if the
-- old Leaf was the left most leaf (what is "R" in this example), then there
-- would be no "OL".  The left leaf digest value for "R" would be ZERO.
--                       +---+==>+---+=+
--                       | R |   | Xj| V
--                     +=+---+<==+---+
--               +---+ V             +---+==>+---+==>+---+=+
-- Add leaf "NL" |NL |     Becomes   |NL |   | R |   | Xj| V
--               +---+             +=+---+<==+---+<==+---+
--                                 V
--
-- New for Spring 2014 are the LeftLeaf and RightLeaf pointers that we 
-- maintain from the root/control information.  That gets updated when we
-- split the left-most leaf and get a new Left-Most Leaf.  Since we never
-- get a new Right-Most Leaf (at least in regular Split operations), we
-- assign that ONLY with the initial create.
-- ======================================================================
local function adjustLeafPointersAfterInsert( src, topRec, ldtMap, newLeftLeaf, rightLeaf )
  local meth = "adjustLeafPointersAfterInsert()";
  GP=E and trace("[ENTER]<%s:%s> ", MOD, meth );

  -- We'll denote our leaf recs as "oldLeftLeaf, newLeftLeaf and rightLeaf"
  -- The existing rightLeaf points to the oldLeftLeaf.
  local newLeftLeafDigest = record.digest( newLeftLeaf );
  local rightLeafDigest   = record.digest( rightLeaf );

  GP=F and trace("[DEBUG]<%s:%s> newLeft(%s) oldRight(%s)",
    MOD, meth, tostring(newLeftLeafDigest), tostring(rightLeafDigest) );

  local newLeftLeafMap = newLeftLeaf[LSR_CTRL_BIN];
  local rightLeafMap = rightLeaf[LSR_CTRL_BIN];

  local oldLeftLeafDigest = rightLeafMap[LF_PrevPage];
  if( oldLeftLeafDigest == 0 ) then
    -- There is no left Leaf.  Just assign ZERO to the newLeftLeaf Left Ptr.
    -- Also -- register this leaf as the NEW LEFT-MOST LEAF.
    GP=F and trace("[DEBUG]<%s:%s> No Old Left Leaf (assign ZERO)",MOD, meth );
    newLeftLeafMap[LF_PrevPage] = 0;
    ldtMap[LS.LeftLeafDigest] = newLeftLeafDigest;
  else 
    -- Regular situation:  Go open the old left leaf and update it.
    local oldLeftLeafDigestString = tostring(oldLeftLeafDigest);
    local oldLeftLeaf =
        ldt_common.openSubRec( src, topRec, oldLeftLeafDigestString );
    if( oldLeftLeaf == nil ) then
      warn("[ERROR]<%s:%s> oldLeftLeaf NIL from openSubrec: digest(%s)",
        MOD, meth, oldLeftLeafDigestString );
      error( ldte.ERR_SUBREC_OPEN );
    end
    local oldLeftLeafMap = oldLeftLeaf[LSR_CTRL_BIN];
    oldLeftLeafMap[LF_NextPage] = newLeftLeafDigest;
    oldLeftLeaf[LSR_CTRL_BIN] = oldLeftLeafMap;
    -- Call update to mark the SubRec as dirty, and to force the write if we
    -- are in "early update" mode. Close will happen at the end of the Lua call.
    ldt_common.updateSubRec( src, oldLeftLeaf );
  end

  -- Now update the new Left Leaf, the Right Leaf, and their page ptrs.
  newLeftLeafMap[LF_PrevPage] = oldLeftLeafDigest;
  newLeftLeafMap[LF_NextPage] = rightLeafDigest;
  rightLeafMap[LF_PrevPage]   = newLeftLeafDigest;
  
  -- Save the Leaf Record Maps, and update the subrecs.
  newLeftLeaf[LSR_CTRL_BIN]   =  newLeftLeafMap;
  rightLeaf[LSR_CTRL_BIN]     = rightLeafMap;
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, newLeftLeaf );
  ldt_common.updateSubRec( src, rightLeaf );

  GP=E and trace("[EXIT]<%s:%s> ", MOD, meth );
  return 0;
end -- adjustLeafPointersAfterInsert()

-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- Save this code for later (for reference)
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
--    for i = 1, list.size( objectList ), 1 do
--      compareResult = compare( keyType, searchKey, objectList[i] );
--      if compareResult == -2 then
--        return nil -- error result.
--      end
--      if compareResult == 0 then
--        -- Start gathering up values
--        gatherLeafListData( topRec, leafSubRec, ldtMap, resultList, searchKey,
--          func, fargs, flag );
--        GP=F and trace("[FOUND VALUES]: <%s:%s> : Value(%s) Result(%s)",
--          MOD, meth, tostring(newStorageValue), tostring( resultList));
--          return resultList;
--      elseif compareResult  == 1 then
--        GP=F and trace("[NotFound]: <%s:%s> : Value(%s)",
--          MOD, meth, tostring(newStorageValue) );
--          return resultList;
--      end
--      -- otherwise, keep looking.  We haven't passed the spot yet.
--    end -- for each list item
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

-- ======================================================================
-- adjustLeafPointersAfterDelete()
-- ======================================================================
-- We've just done a Leaf REMOVE, so now we have to update the page
-- pointers so that the doubly linked leaf page chain remains intact.
-- Note that we never remove leaves once we've reached a MINIMAL tree,
-- which is TWO leaves (in the Unique Key case) or possibly three+ leaves
-- for the Duplicate Key case (a NULL left-most leaf and 1 or more right
-- leaves).
-- When we INSERT leaves -- we ALWAYS create a new left leaf (the right one
-- is the previously existing page)
-- ==> see the sibling function: adjustLeafPointersAfterInsert()
--
-- When we DELETE a leaf, we basically delete the leaf that became empty,
-- and then deal with its neighbors.  Eventually we may add the capability
-- for LEAF MERGE (for better balance)  but that's a more advanced issue,
-- mainly because duplicate values make that a messy problem.
--
-- So, for a given Delete Leaf "DL", we have to look at its left and right
-- neighbors to know how to adjust the Prev/Next page pointers.
--      +---+==>+---+==>+---+==>0
--      | LL|   | DL|   | RL|   Leaves LL, DL and RL
--  0<==+---+<==+---+<==+---+
--      Becomes
--      +---+==>+---+==>0
--      | LL|   |RL |   Leaves LL, RL
--  0<==+---+<==+---+
--
-- Notice that if LL does not exist, then DL was the left-most leaf, and
-- RL must become that (pointed to by the ldtMap).  Similarly, if the RL
-- does not exist, then LL becomes the new right-most leaf.
-- ======================================================================
local function adjustLeafPointersAfterDelete( src, topRec, ldtMap, leafSubRec )
  local meth = "adjustLeafPointersAfterDelete()";
  GP=E and info("[ENTER]<%s:%s> ", MOD, meth );

  GP=D and info("[DEBUG]<%s:%s> ldtMap(%s)",
    MOD, meth, ldtMapSummaryString(ldtMap));

  GP=D and info("[DEBUG]<%s:%s> leafSubRec Summary(%s)",
    MOD, meth, leafSummaryString(leafSubRec));


  -- All of the OTHER information (e.g. parent ptr info, etc) has been taken
  -- care of.  Now we just have to adjust the Next/Prev leaf pointers before
  -- we finally release the Leaf Sub-Record.
  local leafSubRecDigest = record.digest( leafSubRec );
  local leafCtrlMap = leafSubRec[LSR_CTRL_BIN];

  -- There are potentially Left and Right Neighbors.  If they exist, then
  -- adjust their pointers appropriately. 
  local leftLeafDigest = leafCtrlMap[LF_PrevPage];
  local rightLeafDigest = leafCtrlMap[LF_NextPage];
  local leftLeafDigestString;
  local rightLeafDigestString;
  local leftLeafSubRec;
  local rightLeafSubRec;
  local leftLeafCtrlMap;
  local rightLeafCtrlMap;

  -- Update the right leaf first, if it is there.
  if rightLeafDigest ~= nil and rightLeafDigest ~= 0 then
    rightLeafDigestString = tostring(rightLeafDigest);
    rightLeafSubRec = ldt_common.openSubRec(src, topRec, rightLeafDigestString);

    if rightLeafSubRec == nil then
      warn("[SUBREC ERROR]<%s:%s> Could not open RL SubRec(%s)", MOD, meth,
        rightLeafDigestString );
      error(ldte.ERR_INTERNAL);
    end
    rightLeafCtrlMap = rightLeafSubRec[LSR_CTRL_BIN];

    -- This might be zero or a valid Digest.  It works either way.
    rightLeafCtrlMap[LF_PrevPage] = leftLeafDigest;
    if leftLeafDigest == 0 then
      -- This means our current leaf (leafSubRec) is already the LEFTMOST
      -- leaf, and so the right neighbor actually becomes the new LEFTMOST leaf.
      -- Open the right neighbor and set him appropriately.
      ldtMap[LS.LeftLeafDigest] = rightLeafDigest;
    end
    rightLeafSubRec[LSR_CTRL_BIN] = rightLeafCtrlMap;
    ldt_common.updateSubRec(src, rightLeafSubRec);
    leafSummary(rightLeafSubRec);
  end

  -- Now Update the LEFT leaf, if it is there.
  if leftLeafDigest ~= nil and leftLeafDigest ~= 0 then
    leftLeafDigestString = tostring(leftLeafDigest);
    leftLeafSubRec = ldt_common.openSubRec(src, topRec, leftLeafDigestString);

    if leftLeafSubRec == nil then
      warn("[SUBREC ERROR]<%s:%s> Could not open LL SubRec(%s)", MOD, meth,
        leftLeafDigestString );
      error(ldte.ERR_INTERNAL);
    end
    leftLeafCtrlMap = leftLeafSubRec[LSR_CTRL_BIN];

    -- This might be zero or a valid Digest.  It works either way.
    leftLeafCtrlMap[LF_NextPage] = rightLeafDigest;
    if rightLeafDigest == 0 then
      -- This means our current leaf (leafSubRec) is already the RIGHT-MOST
      -- leaf, and so the left neighbor actually becomes the new RIGHT-MOST
      -- leaf.  Open the left neighbor and set her appropriately.
      ldtMap[LS.RightLeafDigest] = leftLeafDigest;
    end
    leftLeafSubRec[LSR_CTRL_BIN] = leftLeafCtrlMap;
    ldt_common.updateSubRec(src, leftLeafSubRec);
    leafSummary(leftLeafSubRec);
  end


  GP=E and trace("[EXIT]<%s:%s> ", MOD, meth );
  return 0;
end -- adjustLeafPointersAfterDelete()

-- ======================================================================
-- createSearchPath: Create and initialize a search path structure so
-- that we can fill it in during our tree search.
-- Parms:
-- (*) ldtMap: topRec map that holds all of the control values
-- ======================================================================
local function createSearchPath( ldtMap )
  local sp = map();
  sp.LevelCount = 0;
  sp.RecList = list();     -- Track all open nodes in the path
  sp.DigestList = list();  -- The mechanism to open each level
  sp.PositionList = list(); -- Remember where the key was
  sp.HasRoom = list(); -- Check each level so we'll know if we have to split

  -- Cache these here for convenience -- they may or may not be useful
  sp.RootListMax = ldtMap[LS.RootListMax];
  sp.NodeListMax = ldtMap[LS.NodeListMax];
  sp.LeafListMax = ldtMap[LS.LeafListMax];

  return sp;
end -- createSearchPath()

-- ======================================================================
-- updateSearchPath:
-- Add one more entry to the search path thru the B+ Tree.
-- We Rememeber the path that we took during the search
-- so that we can retrace our steps if we need to update the rest of the
-- tree after an insert or delete (although, it's unlikely that we'll do
-- any significant tree change after a delete).
-- Parms:
-- (*) SearchPath: a map that holds all of the secrets
-- (*) propMap: The Property Map (tells what TYPE this record is)
-- (*) ldtMap: Main LDT Control structure
-- (*) nodeSubRec: a subrec
-- (*) position: location in the current list
-- (*) keyCount: Number of keys in the list
-- ======================================================================
local function
updateSearchPath(sp, propMap, ldtMap, nodeSubRec, position, keyCount)
  local meth = "updateSearchPath()";
  GP=E and trace("[ENTER]<%s:%s> SP(%s) PMap(%s) LMap(%s) Pos(%d) KeyCnt(%d)",
    MOD, meth, tostring(sp), tostring(propMap), tostring(ldtMap),
    position, keyCount);

  local levelCount = sp.LevelCount;
  local nodeRecordDigest = record.digest( nodeSubRec );
  sp.LevelCount = levelCount + 1;

  list.append( sp.RecList, nodeSubRec );
  list.append( sp.DigestList, nodeRecordDigest );
  list.append( sp.PositionList, position );
  -- Depending on the Tree Node (Root, Inner, Leaf), we might have different
  -- maximum values.  So, figure out the max, and then figure out if we've
  -- reached it for this node.
  local recType = propMap[PM.RecType];
  local nodeMax = 0;
  if( recType == RT.LDT ) then
      nodeMax = ldtMap[LS.RootListMax];
      GP=F and trace("[Root NODE MAX]<%s:%s> Got Max for Root Node(%s)",
        MOD, meth, tostring( nodeMax ));
  elseif( recType == RT.NODE ) then
      nodeMax = ldtMap[LS.NodeListMax];
      GP=F and trace("[Inner NODE MAX]<%s:%s> Got Max for Inner Node(%s)",
        MOD, meth, tostring( nodeMax ));
  elseif( recType == RT.LEAF ) then
      nodeMax = ldtMap[LS.LeafListMax];
      GP=F and trace("[Leaf NODE MAX]<%s:%s> Got Max for Leaf Node(%s)",
        MOD, meth, tostring( nodeMax ));
  else
      warn("[ERROR]<%s:%s> Bad Node Type (%s) in UpdateSearchPath", 
        MOD, meth, tostring( recType ));
      error( ldte.ERR_INTERNAL );
  end
  GP=F and trace("[HasRoom COMPARE]<%s:%s>KeyCount(%d) NodeListMax(%d)",
    MOD, meth, keyCount, nodeMax );
  if( keyCount >= nodeMax ) then
    list.append( sp.HasRoom, false );
    GP=F and trace("[HasRoom FALSE]<%s:%s>Level(%d) SP(%s)",
        MOD, meth, levelCount + 1, tostring( sp ));
  else
    list.append( sp.HasRoom, true );
    GP=F and trace("[HasRoom TRUE ]<%s:%s>Level(%d) SP(%s)",
        MOD, meth, levelCount + 1, tostring( sp ));
  end

  GP=E and trace("[EXIT]<%s:%s> SP(%s)", MOD, meth, tostring(sp) );
  return 0;
end -- updateSearchPath()

-- ======================================================================
-- fullListScan(): Scan a List.  ALL of the list.
-- ======================================================================
-- Process the FULL contents of the list, applying any UnTransform function,
-- and appending the results to the resultList.
--
-- Parms:
-- (*) objectList
-- (*) ldtMap:
-- (*) resultList:
-- Return: OK if all is well, otherwise call error().
-- ======================================================================
local function fullListScan( objectList, ldtMap, resultList )
  local meth = "fullListScan()";
  GP=E and trace("[ENTER]<%s:%s>", MOD, meth);

  local storeObject; -- the transformed User Object (what's stored).
  local liveObject; -- the untransformed storeObject.

  local listSize = list.size( objectList );
  GP=F and trace("[LIST SCAN]<%s:%s>", MOD, meth);
  for i = 1, listSize do
    -- UnTransform the object, if needed.
    storeObject = objectList[i];
    if( G_UnTransform ~= nil ) then
      liveObject = G_UnTransform( storeObject );
    else
      liveObject = storeObject;
    end
    list.append(resultList, liveObject);
  end -- for each item in the list

  GP=E and trace("[EXIT]<%s:%s> rc(0) Result: Sz(%d) List(%s)",
    MOD, meth, list.size(resultList), tostring(resultList));

  return 0;
end -- fullListScan()

-- ======================================================================
-- listScan(): Scan a List
-- ======================================================================
-- Whether this list came from the Leaf or the Compact List, we'll search
-- thru it and look for matching items -- applying the FILTER on all objects
-- that match the key.
--
-- Parms:
-- (*) objectList
-- (*) startPosition:
-- (*) ldtMap:
-- (*) resultList:
-- (*) searchKey:
-- (*) flag: Termination criteria: key ~= val or key > val
-- Return: A, B, where A is the instruction and B is the return code
-- A: Instruction: 0 (SCAN.DONE==stop), 1 (SCAN.CONTINUE==continue scanning)
-- B: Error Code: B==0 ok.   B < 0 Error.
-- ======================================================================
local function
listScan(objectList, startPosition, ldtMap, resultList, searchKey, flag)
  local meth = "listScan()";
  GP=E and trace("[ENTER]<%s:%s>StartPosition(%d) SearchKey(%s) flag(%d)",
        MOD, meth, startPosition, tostring( searchKey), flag);

  -- Start at the specified location, then scan from there.  For every
  -- element that matches, add it to the resultList.
  local compareResult = 0;
  local uniqueKey = ldtMap[LS.KeyUnique]; -- AS_TRUE or AS_FALSE.
  local scanStatus = SCAN.CONTINUE;
  local storeObject; -- the transformed User Object (what's stored).
  local liveObject; -- the untransformed storeObject.

  -- Later: Maybe .. Split the loop search into two -- atomic and map objects
  local listSize = list.size( objectList );
  -- We expect that the FIRST compare (at location "start") should be
  -- equal, and then potentially some number of objects after that (assuming
  -- it's NOT a unique key).  If unique, then we will just jump out on the
  -- next compare.
  GP=F and trace("[LIST SCAN]<%s:%s>Position(%d)", MOD, meth, startPosition);
  for i = startPosition, listSize, 1 do
    -- UnTransform the object, if needed.
    storeObject = objectList[i];
    if( G_UnTransform ~= nil ) then
      liveObject = G_UnTransform( storeObject );
    else
      liveObject = storeObject;
    end

    compareResult = objectCompare( ldtMap, searchKey, liveObject );
    if compareResult == CR.ERROR then
      debug("[WARNING]<%s:%s> Compare Error", MOD, meth );
      return 0, CR.ERROR; -- error result.
    end
    -- Equals is always good.  If we are doing a true range scan, then
    -- as long as the searchKey is LESS THAN the value, we're also good.
    GP=F and trace("[RANGE]<%s:%s>searchKey(%s) LiveObj(%s) CR(%s) FG(%d)",
      MOD, meth, tostring(searchKey),tostring(liveObject),
      tostring(compareResult), flag);

    if((compareResult == CR.EQUAL)or(compareResult == flag)) then
       GP=F and trace("[CR OK]<%s:%s> CR(%d))", MOD, meth, compareResult);
      -- This one qualifies -- save it in result -- if it passes the filter.
      local filterResult = liveObject;
      if( G_Filter ~= nil ) then
        filterResult = G_Filter( liveObject, G_FunctionArgs );
      end
      if( filterResult ~= nil ) then
        list.append( resultList, liveObject );
      end

      GP=F and trace("[Scan]<%s:%s> Pos(%d) Key(%s) Obj(%s) FilterRes(%s)",
        MOD, meth, i, tostring(searchKey), tostring(liveObject),
        tostring(filterResult));

      -- If we're doing a RANGE scan, then we don't want to jump out, but
      -- if we're doing just a VALUE search (and it's unique), then we're 
      -- done and it's time to leave.
      if(uniqueKey == AS_TRUE and searchKey ~= nil and flag == CR.EQUAL) then
        scanStatus = SCAN.DONE;
        GP=F and trace("[BREAK]<%s:%s> SCAN DONE", MOD, meth);
        break;
      end
    else
      -- First non-equals (or non-range end) means we're done.
      GP=F and trace("[Scan:NON_MATCH]<%s:%s> Pos(%d) Key(%s) Obj(%s) CR(%d)",
        MOD, meth, i, tostring(searchKey), tostring(liveObject), compareResult);
      scanStatus = SCAN.DONE;
      break;
    end
  end -- for each item from startPosition to end

  local resultA = scanStatus;
  local resultB = ERR.OK; -- if we got this far, we're ok.

  GP=E and trace("[EXIT]<%s:%s> A(%s) B(%s) Result: Sz(%d) List(%s)",
    MOD, meth, tostring(resultA), tostring(resultB),
    list.size(resultList), tostring(resultList));

  return resultA, resultB;
end -- listScan()

-- ======================================================================
-- fullByteArrayScan(): Scan ALL of a byte array, perform any optional
-- UnTransform operations, and then return each object of the list in
-- the result list.
-- ======================================================================
-- Parms:
-- (*) byteArray: Packed array of bytes holding transformed objects
-- (*) ldtMap:
-- (*) resultList:
-- Return: 0 if OK, error() otherwise.
-- ======================================================================
local function fullByteArrayScan(byteArray, ldtMap, resultList)
  local meth = "fullByteArrayScan()";
  GP=E and trace("[ENTER]<%s:%s> ", MOD, meth);

  -- >>>>>>>>>>>>>>>>>>>>>>>>> BINARY MODE <<<<<<<<<<<<<<<<<<<<<<<<<<<
    -- Do the BINARY (COMPACT BYTE ARRAY) page mode search here -- eventually
  warn("[NOTICE!!]: <%s:%s> :BINARY MODE UNDER CONSTRUCTION: Do NOT USE!",
        MOD, meth);
  error(ldte.ERR_INTERNAL);
end -- fullByteArrayScan()

-- ======================================================================
-- byteArrayScan(): Scan a Byte Array, gathering up all of the the
-- matching value(s) in the array.  Before an object can be compared,
-- it must be UN-TRANSFORMED from a binary form to a live object.
-- ======================================================================
-- Parms:
-- (*) byteArray: Packed array of bytes holding transformed objects
-- (*) startPosition: logical ITEM offset (not byte offset)
-- (*) ldtMap:
-- (*) resultList:
-- (*) searchKey:
-- (*) flag:
-- Return: A, B, where A is the instruction and B is the return code
-- A: Instruction: 0 (stop), 1 (continue scanning)
-- B: Error Code: B==0 ok.   B < 0 Error.
-- ======================================================================
local function byteArrayScan(byteArray, startPosition, ldtMap, resultList,
                          searchKey, flag)
  local meth = "byteArrayScan()";
  GP=E and trace("[ENTER]<%s:%s>StartPosition(%s) SearchKey(%s)",
        MOD, meth, startPosition, tostring( searchKey));

  -- Linear scan of the ByteArray (binary search will come later), for each
  -- match, add to the resultList.
  local compareResult = 0;
  local uniqueKey = ldtMap[LS.KeyUnique]; -- AS_TRUE or AS_FALSE;
  local scanStatus = SCAN.CONTINUE;

  -- >>>>>>>>>>>>>>>>>>>>>>>>> BINARY MODE <<<<<<<<<<<<<<<<<<<<<<<<<<<
    -- Do the BINARY (COMPACT BYTE ARRAY) page mode search here -- eventually
  warn("[NOTICE!!]: <%s:%s> :BINARY MODE UNDER CONSTRUCTION: Do NOT USE!",
        MOD, meth);
  return 0, ERR.GENERAL; -- TODO: Build this mode.

end -- byteArrayScan()

-- ======================================================================
-- fullScanLeaf():
-- ======================================================================
-- Scan ALL of a Leaf Node, and append the results in the resultList.
-- Parms:
-- (*) topRec: 
-- (*) leafSubRec:
-- (*) ldtMap:
-- (*) resultList:
-- Return:
-- 0=for OK
-- Call error() for problems
-- ======================================================================
local function fullScanLeaf(topRec, leafSubRec, ldtMap, resultList)
  local meth = "fullScanLeaf()";
  GP=E and trace("[ENTER]<%s:%s>", MOD, meth);

  if( ldtMap[LC.StoreMode] == SM_BINARY ) then
    -- >>>>>>>>>>>>>>>>>>>>>>>>> BINARY MODE <<<<<<<<<<<<<<<<<<<<<<<<<<<
    GP=F and trace("[DEBUG]<%s:%s> BINARY MODE FULL SCAN", MOD, meth );
    local byteArray = leafSubRec[LSR_BINARY_BIN];
    fullByteArrayScan( byteArray, ldtMap, resultList );
  else
    -- >>>>>>>>>>>>>>>>>>>>>>>>>  LIST  MODE <<<<<<<<<<<<<<<<<<<<<<<<<<<
    GP=F and trace("[DEBUG]<%s:%s> LIST MODE FULL SCAN", MOD, meth );
    local objectList = leafSubRec[LSR_LIST_BIN];
    fullListScan( objectList, ldtMap, resultList );
  end -- else list mode

  -- ResultList goes last -- if long, it gets truncated.
  GP=E and trace("[EXIT]<%s:%s> RSz(%d) result(%s)", MOD,
    meth, list.size(resultList), tostring(resultList));

  return 0;
end -- fullScanLeaf()

-- ======================================================================
-- scanLeaf(): Scan a Leaf Node, gathering up all of the the matching
-- value(s) in the leaf node(s).
-- ======================================================================
-- Once we've searched a B+ Tree and found "The Place", then we have the
-- option of Scanning for values, Inserting new objects or deleting existing
-- objects.  This is the function for gathering up one or more matching
-- values from the leaf node(s) and putting them in the result list.
-- Notice that if there are a LOT Of values that match the search value,
-- then we might read a lot of leaf nodes.
--
-- Leaf Node Structure:
-- (*) TopRec digest
-- (*) Parent rec digest
-- (*) This Rec digest
-- (*) NEXT Leaf
-- (*) PREV Leaf
-- (*) Min value is implicitly index 1,
-- (*) Max value is implicitly at index (size of list)
-- (*) Beginning of last value
-- Parms:
-- (*) topRec: 
-- (*) leafSubRec:
-- (*) startPosition:
-- (*) ldtMap:
-- (*) resultList:
-- (*) searchKey:
-- (*) flag:
-- Return: A, B, where A is the instruction and B is the return code
-- A: Instruction: 0 (stop), 1 (continue scanning)
-- B: Error Code: B==0 ok.   B < 0 Error.
-- ======================================================================
-- NOTE: Need to pass in leaf Rec and Start Position -- because the
-- searchPath will be WRONG if we continue the search on a second page.
local function scanLeaf(topRec, leafSubRec, startPosition, ldtMap, resultList,
                          searchKey, flag)
  local meth = "scanLeaf()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s>StartPosition(%s) SearchKey(%s)",
        MOD, meth, startPosition, tostring( searchKey));

  -- Linear scan of the Leaf Node (binary search will come later), for each
  -- match, add to the resultList.
  -- And -- do not confuse binary search (the algorithm for searching the page)
  -- with "Binary Mode", which is how we will compact values into a byte array
  -- for objects that can be transformed into a fixed size object.
  local compareResult = 0;
  -- local uniqueKey = ldtMap[LS.KeyUnique]; -- AS_TRUE or AS_FALSE;
  local scanStatus = SCAN.CONTINUE;
  local resultA = 0;
  local resultB = 0;

  GP=F and trace("[DEBUG]<%s:%s> Checking Store Mode(%s) (List or Binary?)",
    MOD, meth, tostring( ldtMap[LC.StoreMode] ));

  if( ldtMap[LC.StoreMode] == SM_BINARY ) then
    -- >>>>>>>>>>>>>>>>>>>>>>>>> BINARY MODE <<<<<<<<<<<<<<<<<<<<<<<<<<<
    GP=F and trace("[DEBUG]<%s:%s> BINARY MODE SCAN", MOD, meth );
    local byteArray = leafSubRec[LSR_BINARY_BIN];
    resultA, resultB = byteArrayScan( byteArray, startPosition, ldtMap,
                        resultList, searchKey, flag);
  else
    -- >>>>>>>>>>>>>>>>>>>>>>>>>  LIST  MODE <<<<<<<<<<<<<<<<<<<<<<<<<<<
    GP=F and trace("[DEBUG]<%s:%s> LIST MODE SCAN", MOD, meth );
    -- Do the List page mode search here
    -- Later: Split the loop search into two -- atomic and map objects
    local objectList = leafSubRec[LSR_LIST_BIN];
    resultA, resultB = listScan(objectList, startPosition, ldtMap,
                  resultList, searchKey, flag);
  end -- else list mode

  -- ResultList goes last -- if long, it gets truncated.
  GP=E and trace("[EXIT]<%s:%s> rc(%d) A(%s) B(%s) RSz(%d) result(%s)", MOD,
    meth, rc, tostring(resultA), tostring(resultB),
    list.size(resultList), tostring(resultList));

  return resultA, resultB;
end -- scanLeaf()

-- ======================================================================
-- treeSearch()
-- ======================================================================
-- Search the tree (start with the root and move down). 
-- Remember the search path from root to leaf (and positions in each
-- node) so that insert, Scan and Delete can use this to set their
-- starting positions.
-- Parms:
-- (*) src: subrecContext: The pool of open subrecs
-- (*) topRec: The top level Aerospike Record
-- (*) sp: searchPath: A list of maps that describe each level searched
-- (*) ldtMap: 
-- (*) searchKey: If null, compares LESS THAN everything
-- Return: ST.FOUND(0) or ST.NOT_FOUND(-1)
-- And, implicitly, the updated searchPath Object.
-- ======================================================================
local function treeSearch( src, topRec, sp, ldtCtrl, searchKey )
  local meth = "treeSearch()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> searchKey(%s)", MOD,meth,tostring(searchKey));

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local treeLevels = ldtMap[LS.TreeLevel];

  GP=D and trace("[DEBUG]<%s:%s> ldtSummary(%s) CMap(%s) PMap(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl),tostring(ldtMap),tostring(propMap));

  -- Start the loop with the special Root, then drop into each successive
  -- inner node level until we get to a LEAF NODE.  We search the leaf node
  -- differently than the inner (and root) nodes, since they have OBJECTS
  -- and not keys.  To search a leaf we must compute the key (from the object)
  -- before we do the compare.
  local keyList = ldtMap[LS.RootKeyList];
  local keyCount = list.size( keyList );
  local objectList = nil;
  local objectCount = 0;
  local digestList = ldtMap[LS.RootDigestList];
  local position = 0;
  local nodeRec = topRec;
  local nodeCtrlMap;
  local resultMap;
  local digestString;

  GP=D and trace("\n\n >> ABOUT TO SEARCH TREE -- Starting with ROOT!!!! \n");

  for i = 1, treeLevels, 1 do
     GP=D and trace("\n\n >>>>>>>  SEARCH Loop TOP  <<<<<<<<< \n");
     GP=D and trace("[DEBUG]<%s:%s>Loop Iteration(%d) Lvls(%d)",
       MOD, meth, i, treeLevels);
     GP=D and trace("[TREE SRCH] it(%d) Lvls(%d) KList(%s) DList(%s) OList(%s)",
       i, treeLevels, tostring(keyList), tostring(digestList),
       tostring(objectList));
    if( i < treeLevels ) then
      -- It's a root or node search -- so search the keys
      GP=D and trace("[DEBUG]<%s:%s> UPPER NODE Search", MOD, meth );
      position = searchKeyList( ldtMap, keyList, searchKey );
      if( position < 0 ) then
        info("[ERROR]<%s:%s> searchKeyList Problem", MOD, meth );
        error( ldte.ERR_INTERNAL );
      end
      if( position == 0 ) then
        info("[ERROR]<%s:%s> searchKeyList Problem:Position ZERO", MOD, meth );
        error( ldte.ERR_INTERNAL );
      end
      updateSearchPath(sp,propMap,ldtMap,nodeRec,position,keyCount );

      -- Get ready for the next iteration.  If the next level is an inner node,
      -- then populate our keyList and nodeCtrlMap.
      -- If the next level is a leaf, then populate our ObjectList and LeafMap.
      -- Remember to get the STRING version of the digest in order to
      -- call "open_subrec()" on it.
      GP=F and trace("[DEBUG]Opening Digest Pos(%d) DList(%s) for NextLevel",
        position, tostring( digestList ));

      digestString = tostring( digestList[position] );
      GP=F and trace("[DEBUG]<%s:%s> Checking Next Level", MOD, meth );
      -- NOTE: we're looking at the NEXT level (tl - 1) and we must be LESS
      -- than that to be an inner node.
      if( i < (treeLevels - 1) ) then
        -- Next Node is an Inner Node. 
        GP=F and trace("[Opening NODE Subrec]<%s:%s> Digest(%s) Pos(%d)",
            MOD, meth, digestString, position );
        nodeRec = ldt_common.openSubRec( src, topRec, digestString );
        GP=F and trace("[Open Inner Node Results]<%s:%s>nodeRec(%s)",
          MOD, meth, tostring(nodeRec));
        nodeCtrlMap = nodeRec[NSR_CTRL_BIN];
        propMap = nodeRec[SUBREC_PROP_BIN];
        GP=F and trace("[DEBUG]<%s:%s> NEXT NODE: INNER NODE: Summary(%s)",
            MOD, meth, nodeSummaryString( nodeRec ));
        keyList = nodeRec[NSR_KEY_LIST_BIN];
        keyCount = list.size( keyList );
        digestList = nodeRec[NSR_DIGEST_BIN]; 
        GP=F and trace("[DEBUG]<%s:%s> NEXT NODE: Digests(%s) Keys(%s)",
            MOD, meth, tostring( digestList ), tostring( keyList ));
      else
        -- Next Node is a Leaf
        GP=F and trace("[Opening Leaf]<%s:%s> Digest(%s) Pos(%d) TreeLevel(%d)",
          MOD, meth, digestString, position, i+1);
        nodeRec = ldt_common.openSubRec( src, topRec, digestString );
        GP=F and trace("[Open Leaf Results]<%s:%s>nodeRec(%s)",
          MOD,meth,tostring(nodeRec));
        propMap = nodeRec[SUBREC_PROP_BIN];
        nodeCtrlMap = nodeRec[LSR_CTRL_BIN];
        GP=F and trace("[DEBUG]<%s:%s> NEXT NODE: LEAF NODE: Summary(%s)",
            MOD, meth, leafSummaryString( nodeRec ));
        objectList = nodeRec[LSR_LIST_BIN];
        objectCount = list.size( objectList );
      end
    else
      -- It's a leaf search -- so search the objects.  Note that objectList
      -- and objectCount were set on the previous loop iteration.
      GP=F and trace("[DEBUG]<%s:%s> LEAF NODE Search", MOD, meth );
      resultMap = searchObjectList( ldtMap, objectList, searchKey );
      if( resultMap.Status == 0 ) then
        GP=F and trace("[DEBUG]<%s:%s> LEAF Search Result::Pos(%d) Cnt(%d)",
          MOD, meth, resultMap.Position, objectCount);
        updateSearchPath( sp, propMap, ldtMap, nodeRec,
                  resultMap.Position, objectCount );
      else
        GP=F and trace("[SEARCH ERROR]<%s:%s> LeafSrch Result::Pos(%d) Cnt(%d)",
          MOD, meth, resultMap.Position, keyCount);
      end
    end -- if node else leaf.
  end -- end for each tree level

  if( resultMap ~= nil and resultMap.Status == 0 and resultMap.Found )
  then
    position = resultMap.Position;
  else
    position = 0;
  end

  if position > 0 then
    rc = ST.FOUND;
  else
    rc = ST.NOT_FOUND;
  end

  GP=E and trace("[EXIT]<%s:%s>RC(%d) SearchKey(%s) ResMap(%s) SearchPath(%s)",
      MOD,meth, rc, tostring(searchKey),tostring(resultMap),tostring(sp));

  return rc;
end -- treeSearch()

-- ======================================================================
-- Populate this leaf after a leaf split.
-- Parms:
-- (*) newLeafSubRec
-- (*) objectList
-- ======================================================================
local function populateLeaf( src, leafSubRec, objectList )
  local meth = "populateLeaf()";
  GP=E and trace("[ENTER]<%s:%s>ObjList(%s)",MOD,meth,tostring(objectList));

  local leafCtrlMap    = leafSubRec[LSR_CTRL_BIN];
  leafSubRec[LSR_LIST_BIN] = objectList;
  local count = list.size( objectList );
  leafCtrlMap[LF_ListEntryCount] = count;
  leafCtrlMap[LF_ListEntryTotal] = count;

  leafSubRec[LSR_CTRL_BIN] = leafCtrlMap;
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leafSubRec );

  GP=E and trace("[EXIT]<%s:%s> rc(0)", MOD, meth);
  return 0;
end -- populateLeaf()

-- ======================================================================
-- leafUpdate()
-- Use the search position to mark the location where we will OVERWRITE
-- the value.  This function does NOT perform any transformation.  It
-- it is assumed that any transformation from a Live Obj to a DB Obj has
-- already been done for the "newValue".
--
-- Parms:
-- (*) src: Sub-Rec Context
-- (*) topRec: Primary Record
-- (*) leafSubRec: the leaf subrecord
-- (*) ldtMap: LDT Control: needed for key type and storage mode
-- (*) newValue: Object to be inserted.
-- (*) position: If non-zero, then it's where we insert. Otherwise, we search
-- ======================================================================
local function
leafUpdate(src, topRec, leafSubRec, ldtMap, newValue, position)
  local meth = "leafUpdate()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> value(%s) ldtMap(%s)",
    MOD, meth, tostring(newValue), tostring(ldtMap));

  GP=D and trace("[NOTICE!]<%s:%s>Using LIST MODE ONLY:No Binary Support (yet)",
    MOD, meth );

  local objectList = leafSubRec[LSR_LIST_BIN];

  -- Unlike Insert, for Update we must point at a valid CURRENT object.
  -- So, position must be within the range of the list size.
  local listSize = list.size( objectList );
  if position >= 1 and position <= listSize then
    objectList[position] = newValue;
  else
    warn("[WARNING]<%s:%s> INVALID POSITION(%d) for List Size(%d)", MOD, meth,
    position, listSize);
    error(ldte.ERR_INTERNAL);
  end

  -- Notice that we do NOT update any counters. We just overwrote.

  leafSubRec[LSR_LIST_BIN] = objectList;
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leafSubRec );

  GP=E and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;
end -- leafUpdate()

-- ======================================================================
-- leafInsert()
-- Use the search position to mark the location where we have to make
-- room for the new value.
-- If we're at the end, we just append to the list.
-- Parms:
-- (*) src: Sub-Rec Context
-- (*) topRec: Primary Record
-- (*) leafSubRec: the leaf subrecord
-- (*) ldtMap: LDT Control: needed for key type and storage mode
-- (*) newKey: Search Key for newValue
-- (*) newValue: Object to be inserted.
-- (*) position: If non-zero, then it's where we insert. Otherwise, we search
-- ======================================================================
local function
leafInsert(src, topRec, leafSubRec, ldtMap, newKey, newValue, position)
  local meth = "leafInsert()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> key(%s) value(%s) ldtMap(%s)",
    MOD, meth, tostring(newKey), tostring(newValue), tostring(ldtMap));

  GP=D and trace("[NOTICE!]<%s:%s>Using LIST MODE ONLY:No Binary Support (yet)",
    MOD, meth );

  local objectList = leafSubRec[LSR_LIST_BIN];
  local leafCtrlMap =  leafSubRec[LSR_CTRL_BIN];

  if( position == 0 ) then
    GP=F and trace("[INFO]<%s:%s>Position is ZERO:must Search for position",
      MOD, meth );
    local resultMap = searchObjectList( ldtMap, objectList, newKey );
    position = resultMap.Position;
  end

  if( position <= 0 ) then
    info("[ERROR]<%s:%s> Search Path Position is out of range(%d)",
      MOD, meth, position);
    error( ldte.ERR_INTERNAL );
  end

  -- Move values around, if necessary, to put newValue in a "position"
  ldt_common.listInsert( objectList, newValue, position );

  -- Update Counters
  local itemCount = leafCtrlMap[LF_ListEntryCount];
  leafCtrlMap[LF_ListEntryCount] = itemCount + 1;
  -- local totalCount = leafCtrlMap[LF_ListEntryTotal];
  -- leafCtrlMap[LF_ListEntryTotal] = totalCount + 1;

  leafSubRec[LSR_LIST_BIN] = objectList;
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leafSubRec );

  GP=E and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;
end -- leafInsert()

-- ======================================================================
-- getNodeSplitPosition()
-- Find the right place to split the B+ Tree Inner Node (or Root)
-- TODO: @TOBY: Maybe find a more optimal split position
-- Right now this is a simple arithmethic computation (split the leaf in
-- half).  This could change to split at a more convenient location in the
-- leaf, especially if duplicates are involved.  However, that presents
-- other problems, so we're doing it the easy way at the moment.
-- Parms:
-- (*) ldtMap: main control map
-- (*) keyList: the key list in the node
-- (*) nodePosition: the place in the key list for the new insert
-- (*) newKey: The new value to be inserted
-- ======================================================================
local function getNodeSplitPosition( ldtMap, keyList, nodePosition, newKey )
  local meth = "getNodeSplitPosition()";
  GP=E and trace("[ENTER]<%s:%s> ", MOD, meth );
  GP=F and trace("[NOTICE!!]<%s:%s> Using Rough Approximation", MOD, meth );

  -- This is only an approximization
  local listSize = list.size( keyList );
  local result = (listSize / 2) + 1; -- beginning of 2nd half, or middle

  GP=E and trace("[EXIT]<%s:%s> result(%d)", MOD, meth, result );
  return result;
end -- getNodeSplitPosition

-- ======================================================================
-- getLeafSplitPosition()
-- Find the right place to split the B+ Tree Leaf
-- TODO: @TOBY: Maybe find a more optimal split position
-- Right now this is a simple arithmethic computation (split the leaf in
-- half).  This could change to split at a more convenient location in the
-- leaf, especially if duplicates are involved.  However, that presents
-- other problems, so we're doing it the easy way at the moment.
-- Parms:
-- (*) ldtMap: main control map
-- (*) objList: the object list in the leaf
-- (*) leafPosition: the place in the obj list for the new insert
-- (*) newValue: The new value to be inserted
-- ======================================================================
local function getLeafSplitPosition( ldtMap, objList, leafPosition, newValue )
  local meth = "getLeafSplitPosition()";
  GP=E and trace("[ENTER]<%s:%s> ", MOD, meth );
  GP=F and trace("[NOTICE!!]<%s:%s> Using Rough Approximation", MOD, meth );

  -- This is only an approximization
  local listSize = list.size( objList );
  local result = (listSize / 2) + 1; -- beginning of 2nd half, or middle

  GP=E and trace("[EXIT]<%s:%s> result(%d)", MOD, meth, result );
  return result;
end -- getLeafSplitPosition

-- ======================================================================
-- nodeInsert()
-- Insert a new key,digest pair into the node.  We pass in the actual
-- lists, not the nodeRec, so that we can treat Nodes and the Root in
-- the same way.  Thus, it is up to the caller to update the node (or root)
-- information, other than the list update, which is what we do here.
-- Parms:
-- (*) ldtMap:
-- (*) keyList:
-- (*) digestList:
-- (*) key:
-- (*) digest:
-- (*) position:
-- ======================================================================
local function nodeInsert( ldtMap, keyList, digestList, key, digest, position )
  local meth = "nodeInsert()";
  local rc = 0;

  GP=E and trace("[ENTER]<%s:%s> Pos(%d) KL(%s) DL(%s) key(%s) D(%s)",
    MOD, meth, position, tostring(keyList), tostring(digestList),
    tostring(key), tostring(digest));

  -- If the position is ZERO, then that means we'll have to do another search
  -- here to find the right spot.  Usually, position == 0 means we have
  -- to find the new spot after a split.  Sure, that could be calculated,
  -- but this (a new search) is safer -- for now.
  if( position == 0 ) then
    GP=F and trace("[INFO]<%s:%s>Position is ZERO:must Search for position",
      MOD, meth );
    position = searchKeyList( ldtMap, keyList, key );
  end

  -- Note that searchKeyList() returns either the index of the item searched
  -- for, OR the "insert location" of the searched-for item.  Either way,
  -- we insert at that location for both theh new value and the digest.
  -- Move values around, if necessary, to put key and digest in "position"
  ldt_common.listInsert( keyList, key, position );
  ldt_common.listInsert( digestList, digest, position );

  GP=E and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;

end -- nodeInsert()

-- ======================================================================
-- Populate this inner node after a child split.
-- Parms:
-- (*) nodeSubRec
-- (*) keyList
-- (*) digestList
-- ======================================================================
local function  populateNode( nodeSubRec, keyList, digestList)
  local meth = "populateNode()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> keyList(%s) digestList(%s)",
    MOD, meth, tostring(keyList), tostring(digestList));

  local nodeItemCount = list.size( keyList );
  nodeSubRec[NSR_KEY_LIST_BIN] = keyList;
  nodeSubRec[NSR_DIGEST_BIN] = digestList;

  local nodeCtrlMap = nodeSubRec[NSR_CTRL_BIN];
  nodeCtrlMap[ND_ListEntryCount] = nodeItemCount;
  nodeCtrlMap[ND_ListEntryTotal] = nodeItemCount;
  nodeSubRec[NSR_CTRL_BIN] = nodeCtrlMap;

  GP=E and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;
end -- populateNode()

-- ======================================================================
-- Create a new Inner Node Page and initialize it.
-- ======================================================================
-- createNodeRec( Interior Tree Nodes )
-- ======================================================================
-- Set the values in an Inner Tree Node Control Map and Key/Digest Lists.
-- There are potentially FIVE bins in an Interior Tree Node Record:
--
--    >>>>>>>>>>>>>12345678901234<<<<<< (14 char limit for Bin Names) 
-- (1) nodeSubRec['NsrControlBin']: The control Map (defined here)
-- (2) nodeSubRec['NsrKeyListBin']: The Data Entry List (when in list mode)
-- (3) nodeSubRec['NsrBinaryBin']: The Packed Data Bytes (when in Binary mode)
-- (4) nodeSubRec['NsrDigestBin']: The Data Entry List (when in list mode)
-- Pages are either in "List" mode or "Binary" mode (the whole tree is in
-- one mode or the other), so the record will employ only three fields.
-- Either Bins 1,2,4 or Bins 1,3,4.
--
-- NOTES:
-- (1) For the Digest Bin -- we'll be in LIST MODE for debugging, but
--     in BINARY mode for production.
-- (2) For the Digests (when we're in binary mode), we could potentially
-- save some space by NOT storing the Lock bits and the Partition Bits
-- since we force all of those to be the same,
-- we know they are all identical to the top record.  So, that would save
-- us 4 bytes PER DIGEST -- which adds up for 50 to 100 entries.
-- We would use a transformation method to transform a 20 byte value into
-- and out of a 16 byte value.
--
-- ======================================================================
-- Parms:
-- (*) src: subrecContext: The pool of open subrecords
-- (*) topRec: The main AS Record holding the LDT
-- (*) ldtCtrl: Main LDT Control Structure
-- Contents of a Node Record:
-- (1) SUBREC_PROP_BIN: Main record Properties go here
-- (2) NSR_CTRL_BIN:    Main Node Control structure
-- (3) NSR_KEY_LIST_BIN: Key List goes here
-- (4) NSR_DIGEST_BIN: Digest List (or packed binary) goes here
-- (5) NSR_BINARY_BIN:  Packed Binary Array (if used) goes here
-- ======================================================================
local function createNodeRec( src, topRec, ldtCtrl )
  local meth = "createNodeRec()";
  GP=E and trace("[ENTER]<%s:%s> ", MOD, meth );

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- Create the Aerospike Sub-Record, initialize the Bins (Ctrl, List).
  -- The createSubRec() handles the record type and the SRC.
  -- It also kicks out with an error if something goes wrong.
  local nodeSubRec = ldt_common.createSubRec( src, topRec, ldtCtrl, RT.SUB );
  local nodePropMap = nodeSubRec[SUBREC_PROP_BIN];
  local nodeCtrlMap = map();

  -- Notes:
  -- (1) Item Count is implicitly the KeyList size
  -- (2) All Max Limits, Key sizes and Obj sizes are in the root map
  nodeCtrlMap[ND_ListEntryCount] = 0;  -- Current # of entries in the node list
  nodeCtrlMap[ND_ListEntryTotal] = 0;  -- Total # of slots used in the node list
  nodeCtrlMap[ND_ByteEntryCount] = 0;  -- Bytes used (if in binary mode)

  -- Store the new maps in the record.
  nodeSubRec[SUBREC_PROP_BIN] = nodePropMap;
  nodeSubRec[NSR_CTRL_BIN]    = nodeCtrlMap;
  nodeSubRec[NSR_KEY_LIST_BIN] = list(); -- Holds the keys
  nodeSubRec[NSR_DIGEST_BIN] = list(); -- Holds the Digests -- the Rec Ptrs

  -- We now have one more Node.  Update the count.
  local nodeCount = ldtMap[LS.NodeCount];
  ldtMap[LS.NodeCount] = nodeCount + 1;

  -- NOTE: The SubRec business is Handled by subRecCreate().
  -- Also, If we had BINARY MODE working for inner nodes, we would initialize
  -- the Key BYTE ARRAY here.  However, the real savings would be in the
  -- leaves, so it may not be much of an advantage to use binary mode in nodes.

  GP=E and trace("[EXIT]<%s:%s> OK", MOD, meth);
  return nodeSubRec;
end -- createNodeRec()


-- ======================================================================
-- splitRootInsert()
-- Split this ROOT node, because after a leaf split and the upward key
-- propagation, there's no room in the ROOT for the additional key.
-- Root Split is different any other node split for several reasons:
-- (1) The Root Key and Digests Lists are part of the control map.
-- (2) The Root stays the root.  We create two new children (inner nodes)
--     that become a new level in the tree.
-- Parms:
-- (*) src: SubRec Context (for looking up open subrecs)
-- (*) topRec:
-- (*) sp: SearchPath (from the initial search)
-- (*) ldtCtrl:
-- (*) key:
-- (*) digest:
-- ======================================================================
local function splitRootInsert( src, topRec, sp, ldtCtrl, key, digest )
  local meth = "splitRootInsert()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> topRec(%s) SRC(%s) SP(%s) LDT(%s) Key(%s) ",
    MOD, meth,tostring(topRec), tostring(src), tostring(sp), tostring(key),
    tostring(digest));
  
  GP=D and trace("\n\n <><H><> !!! SPLIT ROOT !!! Key(%s)<><W><> \n",
    tostring( key ));

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  local rootLevel = 1;
  local rootPosition = sp.PositionList[rootLevel];

  local keyList = ldtMap[LS.RootKeyList];
  local digestList = ldtMap[LS.RootDigestList];

  -- Calculate the split position and the key to propagate up to parent.
  local splitPosition =
      getNodeSplitPosition( ldtMap, keyList, rootPosition, key );
  local splitKey = keyList[splitPosition];

  GP=F and trace("[STATUS]<%s:%s> Take and Drop::Pos(%d)Key(%s) Digest(%s)",
    MOD, meth, splitPosition, tostring(keyList), tostring(digestList));

    -- Splitting a node works as follows.  The node is split into a left
    -- piece, a right piece, and a center value that is propagated up to
    -- the parent (in this case, root) node.
    --              +---+---+---+---+---+
    -- KeyList      |111|222|333|444|555|
    --              +---+---+---+---+---+
    -- DigestList   A   B   C   D   E   F
    --
    --                      +---+
    -- New Parent Element   |333|
    --                      +---+
    --                     /X   Y\ 
    --              +---+---+   +---+---+
    -- KeyList Nd(x)|111|222|   |444|555|Nd(y)
    --              +---+---+   +---+---+
    -- DigestList   A   B   C   D   E   F
    --
  -- Our List operators :
  -- (*) list.take (take the first N elements) 
  -- (*) list.drop (drop the first N elements, and keep the rest) 
  -- will let us split the current Root node list into two node lists.
  -- We propagate up the split key (the new root value) and the two
  -- new inner node digests.  Remember that the Key List is ONE CELL
  -- shorter than the DigestList.
  local leftKeyList  = list.take( keyList, splitPosition - 1 );
  local rightKeyList = list.drop( keyList, splitPosition  );

  local leftDigestList  = list.take( digestList, splitPosition );
  local rightDigestList = list.drop( digestList, splitPosition );

  GP=D and trace("\n[DEBUG]<%s:%s>LKey(%s) LDig(%s) SKey(%s) RKey(%s) RDig(%s)",
    MOD, meth, tostring(leftKeyList), tostring(leftDigestList),
    tostring( splitKey ), tostring(rightKeyList), tostring(rightDigestList) );

  -- Create two new Child Inner Nodes -- that will be the new Level 2 of the
  -- tree.  The root gets One Key and Two Digests.
  local leftNodeRec  = createNodeRec( src, topRec, ldtCtrl );
  local rightNodeRec = createNodeRec( src, topRec, ldtCtrl );

  local leftNodeDigest  = record.digest( leftNodeRec );
  local rightNodeDigest = record.digest( rightNodeRec );

  -- This is a different order than the splitLeafInsert, but before we
  -- populate the new child nodes with their new lists, do the insert of
  -- the new key/digest value now.
  -- Figure out WHICH of the two nodes that will get the new key and
  -- digest. Insert the new value.
  -- Compare against the SplitKey -- if less, insert into the left node,
  -- and otherwise insert into the right node.
  local compareResult = keyCompare( key, splitKey );
  if( compareResult == CR.LESS_THAN ) then
    -- We choose the LEFT Node -- but we must search for the location
    nodeInsert( ldtMap, leftKeyList, leftDigestList, key, digest, 0 );
  elseif( compareResult >= CR.EQUAL  ) then -- this works for EQ or GT
    -- We choose the RIGHT (new) Node -- but we must search for the location
    nodeInsert( ldtMap, rightKeyList, rightDigestList, key, digest, 0 );
  else
    -- We got some sort of goofy error.
    info("[ERROR]<%s:%s> Compare Error: CR(%d)", MOD, meth, compareResult );
    error( ldte.ERR_INTERNAL );
  end

  -- Populate the new nodes with their Key and Digest Lists
  populateNode( leftNodeRec, leftKeyList, leftDigestList);
  populateNode( rightNodeRec, rightKeyList, rightDigestList);
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leftNodeRec );
  ldt_common.updateSubRec( src, rightNodeRec );

  -- Replace the Root Information with just the split-key and the
  -- two new child node digests (much like first Tree Insert).
  local keyList = list();
  list.append( keyList, splitKey );
  local digestList = list();
  list.append( digestList, leftNodeDigest );
  list.append( digestList, rightNodeDigest );

  -- The new tree is now one level taller
  local treeLevel = ldtMap[LS.TreeLevel];
  ldtMap[LS.TreeLevel] = treeLevel + 1;

  -- Update the Main control map with the new root lists.
  ldtMap[LS.RootKeyList] = keyList;
  ldtMap[LS.RootDigestList] = digestList;

  GP=E and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;
end -- splitRootInsert()

-- ======================================================================
-- splitNodeInsert()
-- Split this parent node, because after a leaf split and the upward key
-- propagation, there's no room in THIS node for the additional key.
-- Special case is "Root Split" -- and that's handled by the function above.
-- Just like the leaf split situation -- we have to be careful about 
-- duplicates.  We don't want to split in the middle of a set of duplicates,
-- if we can possibly avoid it.  If the WHOLE node is the same key value,
-- then we can't avoid it.
-- Parms:
-- (*) src: SubRec Context (for looking up open subrecs)
-- (*) topRec:
-- (*) sp: SearchPath (from the initial search)
-- (*) ldtCtrl:
-- (*) key:
-- (*) digest:
-- (*) level:
-- ======================================================================
local function splitNodeInsert( src, topRec, sp, ldtCtrl, key, digest, level )
  local meth = "splitNodeInsert()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> SRC(%s) SP(%s) LDT(%s) Key(%s) Lvl(%d)",
    MOD, meth, tostring(src), tostring(sp), tostring(key), tostring(digest),
    level );
  
  if( level == 1 ) then
    -- Special Split -- Root is handled differently.
    rc = splitRootInsert( src, topRec, sp, ldtCtrl, key, digest );
  else
    -- Ok -- "Regular" Inner Node Split Insert.
    -- We will split this inner node, use the existing node as the new
    -- "rightNode" and the newly created node as the new "LeftNode".
    -- We will insert the "splitKey" and the new leftNode in the parent.
    -- And, if the parent has no room, we'll recursively call this function
    -- to propagate the insert up the tree.  ((I hope recursion doesn't
    -- blow up the Lua environment!!!!  :-) ).

    GP=F and trace("\n\n <><!><> !!! SPLIT INNER NODE !!! <><E><> \n\n");

    -- Extract the property map and control map from the ldt bin list.
    local propMap = ldtCtrl[1];
    local ldtMap  = ldtCtrl[2];
    local ldtBinName = propMap[PM.BinName];

    local nodePosition = sp.PositionList[level];
    local nodeSubRecDigest = sp.DigestList[level];
    local nodeSubRec = sp.RecList[level];

    -- Open the Node get the map, Key and Digest Data
    local nodePropMap    = nodeSubRec[SUBREC_PROP_BIN];
    GP=F and
    trace("\n[DUMP]<%s:%s>Node Prop Map(%s)", MOD, meth, tostring(nodePropMap));

    local nodeCtrlMap    = nodeSubRec[NSR_CTRL_BIN];
    local keyList    = nodeSubRec[NSR_KEY_LIST_BIN];
    local digestList = nodeSubRec[NSR_DIGEST_BIN];

    -- Calculate the split position and the key to propagate up to parent.
    local splitPosition =
        getNodeSplitPosition( ldtMap, keyList, nodePosition, key );
    -- We already have a key list -- don't need to "extract".
    local splitKey = keyList[splitPosition];

    GP=F and
    trace("\n[DUMP]<%s:%s> Take and Drop:: Map(%s) KeyList(%s) DigestList(%s)",
    MOD, meth, tostring(nodeCtrlMap), tostring(keyList), tostring(digestList));

    -- Splitting a node works as follows.  The node is split into a left
    -- piece, a right piece, and a center value that is propagated up to
    -- the parent node.
    --              +---+---+---+---+---+
    -- KeyList      |111|222|333|444|555|
    --              +---+---+---+---+---+
    -- DigestList   A   B   C   D   E   F
    --
    --                      +---+
    -- New Parent Element   |333|
    --                      +---+
    --                     /     \
    --              +---+---+   +---+---+
    -- KeyList      |111|222|   |444|555|
    --              +---+---+   +---+---+
    -- DigestList   A   B   C   D   E   F
    --
    -- Our List operators :
    -- (*) list.take (take the first N elements) 
    -- (*) list.drop (drop the first N elements, and keep the rest) 
    -- will let us split the current Node list into two Node lists.
    -- We will always propagate up the new Key and the NEW left page (digest)
    local leftKeyList  = list.take( keyList, splitPosition - 1 );
    local rightKeyList = list.drop( keyList, splitPosition );

    local leftDigestList  = list.take( digestList, splitPosition );
    local rightDigestList = list.drop( digestList, splitPosition );

    GP=D and
    trace("\n[DEBUG]<%s:%s>: LeftKey(%s) LeftDig(%s) RightKey(%s) RightDig(%s)",
      MOD, meth, tostring(leftKeyList), tostring(leftDigestList),
      tostring(rightKeyList), tostring(rightDigestList) );

    local rightNodeRec = nodeSubRec; -- our new name for the existing node
    local leftNodeRec = createNodeRec( src, topRec, ldtCtrl );
    local leftNodeDigest = record.digest( leftNodeRec );

    -- This is a different order than the splitLeafInsert, but before we
    -- populate the new child nodes with their new lists, do the insert of
    -- the new key/digest value now.
    -- Figure out WHICH of the two nodes that will get the new key and
    -- digest. Insert the new value.
    -- Compare against the SplitKey -- if less, insert into the left node,
    -- and otherwise insert into the right node.
    local compareResult = keyCompare( key, splitKey );
    if( compareResult == CR.LESS_THAN ) then
      -- We choose the LEFT Node -- but we must search for the location
      nodeInsert( ldtMap, leftKeyList, leftDigestList, key, digest, 0 );
    elseif( compareResult >= CR.EQUAL  ) then -- this works for EQ or GT
      -- We choose the RIGHT (new) Node -- but we must search for the location
      nodeInsert( ldtMap, rightKeyList, rightDigestList, key, digest, 0 );
    else
      -- We got some sort of unexpected error.
      info("[ERROR]<%s:%s> Compare Error: CR(%d)", MOD, meth, compareResult );
      error( ldte.ERR_INTERNAL );
    end

    -- Populate the new nodes with their Key and Digest Lists
    populateNode( leftNodeRec, leftKeyList, leftDigestList);
    populateNode( rightNodeRec, rightKeyList, rightDigestList);
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leftNodeRec );
  ldt_common.updateSubRec( src, rightNodeRec );

  -- Update the parent node with the new Node information.  It is the job
  -- of this method to either split the parent or do a straight insert.
    
    GP=F and trace("\n\n CALLING INSERT PARENT FROM SPLIT NODE: Key(%s)\n",
      tostring(splitKey));

    insertParentNode(src, topRec, sp, ldtCtrl, splitKey,
      leftNodeDigest, level - 1 );
  end -- else regular (non-root) node split

  GP=F and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;

end -- splitNodeInsert()

-- ======================================================================
-- After a leaf split or a node split, this parent node gets a new child
-- value and digest.  This node might be the root, or it might be an
-- inner node.  If we have to split this node, then we'll perform either
-- a node split or a ROOT split (ugh) and recursively call this method
-- to insert one level up.  Of course, Root split is a special case, because
-- the root node is basically ensconced inside of the LDT control map.
-- Parms:
-- (*) src: The SubRec Context (holds open subrecords).
-- (*) topRec: The main record
-- (*) sp: the searchPath structure
-- (*) ldtCtrl: the main control structure
-- (*) key: the new key to be inserted
-- (*) digest: The new digest to be inserted
-- (*) level: The current level in searchPath of this node
-- ======================================================================
-- NOTE: This function is FORWARD-DECLARED, so it does NOT get a "local"
-- declaration here.
-- ======================================================================
function insertParentNode(src, topRec, sp, ldtCtrl, key, digest, level)
  local meth = "insertParentNode()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> SP(%s) Key(%s) Dig(%s) Level(%d)",
    MOD, meth, tostring(sp), tostring(key), tostring(digest), level );
  GP=D and trace("\n[DUMP]<%s> LDT(%s)", meth, ldtSummaryString(ldtCtrl) );
  GP=D and trace("\n\n STARTING INTO INSERT PARENT NODE \n\n");

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  -- Check the tree level.  If it's the root, we access the node data
  -- differently from a regular inner tree node.
  local listMax;
  local keyList;
  local digestList;
  local position = sp.PositionList[level];
  local nodeSubRec = nil;
  GP=D and trace("[DEBUG]<%s:%s> Lvl(%d) Pos(%d)", MOD, meth, level, position);
  if( level == 1 ) then
    -- Get the control and list data from the Root Node
    listMax    = ldtMap[LS.RootListMax];
    keyList    = ldtMap[LS.RootKeyList];
    digestList = ldtMap[LS.RootDigestList];
  else
    -- Get the control and list data from a regular inner Tree Node
    nodeSubRec = sp.RecList[level];
    if( nodeSubRec == nil ) then
      warn("[ERROR]<%s:%s> Nil NodeRec from SearchPath. Level(%s)",
        MOD, meth, tostring(level));
      error( ldte.ERR_INTERNAL );
    end
    listMax    = ldtMap[LS.NodeListMax];
    keyList    = nodeSubRec[NSR_KEY_LIST_BIN];
    digestList = nodeSubRec[NSR_DIGEST_BIN];
  end

  -- If there's room in this node, then this is easy.  If not, then
  -- it's a complex split and propagate.
  if( sp.HasRoom[level] ) then
    -- Regular node insert
    rc = nodeInsert( ldtMap, keyList, digestList, key, digest, position );
    -- If it's a node, then we have to re-assign the list to the subrec
    -- fields -- otherwise, the change may not take effect.
    if( rc == 0 ) then
      if( level > 1 ) then
        nodeSubRec[NSR_KEY_LIST_BIN] = keyList;
        nodeSubRec[NSR_DIGEST_BIN]   = digestList;
        -- Call update to mark the SubRec as dirty, and to force the write
        -- if we are in "early update" mode. Close will happen at the end
        -- of the Lua call.
        ldt_common.updateSubRec( src, nodeSubRec );
      end
    else
      -- Bummer.  Errors.
      warn("[ERROR]<%s:%s> Parent Node Errors in NodeInsert", MOD, meth );
      error( ldte.ERR_INTERNAL );
    end
  else
    -- Complex node split and propagate up to parent.  Special case is if
    -- this is a ROOT split, which is different.
    rc = splitNodeInsert( src, topRec, sp, ldtCtrl, key, digest, level);
  end

  GP=F and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;
end -- insertParentNode()

-- ======================================================================
-- createLeafRec()
-- ======================================================================
-- Create a new Leaf Page and initialize it.
-- NOTE: Remember that we must create an ESR when we create the first leaf
-- but that is the caller's job
-- Contents of a Leaf Record:
-- (1) SUBREC_PROP_BIN: Main record Properties go here
-- (2) LSR_CTRL_BIN:    Main Leaf Control structure
-- (3) LSR_LIST_BIN:    Object List goes here
-- (4) LSR_BINARY_BIN:  Packed Binary Array (if used) goes here
-- 
-- Parms:
-- (*) src: subrecContext: The pool of open subrecords
-- (*) topRec: The main AS Record holding the LDT
-- (*) ldtCtrl: Main LDT Control Structure
-- (*) firstValue: If present, store this first value in the leaf.
-- (*) valueList: If present, store this value LIST in the leaf.  Note that
--     "firstValue" and "valueList" are mutually exclusive.  If BOTH are
--     non-NIL, then the valueList wins (firstValue not inserted).
--
-- (*) pd: previous (left) Leaf Digest (or 0, if not there)
-- (*) nd: next (right) Leaf Digest (or 0, if not there)
-- ======================================================================
local function createLeafRec( src, topRec, ldtCtrl, firstValue, valueList )
  local meth = "createLeafRec()";
  GP=E and trace("[ENTER]<%s:%s> ldtSum(%s) firstVal(%s)", MOD, meth,
    ldtSummaryString(ldtCtrl), tostring(firstValue));

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- Create the Aerospike Sub-Record, initialize the Bins (Ctrl, List).
  -- The createSubRec() handles the record type and the SRC.
  -- It also kicks out with an error if something goes wrong.
  local leafSubRec = ldt_common.createSubRec( src, topRec, ldtCtrl, RT.LEAF );
  local leafPropMap = leafSubRec[SUBREC_PROP_BIN];
  local leafCtrlMap = map();

  -- Store the new maps in the record.
  -- leafSubRec[SUBREC_PROP_BIN] = leafPropMap; (Already Set)
  leafSubRec[LSR_CTRL_BIN]    = leafCtrlMap;
  local leafItemCount = 0;

  local topDigest = record.digest( topRec );
  local leafDigest = record.digest( leafSubRec );
  
  GP=D and trace("[DEBUG]<%s:%s> Checking Store Mode(%s) (List or Binary?)",
    MOD, meth, tostring( ldtMap[LC.StoreMode] ));

  if( ldtMap[LC.StoreMode] == SM_LIST ) then
    -- <><> List Mode <><>
    GP=D and trace("[DEBUG]: <%s:%s> Initialize in LIST mode", MOD, meth );
    leafCtrlMap[LF_ByteEntryCount] = 0;
    -- If we have an initial value, then enter that in our new object list.
    -- Otherwise, create an empty list.
    local objectList;
    local leafItemCount = 0;

    -- If we have a value (or list) passed in, process it.
    if ( valueList ~= nil ) then
      objectList = valueList;
      leafItemCount = list.size(valueList);
    else
      objectList = list();
      if ( firstValue ~= nil ) then
        list.append( objectList, firstValue );
        leafItemCount = 1;
      end
    end

    -- Store stats and values in the new Sub-Record
    leafSubRec[LSR_LIST_BIN] = objectList;
    leafCtrlMap[LF_ListEntryCount] = leafItemCount;
    leafCtrlMap[LF_ListEntryTotal] = leafItemCount;

  else
    -- <><> Binary Mode <><>
    GP=D and trace("[DEBUG]: <%s:%s> Initialize in BINARY mode", MOD, meth );
    warn("[WARNING!!!]<%s:%s>BINARY MODE Still Under Construction!",MOD,meth );
    leafCtrlMap[LF_ListEntryTotal] = 0;
    leafCtrlMap[LF_ListEntryCount] = 0;
    leafCtrlMap[LF_ByteEntryCount] = 0;
  end

  -- Take our new structures and put them in the leaf record.
  -- Note: leafSubRec[SUBREC_PROP_BIN]  is Already Set
  leafSubRec[LSR_CTRL_BIN] = leafCtrlMap;

  ldt_common.updateSubRec( src, leafSubRec );

  -- We now have one more Leaf.  Update the count
  local leafCount = ldtMap[LS.LeafCount];
  ldtMap[LS.LeafCount] = leafCount + 1;
  
  -- Note that the caller will write out the record, since there will
  -- possibly be more to do (like add data values to the object list).
  GP=F and trace("[STATE]<%s:%s> TopRec Digest(%s) Leaf Digest(%s))",
    MOD, meth, tostring(topDigest), tostring(leafDigest));

  GP=F and trace("[STATE]<%s:%s> LeafPropMap(%s) Leaf Map(%s)",
    MOD, meth, tostring(leafPropMap), tostring(leafCtrlMap));

  -- Show the state of the new Leaf:
  GP=DEBUG and printLeaf(leafSubRec);

  GP=F and trace("[EXIT]<%s:%s> OK", MOD, meth);
  return leafSubRec;
end -- createLeafRec()

-- ======================================================================
-- splitLeafInsert()
-- We already know that there isn't enough room for the item, so we'll
-- have to split the leaf in order to insert it.
-- The searchPath position tells us the insert location in THIS leaf,
-- but, since this leaf will have to be split, it gets more complicated.
-- We split, THEN decide which leaf to use.
-- ALSO -- since we don't want to split the page in the middle of a set of
-- duplicates, we have to find the closest "key break" to the middle of
-- the page.  More thinking needed on how to handle duplicates without
-- making the page MUCH more complicated.
-- For now, we'll make the split easier and just pick the middle item,
-- but in doing that, it will make the scanning more complicated.
-- Parms:
-- (*) src: subrecContext
-- (*) topRec
-- (*) sp: searchPath
-- (*) ldtCtrl
-- (*) newKey
-- (*) newValue
-- Return:
-- ======================================================================
local function
splitLeafInsert( src, topRec, sp, ldtCtrl, newKey, newValue )
  local meth = "splitLeafInsert()";

  GP=B and info("\n\n <><><> !!! SPLIT LEAF !!! <><><> \n\n");

  GP=E and trace("[ENTER]<%s:%s> Key(%s) Val(%s)",
    MOD, meth, tostring(newKey), tostring(newValue));

  GP=D and trace("[DEBUG]<%s:%s> SearchPath(%s)", MOD, meth, tostring(sp));
  GP=D and trace("[DEBUG]<%s:%s> LDT Summary(%s) ",
    MOD, meth, ldtSummaryString(ldtCtrl));

  -- Splitting a leaf works as follows.  It is slightly different than a
  -- node split.  The leaf is split into a left piece and a right piece. 
  --
  -- The first element if the right leaf becomes the new key that gets
  -- propagated up to the parent.  This is the main difference between a Leaf
  -- split and a node split.  The leaf split uses a COPY of the key, whereas
  -- the node split removes that key from the node and moves it to the parent.
  --
  --  Inner Node   +---+---+
  --  Key List     |111|888|
  --               +---+---+
  --  Digest List  A   B   C
  --
  -- +---+---+    +---+---+---+---+---+    +---+---+
  -- | 50| 88|    |111|222|333|444|555|    |888|999|
  -- +---+---+    +---+---+---+---+---+    +---+---+
  -- Leaf A       Leaf B                   Leaf C
  --
  --                      +---+
  -- Copy of key element  |333|
  -- moves up to parent   +---+
  -- node.                ^ ^ ^ 
  --              +---+---+   +---+---+---+
  --              |111|222|   |333|444|555|
  --              +---+---+   +---+---+---+
  --              Leaf B1     Leaf B2
  --
  --  Inner Node   +---+---+---+
  --  Key List     |111|333|888|
  --               +---+---+---+
  --  Digest List  A   B1  B2  C
  --
  -- +---+---+    +---+---+   +---+---+---+    +---+---+
  -- | 50| 88|    |111|222|   |333|444|555|    |888|999|
  -- +---+---+    +---+---+   +---+---+---+    +---+---+
  -- Leaf A       Leaf B1     Leaf B2          Leaf C
  --
  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  local leafLevel = sp.LevelCount;
  local leafPosition = sp.PositionList[leafLevel];
  local leafSubRecDigest = sp.DigestList[leafLevel];
  local leafSubRec = sp.RecList[leafLevel];

  -- Open the Leaf and look inside.
  local objectList = leafSubRec[LSR_LIST_BIN];

  -- Calculate the split position and the key to propagate up to parent.
  local splitPosition =
      getLeafSplitPosition( ldtMap, objectList, leafPosition, newValue );
  local splitKey = getKeyValue( ldtMap, objectList[splitPosition] );

  GP=F and trace("[STATUS]<%s:%s> Got Split Key(%s) at position(%d)",
    MOD, meth, tostring(splitKey), splitPosition );

  GP=F and trace("[STATUS]<%s:%s> About to Take and Drop:: List(%s)",
    MOD, meth, tostring(objectList));

  -- Our List operators :
  -- (*) list.take (take the first N elements) 
  -- (*) list.drop (drop the first N elements, and keep the rest) 
  -- will let us split the current leaf list into two leaf lists.
  -- We will always propagate up the new Key and the NEW left page (digest)
  local leftList  = list.take( objectList, splitPosition - 1 );
  local rightList = list.drop( objectList, splitPosition - 1 );

  GP=F and trace("\n[STATE]<%s:%s>: LeftList(%s) SplitKey(%s) RightList(%s)",
    MOD, meth, tostring(leftList), tostring(splitKey), tostring(rightList) );

  local rightLeafRec = leafSubRec; -- our new name for the existing leaf
  local leftLeafRec = createLeafRec( src, topRec, ldtCtrl, nil );
  local leftLeafDigest = record.digest( leftLeafRec );

  -- Overwrite the leaves with their new object value lists
  populateLeaf( src, leftLeafRec, leftList );
  populateLeaf( src, rightLeafRec, rightList );

  -- Update the Page Pointers: Given that they are doubly linked, we can
  -- easily find the ADDITIONAL page that we have to open so that we can
  -- update its next-page link.  If we had to go up and down the tree to find
  -- it (the near LEFT page) that would be a horrible HORRIBLE experience.
  adjustLeafPointersAfterInsert(src,topRec,ldtMap,leftLeafRec,rightLeafRec);

  -- Now figure out WHICH of the two leaves (original or new) we have to
  -- insert the new value.
  -- Compare against the SplitKey -- if less, insert into the left leaf,
  -- and otherwise insert into the right leaf.
  local compareResult = keyCompare( newKey, splitKey );
  if( compareResult == CR.LESS_THAN ) then
    -- We choose the LEFT Leaf -- but we must search for the location
    leafInsert(src, topRec, leftLeafRec, ldtMap, newKey, newValue, 0);
  elseif( compareResult >= CR.EQUAL  ) then -- this works for EQ or GT
    -- We choose the RIGHT (new) Leaf -- but we must search for the location
    leafInsert(src, topRec, rightLeafRec, ldtMap, newKey, newValue, 0);
  else
    -- We got some sort of goofy error.
    warn("[ERROR]<%s:%s> Compare Error(%d)", MOD, meth, compareResult );
    error( ldte.ERR_INTERNAL );
  end

  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leftLeafRec );
  ldt_common.updateSubRec( src, rightLeafRec );

  -- Update the parent node with the new leaf information.  It is the job
  -- of this method to either split the parent or do a straight insert.
  GP=F and trace("\n\n CALLING INSERT PARENT FROM SPLIT LEAF: Key(%s)\n",
    tostring(splitKey));
  insertParentNode(src, topRec, sp, ldtCtrl, splitKey,
    leftLeafDigest, leafLevel - 1 );

  GP=F and trace("[EXIT]<%s:%s> rc(0)", MOD, meth );
  return 0;
end -- splitLeafInsert()

-- ======================================================================
-- buildNewTree( src, topRec, ldtMap, leftLeafList, splitKey, rightLeafList );
-- ======================================================================
-- Build a brand new tree -- from the contents of the Compact List.
-- This is the efficient way to construct a new tree.
-- Note that this function is assumed to take data from the Compact List.
-- It is not meant for LARGE lists, where the supplied LEFT and RIGHT lists
-- could each overflow a single leaf.
--
-- Parms:
-- (*) src: SubRecContext
-- (*) topRec
-- (*) ldtCtrl
-- (*) leftLeafList
-- (*) splitKeyValue: The new Key for the ROOT LIST.
-- (*) rightLeafList )
-- ======================================================================
local function buildNewTree( src, topRec, ldtCtrl,
                             leftLeafList, splitKeyValue, rightLeafList )
  local meth = "buildNewTree()";

  GP=E and trace("[ENTER]<%s:%s> LeftList(%s) SKey(%s) RightList(%s)",MOD,meth,
    tostring(leftLeafList), tostring(splitKeyValue), tostring(rightLeafList));

  GP=D and trace("[DEBUG]<%s:%s> LdtSummary(%s)",
    MOD, meth, ldtSummaryString( ldtCtrl ));

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  -- These are set on create -- so we can use them, even though they are
  -- (or should be) empty.
  local rootKeyList = ldtMap[LS.RootKeyList];
  local rootDigestList = ldtMap[LS.RootDigestList];

  -- Create two leaves -- Left and Right. Initialize them.  Then
  -- assign our new value lists to them.
  local leftLeafRec = createLeafRec( src, topRec, ldtCtrl, nil, leftLeafList);
  local leftLeafDigest = record.digest( leftLeafRec );
  ldtMap[LS.LeftLeafDigest] = leftLeafDigest; -- Remember Left-Most Leaf

  local rightLeafRec = createLeafRec( src, topRec, ldtCtrl, nil, rightLeafList);
  local rightLeafDigest = record.digest( rightLeafRec );
  ldtMap[LS.RightLeafDigest] = rightLeafDigest; -- Remember Right-Most Leaf

  -- Our leaf pages are doubly linked -- we use digest values as page ptrs.
  setLeafPagePointers( src, leftLeafRec, 0, rightLeafDigest );
  setLeafPagePointers( src, rightLeafRec, leftLeafDigest, 0 );

  GP=F and trace("[STATE]<%s:%s>Created Left(%s) and Right(%s) Records",
    MOD, meth, tostring(leftLeafDigest), tostring(rightLeafDigest) );

  -- Build the Root Lists (key and digests)
  list.append( rootKeyList, splitKeyValue );
  list.append( rootDigestList, leftLeafDigest );
  list.append( rootDigestList, rightLeafDigest );

  ldtMap[LS.TreeLevel] = 2; -- We can do this blind, since it's special.

  -- Note: The caller will update the top record, but we need to update the
  -- subrecs here.
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leftLeafRec );
  ldt_common.updateSubRec( src, rightLeafRec );

  GP=F and trace("[EXIT]<%s:%s>Return OK: ldtMap(%s) newKey(%s)",
    MOD, meth, tostring(ldtMap), tostring(splitKeyValue));
  return 0;
end -- buildNewTree()

-- ======================================================================
-- firstTreeInsert()
-- ======================================================================
-- For the VERY FIRST INSERT, we don't need to search.  We just put the
-- first key in the root, and we allocate TWO leaves: the left leaf for
-- values LESS THAN the first value, and the right leaf for values
-- GREATER THAN OR EQUAL to the first value.
--
-- In general, we build our tree from the Compact List, but in those
-- cases where the Objects being stored are too large to hold in the
-- compact List (even for a little bit), we start directly with
-- a tree insert.
--
-- NOTE: There's a special condition to be aware of.  When we are doing
-- sorted inserts, like for timeseries, the left leaf will just stay
-- empty because all subsequent values will be greater than or equal to
-- the first value.   We may have to switch "firstTreeInsert()" to use
-- a SINGLE LEAF, with no key, as the initial tree.  That means that
-- a special test will be needed for "MINIMAL TREE" when doing searches
-- or inserts.
--
-- NOTE: Similarly, when splitting a TIMESERIES Leaf, we should not split
-- the leaf in the middle but should instead split it at the very right,
-- because all subsequent values will flow into the next leaf.
--
-- Parms:
-- (*) src: SubRecContext
-- (*) topRec
-- (*) ldtCtrl
-- (*) newValue
-- ======================================================================
local function firstTreeInsert( src, topRec, ldtCtrl, newValue )
  local meth = "firstTreeInsert()";
  
  GP=E and trace("[ENTER]<%s:%s> newValue(%s) LdtSummary(%s)",
    MOD, meth, tostring(newValue), ldtSummaryString(ldtCtrl) );

  -- We know that on the VERY FIRST SubRecord create, we want to create
  -- the Existence Sub Record (ESR).  So, do this first.
  --NOT NEEDED -- ESR will be created by createLeafRec()
  --local esrDigest = createAndInitESR( src, topRec, ldtCtrl );

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  local rootKeyList = ldtMap[LS.RootKeyList];
  local rootDigestList = ldtMap[LS.RootDigestList];
  local keyValue = getKeyValue( ldtMap, newValue );

  -- Create two leaves -- Left and Right. Initialize them.  Then
  -- insert our new value into the RIGHT one.
  local leftLeafRec = createLeafRec( src, topRec, ldtCtrl, nil, nil );
  local leftLeafDigest = record.digest( leftLeafRec );
  ldtMap[LS.LeftLeafDigest] = leftLeafDigest; -- Remember Left-Most Leaf

  local rightLeafRec = createLeafRec( src, topRec, ldtCtrl, newValue, nil );
  local rightLeafDigest = record.digest( rightLeafRec );
  ldtMap[LS.RightLeafDigest] = rightLeafDigest; -- Remember Right-Most Leaf

  -- Our leaf pages are doubly linked -- we use digest values as page ptrs.
  setLeafPagePointers( src, leftLeafRec, 0, rightLeafDigest );
  setLeafPagePointers( src, rightLeafRec, leftLeafDigest, 0 );

  GP=F and trace("[STATE]<%s:%s>Created Left(%s) and Right(%s) Records",
    MOD, meth, tostring(leftLeafDigest), tostring(rightLeafDigest) );

  -- Insert our very first key into the root directory (no search needed),
  -- along with the two new child digests
  list.append( rootKeyList, keyValue );
  list.append( rootDigestList, leftLeafDigest );
  list.append( rootDigestList, rightLeafDigest );

  ldtMap[LS.TreeLevel] = 2; -- We can do this blind, since it's special.

  -- NOTE: Do NOT update the ItemCount.  The caller does that.
  -- Also, the lists are part of the ldtMap, so they DO NOT need updating.
  -- ldtMap[LS.RootKeyList] = rootKeyList;
  -- ldtMap[LS.RootDigestList] = rootDigestList;

  -- Note: The caller will update the top record, but we need to update the
  -- subrecs here.
  -- Call update to mark the SubRec as dirty, and to force the write if we
  -- are in "early update" mode. Close will happen at the end of the Lua call.
  ldt_common.updateSubRec( src, leftLeafRec );
  ldt_common.updateSubRec( src, rightLeafRec );

  GP=F and trace("[EXIT]<%s:%s>Return OK: LdtSummary(%s) newValue(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl), tostring(newValue));
  return 0;
end -- firstTreeInsert()

-- ======================================================================
-- treeInsert()
-- ======================================================================
-- Search the tree (start with the root and move down).  Get the spot in
-- the leaf where the insert goes.  Insert into the leaf.  Remember the
-- path on the way down, because if a leaf splits, we have to move back
-- up and potentially split the parents bottom up.
-- Parms:
-- (*) src: subrecContext: The pool of open subrecords
-- (*) topRec
-- (*) ldtCtrl
-- (*) value
-- (*) update: when true, we overwrite unique values rather than complain.
-- Return:
-- 0: All ok, Regular insert
-- 1: Ok, but we did an UPDATE, with no count increase.
-- ======================================================================
local function treeInsert( src, topRec, ldtCtrl, value, update )
  local meth = "treeInsert()";
  local rc = 0;
  
  GP=E and trace("[ENTER]<%s:%s>", MOD, meth );

  GP=F and trace("[PARMS]<%s:%s>value(%s) update(%s) LdtSummary(%s) ",
  MOD, meth, tostring(value), tostring(update), ldtSummaryString(ldtCtrl));

  local insertResult = 0; -- assume regular insert

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  local key = getKeyValue( ldtMap, value );

  -- For the VERY FIRST INSERT, we don't need to search.  We just put the
  -- first key in the root, and we allocate TWO leaves: the left leaf for
  -- values LESS THAN the first value, and the right leaf for values
  -- GREATER THAN OR EQUAL to the first value.
  -- Note: now that we're doing a batch insert after the conversion from
  -- "CompactList Mode" to Tree Mode, we no longer insert a single
  -- value as the first entry -- we instead start with a whole compact list.
  if( ldtMap[LS.TreeLevel] == 1 ) then
    GP=D and trace("[DEBUG]<%s:%s>\n\n<FFFF> FIRST TREE INSERT!!!\n",
        MOD, meth );
    firstTreeInsert( src, topRec, ldtCtrl, value );
  else
    GP=D and trace("[DEBUG]<%s:%s>\n\n<RRRR> Regular TREE INSERT(%s)!!!\n",
        MOD, meth, tostring(value));
    -- It's a real insert -- so, Search first, then insert
    -- Map: Path from root to leaf, with indexes
    -- The Search path is a map of values, including lists from root to leaf
    -- showing node/list states, counts, fill factors, etc.
    local sp = createSearchPath(ldtMap);
    local status = treeSearch( src, topRec, sp, ldtCtrl, key );
    local leafLevel = sp.LevelCount;
    local leafSubRec = sp.RecList[leafLevel];
    local position = sp.PositionList[leafLevel];

    -- If FOUND, then if UNIQUE, it's either an ERROR, or we are doing
    -- an Update (overwrite in place).
    -- Otherwise, if not UNIQUE, do the insert.
    if( status == ST.FOUND and ldtMap[LS.KeyUnique] == AS_TRUE ) then
      if update then
        -- TODO: Check for Room (available Space) when we have BYTE usage
        -- information.  For now, we're just going to overwrite the object
        -- and so we know we have a slot for it.
        -- Do the Leaf Update (overwrite in place)
        local leafSubRec = sp.RecList[leafLevel];
        local position = sp.PositionList[leafLevel];
        rc = leafUpdate(src, topRec, leafSubRec, ldtMap, value, position);
        -- Call update_subrec() to both mark the subRec as dirty, AND to write
        -- it out if we are in "early update" mode.  In general, Dirty SubRecs
        -- are also written out and closed at the end of the Lua Context.
        ldt_common.updateSubRec( src, leafSubRec );
        insertResult = 1; -- Special UPDATE (no count stats increase).
      else
        debug("[User ERROR]<%s:%s> Unique Key(%s) Violation",
          MOD, meth, tostring(value ));
        error( ldte.ERR_UNIQUE_KEY );
      end
      -- End of the UPDATE case
    else -- else, do INSERT

      GP=D and trace("[DEBUG]<%s:%s>LeafInsert: Level(%d): HasRoom(%s)",
        MOD, meth, leafLevel, tostring(sp.HasRoom[leafLevel] ));

      if( sp.HasRoom[leafLevel] ) then
        -- Regular Leaf Insert
        local leafSubRec = sp.RecList[leafLevel];
        local position = sp.PositionList[leafLevel];
        rc = leafInsert(src, topRec, leafSubRec, ldtMap, key, value, position);
        -- Call update_subrec() to both mark the subRec as dirty, AND to write
        -- it out if we are in "early update" mode.  In general, Dirty SubRecs
        -- are also written out and closed at the end of the Lua Context.
        ldt_common.updateSubRec( src, leafSubRec );
      else
        -- Split first, then insert.  This split can potentially propagate all
        -- the way up the tree to the root. This is potentially a big deal.
        splitLeafInsert( src, topRec, sp, ldtCtrl, key, value );
      end
    end -- Insert
  end -- end else "real" insert

  -- All of the subrecords were written out in the respective insert methods,
  -- so if all went well (we wouldn't be here otherwise), we'll now update the
  -- top record. Otherwise, we will NOT udate it.
  topRec[ldtBinName] = ldtCtrl;
  record.set_flags(topRec, ldtBinName, BF.LDT_BIN );--Must set every time
  rc = aerospike:update( topRec );
  if rc and rc ~= 0 then
    warn("[ERROR]<%s:%s>TopRec Update Error rc(%s)",MOD,meth,tostring(rc));
    error( ldte.ERR_TOPREC_UPDATE );
  end 

  GP=F and trace("[EXIT]<%s:%s>LdtSummary(%s) value(%s) rc(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl), tostring(value), tostring(rc));
  return insertResult;
end -- treeInsert

-- ======================================================================
-- getNextLeaf( src, topRec, leafSubRec  )
-- Our Tree Leaves are doubly linked -- so from any leaf we can move 
-- right or left.  Get the next leaf (right neighbor) in the chain.
-- This is called primarily by scan(), so the pages should be clean.
-- ======================================================================
local function getNextLeaf( src, topRec, leafSubRec  )
  local meth = "getNextLeaf()";
  GP=E and trace("[ENTER]<%s:%s> TopRec(%s) src(%s) LeafSummary(%s)",
    MOD, meth, tostring(topRec), tostring(src), leafSummaryString(leafSubRec));

  local leafSubRecMap = leafSubRec[LSR_CTRL_BIN];
  local nextLeafDigest = leafSubRecMap[LF_NextPage];

  local nextLeaf = nil;
  local nextLeafDigestString;

  -- Close the current leaf before opening the next one.  It should be clean,
  -- so closing is ok.
  -- aerospike:close_subrec( leafSubRec );
  ldt_common.closeSubRec( src, leafSubRec, false);

  if( nextLeafDigest ~= nil and nextLeafDigest ~= 0 ) then
    nextLeafDigestString = tostring( nextLeafDigest );
    GP=F and trace("[OPEN SUB REC]:<%s:%s> Digest(%s)",
      MOD, meth, nextLeafDigestString);

    nextLeaf = ldt_common.openSubRec( src, topRec, nextLeafDigestString )
    if( nextLeaf == nil ) then
      warn("[ERROR]<%s:%s> Can't Open Leaf(%s)",MOD,meth,nextLeafDigestString);
      error( ldte.ERR_SUBREC_OPEN );
    end
  end

  GP=F and trace("[EXIT]<%s:%s> Returning NextLeaf(%s)",
     MOD, meth, leafSummaryString( nextLeaf ) );
  return nextLeaf;

end -- getNextLeaf()

-- ======================================================================
-- createStoredObject()
-- ======================================================================
-- If there's a TRANSFORM function present, apply it and return the
-- transformed "Stored Object".
-- ======================================================================
local function createStoredObject( liveObject )
  if( G_Transform ~= nil ) then
    return G_Transform( liveObject );
  else
    return liveObject;
  end
end -- createStoredObject()

-- ======================================================================
-- getLiveObject()
-- ======================================================================
-- If there's an UNTRANSFORM function present, apply it and return the
-- transformed "Live Object".
-- ======================================================================
local function getLiveObject( storedObject )
    
  if( G_UnTransform ~= nil ) then
    return G_UnTransform( storedObject );
  else
    return storedObject;
  end
end -- getLiveObject()

-- ======================================================================
-- computeDuplicateSplit()
-- ======================================================================
-- From a list of objects that may contain duplicates, we have to find
-- a split point that is NOT in the middle of a set of duplicates.
--              +---+---+---+---+---+---+
-- ObjectList   |222|333|333|333|333|444|
--              +---+---+---+---+---+---+
-- Offsets        1   2   3   4   5   6
-- We start at the middle point (offset 3 of 6 in this example) and look
-- increasingly on either side until we find a NON-MATCH (offset 4, then 2,
-- then 5, then 1 (success));
-- Parms:
-- (*) ldtMan
-- (*) ObjectList
-- Return: Position of the split, or ZERO if there's no split location
-- ======================================================================
-- Note that all lists, including the Compact List, must go thru the
-- Transform/Untransform step.
-- ======================================================================
local function computeDuplicateSplit(ldtMap, objectList)
  local meth = "computeDuplicateSplit()";

  GP=E and trace("[ENTER]<%s:%s> ObjectList(%s)", MOD, meth,
    tostring(objectList));

  if objectList == nil then
    warn("[ERROR]<%s:%s> NIL object list", MOD, meth);
    error(ldte.ERR_INTERNAL);
  end

  local objectListSize = #objectList;
  if objectListSize <= 1 then
    GP=E and debug("[EARLY EXIT]<%s:%s> ObjectList(%s) Too Small", MOD,
      meth, tostring(objectList));
    return 0;
  end

  -- Remove this if we do not need it.
  local keyType = ldtMap[LC.KeyType];

  -- Start at the BEST position (the middle), and find the closest place
  -- to there to split.
  local startPosition = math.floor(list.size(objectList) / 2);
  local liveObject = getLiveObject(objectList[startPosition]);
  local startKey = getKeyValue( ldtMap, liveObject );
  local listLength = #objectList;
  local direction = 1; -- Start with first probe towards the end.
  local flip = -1;
  local compareKey;
  local probeIndex;

  -- Iterate, starting from the middle.  The startKey is set for the
  -- first itetation.
  for i = 1, listLength do
    probeIndex = (direction * i) + startPosition;
    GP=D and debug("[DEBUG]<%s:%s> Probe(%d)", MOD, meth, probeIndex);
    if probeIndex > 0 and probeIndex <= listLength then
      liveObject = getLiveObject(ldtMap, objectList[probeIndex]);
      compareKey = getKeyValue(ldtMap, liveObject);
      GP=D and debug("[DEBUG]<%s:%s> Compare StartKey(%s) and CompKey(%s)",
        MOD, meth, tostring(startKey), tostring(compareKey));
      if compareKey ~= startKey then
        -- We found it.  Return with THIS position.
        GP=E and debug("[EXIT]<%s:%s> Success. Pos(%d)", MOD, meth, probeIndex);
        return probeIndex;
      end
    end
    -- Compute for next round.  Flip the direction
    direction = direction * flip;
  end -- for each Obj.. probing from the middle

  GP=E and debug("[EXIT]<%s:%s> Failure. Pos(0)", MOD, meth);
  return 0;
end -- computeDuplicateSplit()

-- ======================================================================
-- convertList( src, topRec, ldtBinName, ldtCtrl )
-- ======================================================================
-- When we start in "compact" StoreState (SS_COMPACT), we eventually have
-- to switch to "regular" tree state when we get enough values.  So, at some
-- point (StoreThreshold), we take our simple list and then insert into
-- the B+ Tree.
-- Now, convertList does the SMART thing and builds the tree from the 
-- compact list without doing any tree inserts.
-- Parms:
-- (*) src: subrecContext
-- (*) topRec
-- (*) ldtBinName
-- (*) ldtCtrl
-- ======================================================================
local function convertList(src, topRec, ldtBinName, ldtCtrl )
  local meth = "convertList()";

  GP=E and trace("[ENTER]<%s:%s>\n\n<><> CONVERT LIST <><>\n",MOD,meth);

  GP=F and trace("[DEBUG]<%s:%s> BinName(%s) LDT Summary(%s)", MOD, meth,
    tostring(ldtBinName), ldtSummaryString(ldtCtrl));
  
  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  -- Get the compact List, cut it in half, build the two leaves, and
  -- copy the min value of the right leaf into the root.
  local compactList = ldtMap[LS.CompactList];

  if compactList == nil then
    warn("[INTERNAL ERROR]:<%s:%s> Empty Compact list in LDT Bin(%s)",
      MOD, meth, tostring(ldtBinName));
    error( ldte.ERR_INTERNAL );
  end

  ldtMap[LS.StoreState] = SS_REGULAR; -- now in "regular" (modulo) mode

  -- There will be cases where the compact list is empty, but we're being
  -- asked to convert anyway.  No problem.  Just return.
  if #compactList == 0 then
    return 0;
  end

  -- Notice that the actual "split position" is AFTER the splitPosition
  -- value -- so if we were splitting 10, the list would split AFTER 5,
  -- and index 6 would be the first entry of the right list and thus the
  -- location of the split key.
  -- Also, we would like to be smart about our split.  If we have UNIQUE
  -- keys, we can pick any spot (e.g. the half-way point), but if we have
  -- potentially DUPLICATE keys, we need to split in a spot OTHER than
  -- in the middle of the duplicate list.
  local splitPosition;
  local splitValue;
  local leftLeafList;
  local rightLeafList;
  if ( ldtMap[LS.KeyUnique] == AS_TRUE ) then
    splitPosition = math.floor(list.size(compactList) / 2);
    splitValue = compactList[splitPosition + 1];
  -- Our List operators :
  -- (*) list.take (take the first N elements)
  -- (*) list.drop (drop the first N elements, and keep the rest)
    leftLeafList  =  list.take( compactList, splitPosition );
    rightLeafList =  list.drop( compactList, splitPosition );
  else
    -- It's possible that the entire compact list is composed of a single
    -- value (e.g. "7,7,7,7 ... 7,7,7"), in which case we have to treat the
    -- "split" specially.  In fact, the entire compact list would go into
    -- the RIGHT leaf, and the left leaf would remain empty.
    splitPosition = computeDuplicateSplit(compactList);
    if splitPosition > 0 then
      splitValue = compactList[splitPosition + 1];
      leftLeafList  =  list.take( compactList, splitPosition );
      rightLeafList =  list.drop( compactList, splitPosition );
    else
      -- The ENTIRE LIST is the same value.  Just use the first one for
      -- the "splitValue", and the entire list goes in the right leaf.
      splitValue = compactList[1];
      leftLeafList = list();
      rightLeafList = compactList;
    end
  end
  local splitKey = getKeyValue( ldtMap, splitValue );

  -- Toss the old Compact List;  No longer needed.  However, we must replace
  -- it with an EMPTY list, not a NIL.
  ldtMap[LS.CompactList] = list();

  -- Now build the new tree:
  buildNewTree( src, topRec, ldtCtrl, leftLeafList, splitKey, rightLeafList );

  GP=F and trace("[EXIT]: <%s:%s> ldtSummary(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl));
  return 0;
end -- convertList()

-- ======================================================================
-- Starting from the left-most leaf, scan all the way to the right-most
-- leaf.  This function does not filter, but it does UnTransform.
-- Parms:
-- (*) src: subrecContext
-- (*) resultList: stash the results here
-- (*) topRec: Top DB Record
-- (*) ldtCtrl: The Truth
-- Return: void
-- ======================================================================
local function fullTreeScan( src, resultList, topRec, ldtCtrl )
  local meth = "fullTreeScan()";
  GP=E and trace("[ENTER]<%s:%s> ", MOD, meth);

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- Scan all of the leaves.
  local leafDigest = ldtMap[LS.LeftLeafDigest];
  if leafDigest == nil or leafDigest == 0 then
    debug("[DEBUG]<%s:%s> Left Leaf Digest is NIL", MOD, meth);
    error(ldte.ERR_INTERNAL);
  end

  local leafDigestString = tostring(leafDigest);

  local leafSubRec = ldt_common.openSubRec(src, topRec, leafDigestString);
  while leafSubRec ~= nil and leafSubRec ~= 0 do
    fullScanLeaf(topRec, leafSubRec, ldtMap, resultList);
    leafSubRec = getNextLeaf( src, topRec, leafSubRec );
  end -- loop thru each subrec

  GP=F and trace("[EXIT]<%s:%s>ResultListSize(%d) ResultList(%s)",
      MOD, meth, list.size(resultList), tostring(resultList));

end -- fullTreeScan()

-- ======================================================================
-- Given the searchPath result from treeSearch(), Scan the leaves for all
-- values that satisfy the searchPredicate and the filter.
-- Parms:
-- (*) src: subrecContext
-- (*) resultList: stash the results here
-- (*) topRec: Top DB Record
-- (*) sp: Search Path Object
-- (*) ldtCtrl: The Truth
-- (*) key: the end marker: 
-- (*) flag: Either Scan while equal to end, or Scan until val > end.
-- ======================================================================
local function treeScan( src, resultList, topRec, sp, ldtCtrl, key, flag )
  local meth = "treeScan()";
  local scan_A = 0;
  local scan_B = 0;
  GP=E and trace("[ENTER]<%s:%s> searchPath(%s) key(%s)",
      MOD, meth, tostring(sp), tostring(key) );

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local leafLevel = sp.LevelCount;
  local leafSubRec = sp.RecList[leafLevel];

  local count = 0;
  local done = false;
  local startPosition = sp.PositionList[leafLevel];
  while not done do
    GP=D and trace("[LOOP DEBUG]<%s:%s>Loop Top: Count(%d)", MOD, meth, count );
    -- NOTE: scanLeaf() actually returns a "double" value -- the first is
    -- the scan instruction (stop=0, continue=1) and the second is the error
    -- return code.  So, if scan_B is "ok" (0), then we look to scan_A to see
    -- if we should continue the scan.
    scan_A, scan_B  = scanLeaf(topRec, leafSubRec, startPosition, ldtMap,
                              resultList, key, flag)

    -- Uncomment this next line to see the "LEAF BOUNDARIES" in the data.
    -- list.append(resultList, 999999 );

    -- Look and see if there's more scanning needed. If so, we'll read
    -- the next leaf in the tree and scan another leaf.
    if( scan_B < 0 ) then
      warn("[ERROR]<%s:%s> Problems in ScanLeaf() A(%s) B(%s)",
        MOD, meth, tostring( scan_A ), tostring( scan_B ) );
      error( ldte.ERR_INTERNAL );
    end
      
    if( scan_A == SCAN.CONTINUE ) then
      GP=F and trace("[STILL SCANNING]<%s:%s>", MOD, meth );
      startPosition = 1; -- start of next leaf
      leafSubRec = getNextLeaf( src, topRec, leafSubRec );
      if( leafSubRec == nil ) then
        GP=F and trace("[NEXT LEAF RETURNS NIL]<%s:%s>", MOD, meth );
        done = true;
      end
    else
      GP=F and trace("[DONE SCANNING]<%s:%s>", MOD, meth );
      done = true;
    end
  end -- while not done reading the T-leaves

  GP=F and trace("[EXIT]<%s:%s>SearchKey(%s) SP(%s) ResSz(%d) ResultList(%s)",
      MOD,meth,tostring(key),tostring(sp),list.size(resultList),
      tostring(resultList));

  return 0;
end -- treeScan()

-- ======================================================================
-- listDelete()
-- ======================================================================
-- General List Delete function that can be used to delete items or keys.
-- RETURN:
-- A NEW LIST that no longer contains the deleted item.
-- ======================================================================
local function listDelete( objectList, key, position )
  local meth = "listDelete()";
  local resultList;
  local listSize = list.size( objectList );

  GP=E and trace("[ENTER]<%s:%s>List(%s) size(%d) Key(%s) Position(%d)", MOD,
  meth, tostring(objectList), listSize, tostring(key), position );
  
  if( position < 1 or position > listSize ) then
    warn("[DELETE ERR]<%s:%s> Bad pos(%d) for delete: key(%s) ListSz(%d)",
      MOD, meth, position, tostring(key), listSize);
    error( ldte.ERR_DELETE );
  end

  -- Move elements in the list to "cover" the item at Position.
  --  +---+---+---+---+
  --  |111|222|333|444|   Delete item (333) at position 3.
  --  +---+---+---+---+
  --  Moving forward, Iterate:  list[pos] = list[pos+1]
  --  This is what you would THINK would work:
  -- for i = position, (listSize - 1), 1 do
  --   objectList[i] = objectList[i+1];
  -- end -- for()
  -- objectList[i+1] = nil;  (or, call trim() )
  -- However, because we cannot assign "nil" to a list, nor can we just
  -- trim a list, we have to build a NEW list from the old list, that
  -- contains JUST the pieces we want.
  -- So, basically, we're going to build a new list out of the LEFT and
  -- RIGHT pieces of the original list.
  --
  -- Eventually we'll have OPTIMIZED list functions that will do the
  -- right thing on the ServerSide (e.g. no mallocs, no allocs, etc).
  --
  -- Our List operators :
  -- (*) list.take (take the first N elements) 
  -- (*) list.drop (drop the first N elements, and keep the rest) 
  -- The special cases are:
  -- (*) A list of size 1:  Just return a new (empty) list.
  -- (*) We're deleting the FIRST element, so just use RIGHT LIST.
  -- (*) We're deleting the LAST element, so just use LEFT LIST
  if( listSize == 1 ) then
    resultList = list();
  elseif( position == 1 ) then
    resultList = list.drop( objectList, 1 );
  elseif( position == listSize ) then
    resultList = list.take( objectList, position - 1 );
  else
    resultList = list.take( objectList, position - 1);
    local addList = list.drop( objectList, position );
    local addLength = list.size( addList );
    for i = 1, addLength, 1 do
      list.append( resultList, addList[i] );
    end
  end

  -- When we do deletes with Dups -- we'll change this to have a 
  -- START position and an END position (or a length), rather than
  -- an assumed SINGLE cell.
  -- info("[NOTICE!!!]: >>>>>>>>>>>>>>>>>>>> <*>  <<<<<<<<<<<<<<<<<<<<<<");
     info("[NOTICE!!!]: Currently performing ONLY single item delete");
  -- info("[NOTICE!!!]: >>>>>>>>>>>>>>>>>>>> <*>  <<<<<<<<<<<<<<<<<<<<<<");

  GP=F and trace("[EXIT]<%s:%s> Result: Sz(%d) List(%s)", MOD, meth,
    list.size(resultList), tostring(resultList));
  return resultList;
end -- listDelete()

-- ======================================================================
-- collapseTree()
-- ======================================================================
-- Read Level TWO of the B+ Tree and collapse the contents into the root
-- node.  We start with a tree in this shape:
--                  +=+====+=+
--  (Root Node)     |*| 30 |*|
--                  +|+====+|+
--             +-----+      +------+
-- Internal    |                   |         
-- Nodes       V                   V         
--     +=+====+=+====+=+   +=+====+=+====+=+ 
--     |*|  5 |*| 20 |*|   |*| 40 |*| 50 |*| 
--     +|+====+|+====+|+   +|+====+|+====+|+ 
--      |      |      |     |      |      |  
--    +-+   +--+   +--+     +-+    +-+    +-+
--    |     |      |          |      |      |   
--    V     V      V          V      V      V   
--  +-^-++--^--++--^--+    +--^--++--^--++--^--+
--  |1|3||6|7|8||22|26|    |30|39||40|46||51|55|
--  +---++-----++-----+    +-----++-----++-----+
--  Leaf Nodes
--
--    And we end up with a tree in this shape (one less level of inner nodes).
--
--     New (Merged) Root Node
--     +=+====+=+====+=+====+=+====+=+====+=+ 
--     |*|  5 |*| 20 |*| 30 |*| 40 |*| 50 |*| 
--     +|+====+|+====+|+====+|+====+|+====+|+ 
--      |      |      |      |      |      |  
--    +-+   +--+   +--+      ++     ++     ++
--    |     |      |          |      |      |   
--    V     V      V          V      V      V   
--  +-^-++--^--++--^--+    +--^--++--^--++--^--+
--  |1|3||6|7|8||22|26|    |30|39||40|46||51|55|
--  +---++-----++-----+    +-----++-----++-----+
--  Leaf Nodes
--
-- ======================================================================
local function collapseTree(src, topRec, ldtCtrl)
  GP=B and trace("\n\n <><H><> !!! Collapse Tree !!! <><W><> \n");
  local meth = "collapseTree()";
  GP=E and trace("[ENTER]<%s:%s> topRec(%s) SRC(%s) LDT(%s)",
    MOD, meth,tostring(topRec), tostring(src), ldtSummaryString(ldtCtrl));
  
  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];


  -- The caller has done all of the validation -- we just need to do the
  -- actual tree collapse.
  -- Read the contents of the root's children and copy them into the
  -- root (see above diagram).  Notice that the ONE remaining key in the
  -- root stays (as the divider of the two chidred).
  local leftSubRecDigest = ldtMap[LS.RootDigestList[1]];
  local leftSubRecDigestString = tostring(leftSubRecDigest);
  local leftSubRec = ldt_common.openSubRec(src, topRec, leftSubRecDigestString);
  if leftSubRec == nil then
    warn("[ERROR]<%s:%s> Can't Open Left Root Child(%s)",
      MOD, meth, leftSubRecDigestString);
    error( ldte.ERR_SUBREC_OPEN );
  end
  local leftSubRecCtrlMap = leftSubRec[NSR_CTRL_BIN];
  local leftKeyList =       leftSubRec[NSR_KEY_LIST_BIN];
  local leftDigestList =    leftSubRec[NSR_DIGEST_BIN];

  local rightSubRecDigest = ldtMap[LS.RootKeyList[2]];
  local rightSubRecDigestString = tostring(rightSubRecDigest);
  local rightSubRec = ldt_common.openSubRec(src,topRec,rightSubRecDigestString);
  if rightSubRec == nil then
    warn("[ERROR]<%s:%s> Can't Open Right Root Child(%s)",
      MOD, meth, rightSubRecDigestString);
    error( ldte.INTERNAL );
  end
  local rightSubRecCtrlMap = rightSubRec[NSR_CTRL_BIN];
  local rightKeyList =       rightSubRec[NSR_KEY_LIST_BIN];
  local rightDigestList =    rightSubRec[NSR_DIGEST_BIN];

  local newRootKeyList = list();
  local newRootDigestList = list();
  if (leftKeyList ~= nil and leftDigestList ~= nil) then
    list.append(newRootKeyList, leftKeyList);
    list.append(newRootDigestList, leftDigestList);
  else
    warn("[ERROR]<%s:%s> LeftChild Bad Lists: Key(%s) Digest(%s)", MOD, meth,
      tostring(leftKeyList), tostring(leftDigestList));
    error( ldte.ERR_INTERNAL );
  end

  -- This should have only one element in it.  If there is more than one
  -- key (and two children), then we need to handle this differently
  local oldRootKeyList = ldtMap[LS.RootKeyList[1]];
  if #oldRootKeyList ~= 1 then
    warn("[ERROR]<%s:%s> Old Root Key List is not length ONE: Len(%d)",
      MOD, meth, #oldRootKeyList);
    error( ldte.INTERNAL );
  end
  list.append(newRootKeyList, oldRootKeyList);

  if (rightKeyList ~= nil and rightDigestList ~= nil) then
    list.append(newRootKeyList, rightKeyList);
    list.append(newRootDigestList, rightDigestList);
  else
    warn("[ERROR]<%s:%s> RightChild Bad Lists: Key(%s) Digest(%s)", MOD, meth,
      tostring(rightKeyList), tostring(rightDigestList));
    error( ldte.ERR_SUBREC_OPEN );
  end

  -- We have now merged the contents of the two Root children into the root,
  -- so we can safely release the two children.
  ldt_common.removeSubRec( src, topRec, propMap, leftSubRecDigestString );
  ldt_common.removeSubRec( src, topRec, propMap, rightSubRecDigestString );

  -- Finally, adjust the tree level to show that we now have one LESS
  -- tree level.
  local treeLevel = ldtMap[LS.TreeLevel];
  ldtMap[LS.TreeLevel] = treeLevel - 1;

  -- Sanity check
  if ldtMap[LS.TreeLevel] < 2 then
    warn("[INTERNAL ERROR]<%s:%s> Tree Level (%d) incorrect. Must be >= 2",
      MOD, meth, ldtMap[LS.TreeLevel]);
    error( ldte.ERR_SUBREC_OPEN );
  end

  GP=E and trace("[EXIT]<%s:%s> rc(0)", MOD, meth);
  return 0;
end -- collapseTree()

-- ======================================================================
-- mergeRoot()
-- ======================================================================
-- After a root entry delete, we have one less entry in this root.
-- We Test to see if a MERGE of the root children is possible.
--
-- When we are down to only two children nodes of the root, we look at both
-- of those nodes to see if we can possibly merge the contents of the two
-- children nodes into the root node.  Note that the maximum size of the
-- root node is likely different than the max size of an internal node.
--
-- There is a special case for trees that have three levels (a root, two
-- or more child nodes, and leaves).  In this specific case, 
-- we can can use the leaf count to decide if the contents of the root's
-- children can fit in the root.  For larger trees, we look inside of the
-- two children to decide if their contents can fit.
--
-- ======================================================================
local function mergeRoot(src, sp, topRec, ldtCtrl)
  GP=B and trace("\n\n <><H><> !!! MERGE ROOT !!! <><W><> \n");

  local meth = "mergeRoot()";
  local rc = 0;
  GP=E and trace("[ENTER]<%s:%s> topRec(%s)", MOD, meth, tostring(topRec));
  GP=D and debug("[DEBUG]<%s:%s> SRC(%s)", MOD, meth, tostring(src));
  GP=D and trace("[DEBUG]<%s:%s> SP(%s)", MOD, meth, tostring(sp));
  GP=D and trace("[DEBUG]<%s:%s> LDT(%s)",MOD,meth,ldtSummaryString(ldtCtrl));
  
  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local ldtBinName = propMap[PM.BinName];

  local rootLevel = 1;
  local rootPosition = sp.PositionList[rootLevel];

  local keyList = ldtMap[LS.RootKeyList];
  local digestList = ldtMap[LS.RootDigestList];


  GP=D and trace("[DEBUG]<%s:%s> KeyList(%s) DigList(%s)", MOD, meth,
    tostring(keyList), tostring(digestList));

  -- The Caller has already verified that there are ONLY two children
  -- in the root -- so we can test for our two cases:
  -- First -- If the tree level is 3 (one root, two nodes and N leaves),
  -- we make a special computation because we can just count the leaves
  -- and know if we can make this a two level tree.
  local treeLevel = ldtMap[LS.TreeLevel];
  local rootMax = ldtMap[LS.RootListMax];
  if treeLevel == 3 then
    local leafCount = ldtMap[LS.LeafCount];
    if leafCount < rootMax then
      GP=D and trace("[DEBUG]<%s:%s> Calling CollapseTree(1)", MOD, meth);
      collapseTree(src, topRec, ldtCtrl);
    else
      GP=D and trace("[DEBUG]<%s:%s> NO CollapseTree", MOD, meth);
      GP=D and trace("[DEBUG]<%s:%s> LeafCount(%d) RootMax(%d)", MOD, meth,
        leafCount, rootMax);
    end
  else
    -- The tree is larger than three levels, so that means we have to look
    -- inside the two root children to see if they are small enough to
    -- be merged into the root node.
    local leftSubRecDigest = ldtMap[LS.RootDigestList[1]];
    local leftSubRecDigestString = tostring(leftSubRecDigest);
    local leftSubRec = ldt_common.openSubRec(src,topRec,leftSubRecDigestString);
    if leftSubRec == nil then
      warn("[ERROR]<%s:%s> Can't Open Left Root Child(%s)",
        MOD, meth, leftSubRecDigestString);
      error( ldte.ERR_SUBREC_OPEN );
    end
    local leftDigestList =    leftSubRec[NSR_DIGEST_BIN];

    local rightSubRecDigest = ldtMap[LS.RootKeyList[2]];
    local rightSubRecDigestString = tostring(rightSubRecDigest);
    local rightSubRec =
      ldt_common.openSubRec(src,topRec,rightSubRecDigestString);
    if rightSubRec == nil then
      warn("[ERROR]<%s:%s> Can't Open Right Root Child(%s)",
        MOD, meth, rightSubRecDigestString);
      error( ldte.INTERNAL );
    end
    local rightDigestList =    rightSubRec[NSR_DIGEST_BIN];

    if ((#leftDigestList + #rightDigestList + 1) < rootMax) then
      GP=D and trace("[DEBUG]<%s:%s> Calling CollapseTree(2)", MOD, meth);
      GP=D and trace("[DEBUG]<%s:%s> LeftCnt(%d) RightCnt(%d) RootMax(%d)",
        MOD, meth, #leftDigestList, #rightDigestList, rootMax);
      collapseTree(src, topRec, ldtCtrl);
    else
      GP=D and trace("[DEBUG]<%s:%s> NO CollapseTree", MOD, meth);
      GP=D and trace("[DEBUG]<%s:%s> LeftCnt(%d) RightCnt(%d) RootMax(%d)",
        MOD, meth, #leftDigestList, #rightDigestList, rootMax);
    end
  end

  GP=E and trace("[EXIT]<%s:%s> rc(%s)", MOD, meth, tostring(rc) );
  return rc;
end -- mergeRoot()

-- ======================================================================
-- rootDelete()
-- ======================================================================
-- After a Node or Leaf delete, we're left with an empty node/leaf, which
-- means we have to delete the corresponding entry from the root.  The
-- root is special, so it gets special attention.  If we get all the way
-- down to either the last leaf or the second to last leaf, then we do
-- not want to remove the leaf.  Instead, we want to borrow some number 
-- of elements in order to balance the small tree.  Notice that Duplicate
-- keys make things a bit messy, as we may have to deal with an empty
-- left leaf, and a middle/right leaf that holds duplicate values.  It 
-- would be nice if we could always collapse into a compact list and regrow
-- from there, but there's no guarantee that the remaining list of
-- duplicate values will all fit in the compact list.
--
-- Here's the problem:  We'll highlight this by showing a related problem:
--
-- The initial split of a compact list into leaves shows the inherent
-- problem.  If we have duplicate values that will span a leaf, we cannot
-- (by definition) have a left leaf, as all values LESS than a given key
-- are down the left-most leaf path, and everything greater than or equal
-- to the node key are in the right leaves.
--
-- Consider this example, where our compact list is 10 elements, and our
-- leaves can hold up to 8 elements.  And, in this case, we have 8 duplicates
-- of a single value.  We COULD split the compact list in half, but that gives
-- us a propagated key of "444", which is not correct.
-- So, technically, we must generate THREE leaves, where the Left leaf is
-- empty, and the middle and right leaves have duplicate values in the root.
-- NOTE: we follow the rule that the compact list must fit in a single
-- leaf, so we don't have the "three leaf" problem when building a new tree.
--
--              +---+---+---+---+---+---+---+---+---+---+
-- Compact      |444|444|444|444|444|444|444|444|444|444|
-- List         +---+---+---+---+---+---+---+---+---+---+
--
--                            +~+---+~+---+~+
-- Root Key List    --------> |*|444|*|444|*|
--                            +|+---+|+---+|+
-- Root Digest List --------> A|    B|    C|
--                   +---------+     |     +-----------------+
--                   |               |                       |
--                   V               V                       V
--                 +---+   +---+---+---+---+---+   +---+---+---+---+---+
-- Leaves          |   |   |444|444|444|444|444|   |444|444|444|444|444|
--                 +---+   +---+---+---+---+---+   +---+---+---+---+---+
--                   A               B                       C
--
-- We have a similar problem when we want to collapse leaves.  We have
-- to preserve the correct state of the tree, for many different (and
-- potentially unusual) situations.
--
-- Here's the other issue with ROOT and Inner Node delete.  The Search Path
-- (SP) position must be interpreted correctly.  There are N Keys, but N+1
-- child node/leaf pointers, so we have to interpret the SP Position correctly.
-- The searchKeyList() function gives us the DIGEST index that we should
-- follow for a particular Key value.  So, the SP position values for the
-- ROOT node will be in the range: [1 .. #DigestLength].
--
--
--                      +--->    K1    K2    K3
--                      |     +~+---+~+---+~+---+~+
-- Root Key List    ----+---> |*|111|*|222|*|333|*|
--                            +|+---+|+---+|+---+|+
-- Root Digest List --------> A|    B|    C|    D|
--             +---------------+     |   +-+     +-------+
--             |           +---------+   |               |
--             V(D1)       V(D2)         V(D3)           V(D4)
--         +---+---+   +---+---+    ---+---+---+   +---+---+---+
-- Leaves  |059|099|   |111|113|   |222|225|230|   |333|444|555|
--         +---+---+   +---+---+    ---+---+---+   +---+---+---+
--             A           B             C               D
--
-- Case 1: SP Position 1 (Remove Leaf A): Remove D1(A), K1(111) (special)
-- Case 2: SP Position 2 (Remove Leaf B): Remove D2(B), K1(111)
-- Case 3: SP Position 3 (Remove Leaf C): Remove D3(C), K2(222)
-- Case 4: SP Position 4 (Remove Leaf D): Remove D4(D), K3(333)
--
-- The search path position points to the Found or Insert position, and
-- then points to ZERO when not found (or insert is at the front).  The
-- insert position also tells us how to delete.
-- In general, we delete:
-- ==> Key at position, unless position is Zero (then it is one)
-- ==> Digest at position + 1.
-- ======================================================================
local function rootDelete(src, sp, topRec, ldtCtrl)
  GP=B and info("\n [ >>>>>>>>>>>>>>>> < rootDelete >  <<<<<<<<<<<<<<<<<< ]\n");

  local meth = "rootDelete()";
  GP=E and trace("[ENTER]<%s:%s> LdtCtrl(%s)",
    MOD, meth, ldtSummaryString( ldtCtrl ));

  GP=D and trace("[DETAIL]<%s:%s> SearchPath(%s)", MOD, meth,tostring(sp));

  -- Do the heavy Duty Dump when in Debug Mode
  GP=DEBUG and ldtDebugDump( ldtCtrl );

  -- Our list and map has already been validated.  Just use it.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- Caller has verified that there are more than two children (leaves or
  -- nodes) so we can go ahead and remove one of them.

  -- The Search Path (sp) object shows the search path from root to leaf.
  -- The Position values in SP are actually different for Leaf nodes and
  -- Inner/Root Nodes.  For Root/Inner nodes, the SP Position points to the
  -- index of the DIGEST that we follow to find the value (not the Key index).
  local rootLevel = 1;
  local rootPosition = sp.PositionList[rootLevel];
  local rc = 0;

  local keyList     = ldtMap[LS.RootKeyList];
  local digestList  = ldtMap[LS.RootDigestList];
  local digestPosition = rootPosition;
  local keyPosition;
  if digestPosition == 1 then
    keyPosition = 1;
  else
    keyPosition = digestPosition - 1;
  end
  local resultKeyList;
  local resultDigestList;

  GP=D and debug("[DEBUG]<%s:%s> RootPos(%d) KeyPos(%d) DigPos(%d)",
    MOD, meth, rootPosition, keyPosition, digestPosition);

  GP=D and debug("[DEBUG]<%s:%s> Lists Before Delete: Key(%s) Dig(%s)",
    MOD, meth, tostring(keyList), tostring(digestList));

  -- If it's a unique Index, then the delete is simple.  Release the child
  -- sub-rec, then remove the entries from the Key and Digest Lists.
  if( ldtMap[LS.KeyUnique] == AS_TRUE ) then
    resultKeyList    = ldt_common.listDelete(keyList, keyPosition );
    resultDigestList = ldt_common.listDelete(digestList, digestPosition );
  else
    -- For Duplicate value cases, it's more complex.  There is more to do here.
    -- For now, we'll treat it as a single value delete.  Later, we will
    -- have to look for MULTIPLE keys with the same value in the upper nodes.
    info("[NOTICE]<%s:%s> Treating Duplicate Case simple for now", MOD, meth);
    resultKeyList    = ldt_common.listDelete(keyList, keyPosition );
    resultDigestList = ldt_common.listDelete(digestList, digestPosition );
  end

  GP=D and debug("[DEBUG]<%s:%s> Lists AFTER Delete: Key(%s) Dig(%s)",
    MOD, meth, tostring(resultKeyList), tostring(resultDigestList));

  -- Until we get our improved List Processing Function, we have to assign
  -- our newly created list back into the ldt map.
  -- The outer caller will udpate the Top Record.
  ldtMap[LS.RootKeyList]    = resultKeyList;
  ldtMap[LS.RootDigestList] = resultDigestList;

  -- Now that we've dealt with a basic delete, there is still the possibility
  -- of merging the contents of the children of the root (who have to be inner
  -- Tree nodes, not leaves) into the root itself,
  -- which means we lose one level of the tree (the opposite of root split).
  -- So, this is valid ONLY when we have trees of a level >= 3.
  local treeLevel = ldtMap[LS.TreeLevel];
  if #resultDigestList <= 2 and treeLevel >= 3 then
    -- This function will CHECK for merge, and then merge if needed.
    mergeRoot(src, sp, topRec, ldtCtrl);
  end

  GP=D and trace("[DUMP]<%s:%s>After delete: KeyList(%s) DigList(%s)",
    MOD, meth, tostring(resultKeyList), tostring(resultDigestList));

  GP=F and trace("[DUMP]<%s:%s> LdtSummary(%s)", MOD, meth,
    ldtSummaryString(ldtCtrl));

  GP=E and trace("[EXIT]<%s:%s> RC(0)", MOD, meth );
  return 0;
end -- rootDelete()

-- ======================================================================
-- releaseNode()
-- ======================================================================
-- Release (remove) this Node and remove the entry in the parent node.
-- ======================================================================
local function releaseNode(src, sp, topRec, ldtCtrl)
  local meth = "releaseNode()";
  GP=E and trace("[ENTER]<%s:%s> LdtCtrl(%s)",
    MOD, meth, ldtSummaryString( ldtCtrl ));

  GP=B and info("\n [ >>>>>>>>>>>>>>>  < releaseNode >  <<<<<<<<<<<<<<<<< ]\n");

  -- The Search Path (sp) from root to leaf shows how we will bubble up
  -- if this node delete propagates up to the root node.
  local nodeLevel = sp.LevelCount;
  local nodePosition = sp.PositionList[nodeLevel];
  local nodeSubRecDigest = sp.DigestList[nodeLevel];
  local nodeSubRec = sp.RecList[nodeLevel];

  if (nodeLevel == 2) then
    -- Special root case
    rootDelete( src, sp, topRec, ldtCtrl );
  else
    nodeDelete( src, sp, (nodeLevel - 1), topRec, ldtCtrl );
  end

  -- Release this node
  local digestString = tostring(nodeSubRecDigest);
  ldt_common.removeSubRec( src, topRec, ldtCtrl[1], digestString );

  -- We now have one LESS node.  Update the global count.
  local ldtMap  = ldtCtrl[2];
  local nodeCount = ldtMap[LS.NodeCount];
  ldtMap[LS.NodeCount] = nodeCount - 1;

  GP=E and trace("[EXIT]<%s:%s>", MOD, meth );
end -- releasenode()

-- ======================================================================
-- nodeDelete()
-- ======================================================================
-- After a child (Node/Leaf) delete, we have to remove the entry from
-- the node (the digest list and the key list).  Notice that this can
-- in turn trigger further parent operations if this delete is the last
-- entry in THIS node.
--
-- Collapse the list to get rid of the entry in the node.  The SearchPath
-- parm shows us where the item is in the node.
-- Parms: 
-- (*) src: SubRec Context (in case we have to open more leaves)
-- (*) sp: Search Path structure
-- (*) nodeLevel: Level in the tree of this node.
-- (*) topRec:
-- (*) ldtCtrl:
--
-- Here's the other issue with ROOT and Inner Node delete.  The Search Path
-- (SP) position must be interpreted correctly.  There are N Keys, but N+1
-- child node/leaf pointers, so we have to interpret the SP Position correctly.
--
--                      +--->    K1    K2    K3
--                      |     +~+---+~+---+~+---+~+
-- Root Key List    ----+---> |*|111|*|222|*|333|*|
--                            +|+---+|+---+|+---+|+
-- Root Digest List --------> A|    B|    C|    D|
--             +---------------+     |   +-+     +-------+
--             |           +---------+   |               |
--             V(D1)       V(D2)         V(D3)           V(D4)
--         +---+---+   +---+---+    ---+---+---+   +---+---+---+
-- Leaves  |059|099|   |111|113|   |222|225|230|   |333|444|555|
--         +---+---+   +---+---+    ---+---+---+   +---+---+---+
--             A           B             C               D
--
-- Case 1: SP Position 0 (Remove Leaf A): Remove D1(A), K1(111) (special)
-- Case 2: SP Position 1 (Remove Leaf B): Remove D2(B), K1(111)
-- Case 3: SP Position 2 (Remove Leaf C): Remove D3(C), K2(222)
-- Case 4: SP Position 3 (Remove Leaf D): Remove D4(D), K3(333)
--
-- The search path position points to the Found or Insert position, and
-- then points to ZERO when not found (or insert is at the front).  The
-- insert position also tells us how to delete.
-- In general, we delete:
-- ==> Key at position, unless position is Zero (then it is one)
-- ==> Digest at position + 1.
-- ======================================================================
-- NOTE: This function is FORWARD-DECLARED, so it does NOT get a "local"
-- declaration here.
-- ======================================================================
function nodeDelete( src, sp, nodeLevel, topRec, ldtCtrl )
  GP=B and info("\n [ >>>>>>>>>>>>>>> < nodeDelete >  <<<<<<<<<<<<<<<<<< ]\n");

  local meth = "nodeDelete()";

  GP=E and trace("[ENTER]<%s:%s> SP(%s) LdtCtrl(%s)", MOD, meth,
    tostring(sp), ldtSummaryString( ldtCtrl ));

  GP=D and info("[ENTER]<%s:%s> SP(%s) LdtCtrl(%s)", MOD, meth,
    tostring(sp), ldtSummaryString( ldtCtrl ));

  local rc = 0;

  -- Our list and map has already been validated.  Just use it.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- The Search Path (sp) object shows the search path from root to leaf.
  local keyList     = ldtMap[LS.RootKeyList];
  local digestList  = ldtMap[LS.RootDigestList];
  local resultKeyList = list();
  local resultDigestList;


  -- The Search Path (sp) from root to leaf shows how we will bubble up
  -- if this node delete propagates up to the parent (or root).
  local nodePosition = sp.PositionList[nodeLevel];
  local nodeSubRec = sp.RecList[nodeLevel];
  local nodeSubRecDigest = sp.DigestList[nodeLevel];

  GP=DEBUG and printNode(nodeSubRec);

  local keyList = nodeSubRec[NSR_KEY_LIST_BIN];
  local digestList = nodeSubRec[NSR_DIGEST_BIN];
  local keyPosition = nodePosition == 0 and 1 or nodePosition;
  local digestPosition = nodePosition + 1;

  local removedDigestString = tostring(digestList[digestPosition]);

  GP=F and trace("[DUMP]Before delete: KeyList(%s) DigList(%s) Pos(%d)",
    tostring(keyList), tostring(digestList), nodePosition);

  GP=D and info("[NOTICE]<%s:%s> NodePos(%d) KeyPos(%d) DigPos(%d)", MOD, meth,
    nodePosition, keyPosition, digestPosition);

  -- If we allow duplicates, then we treat deletes quite a bit differently
  -- than we treat unique value deletes. Do the unique value case first.
  if( ldtMap[LS.KeyUnique] == AS_TRUE ) then
    -- Check for minimal node: 1 key, two digest pointers.  Look to merge
    -- two nodes into one.
    if #keyList <= 1 then
      GP=D and info("[NOTICE]<%s:%s> Minimal Node, Unique case", MOD, meth);
    else
      GP=D and info("[NOTICE]<%s:%s> Non-Minimal Node, Unique case", MOD, meth);
      -- Remove the entry from both the Key List and the Digest List
      local resultKeyList = ldt_common.listDelete(keyList, keyPosition);
      nodeSubRec[NSR_KEY_LIST_BIN] = resultKeyList;
      local resultDigestList = ldt_common.listDelete(digestList,digestPosition);
      nodeSubRec[NSR_DIGEST_BIN] = resultDigestList;

    end
  else
    GP=D and info("[NOTICE]<%s:%s>Delete From Node, Duplicate case",MOD,meth);
  end

  -- ok -- if we're left with NOTHING in the noded then collapse this node
  -- and release the entry in the parent.  If our parent is a regular node,
  -- then do the usual thing.  However, if it is the root node, then
  -- we have to do something special.  That is all handled by releaseNode();
  if #resultKeyList == 0 then
    releaseNode(src, sp, nodeLevel, topRec, ldtCtrl)
  else
    -- Mark this page as dirty and possibly write it out if needed.
    ldt_common.updateSubRec( src, nodeSubRec );
  end

  GP=D and trace("[DUMP]<%s:%s>After delete: KeyList(%s) DigList(%s)",
    MOD, meth, tostring(resultKeyList), tostring(resultDigestList));

  GP=F and trace("[EXIT]<%s:%s>LdtSummary(%s) rc(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl), tostring(rc));
  return rc;
end -- nodeDelete()

-- ======================================================================
-- releaseLeaf()
-- ======================================================================
-- If this leaf CAN borrow any items from its neighbors, then we will hang
-- onto it and not release it.  Look Left And/or Right to see if we can
-- borrow items from a neighbor.  If not, then ...
-- Release this leaf and remove the entry in the parent node.
-- The caller has already verified that this Sub-Rec Leaf is empty.
-- Notice that we will NOT reclaim this leaf it is one of the last two
-- leaves.  We leave the last two until we can either collapse into a
-- compact list, or the tree is completely empty.
-- Parms:
-- Return: Nothing.
-- ======================================================================
local function releaseLeaf(src, sp, topRec, ldtCtrl)
  GP=B and info("\n [ >>>>>>>>>>>>>>>>>  <Release Leaf>  <<<<<<<<<<<<<<< ]\n");

  local meth = "releaseLeaf()";

  GP=E and trace("[ENTER]<%s:%s> LdtCtrl(%s)",
    MOD, meth, ldtSummaryString( ldtCtrl ));


  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- NOTE: Near Future Work:
  -- Do the Search for Left or Right Leaves that might have items that we
  -- can borrow.  Notice that this is not worth doing if the object size
  -- is over a certain size (e.g. 100kb).  At that point, we shouldn't even
  -- try -- just remove this leaf.
  -- Also -- if this is the LEFT-MOST Leaf, then it is likely that we're
  -- doing a Time-Series delete, which will not benefit from a Leaf Borrow.
  GP=D and info("[NOTICE]<%s:%s> Leaf Borrow not yet activated", MOD, meth);

  GP=D and info("[DEBUG]<%s:%s> Using SearchPath(%s)", MOD, meth, tostring(sp));

  -- The Search Path (sp) from root to leaf shows how we will bubble up
  -- if this leaf delete propagates up to the parent node.
  local leafLevel = sp.LevelCount;
  local leafPosition = sp.PositionList[leafLevel];
  local leafSubRecDigest = sp.DigestList[leafLevel];
  local leafSubRec = sp.RecList[leafLevel];

  if leafSubRec == nil then
    warn("[INTERNAL ERROR]<%s:%s> LeafSubRec is NIL: Dig(%s)",
      MOD, meth, leafSubRecDigest);
    error(ldte.ERR_INTERNAL);
  else
    GP=D and info("[DEBUG]<%s:%s> LeafSubRec Summary(%s)", MOD, meth,
      leafSummaryString(leafSubRec)); 
  end

  if (leafLevel == 2) then
    -- Special root case.  Note that the caller has already checked that
    -- we have more than 2 leaves, so we can certainly remove one.
    GP=D and info("[DEBUG]<%s:%s> Calling Root Delete", MOD, meth );
    rootDelete( src, sp, topRec, ldtCtrl );
  else
    GP=D and info("[DEBUG]<%s:%s> Calling Node Delete", MOD, meth );
    nodeDelete( src, sp, (leafLevel - 1), topRec, ldtCtrl );
  end

  -- Since Leaf Nodes are doubly-linked, when we remove a leaf we have to
  -- adjust the Prev/Next pointers in the neighboring leaves.  Also, if
  -- this leaf is either the LeftMost Leaf or the RightMost Leaf, then
  -- we have to take some additional steps (we have to adjust the Leaf Ptrs
  -- in the Main control block.
  adjustLeafPointersAfterDelete( src, topRec, ldtMap, leafSubRec )

  -- Release this leaf
  local digestString = tostring(leafSubRecDigest);
  GP=D and info("[DEBUG]<%s:%s> About to Release Leaf(%s)",
    MOD, meth, digestString);
  ldt_common.removeSubRec( src, topRec, propMap, digestString );

  -- We now have one LESS Leaf.  Update the count.
  local leafCount = ldtMap[LS.LeafCount];
  ldtMap[LS.LeafCount] = leafCount - 1;

  GP=DEBUG and ldtDebugDump(ldtCtrl);

  GP=E and trace("[EXIT]<%s:%s>", MOD, meth );
end -- releaseLeaf()

-- ======================================================================
-- releaseTree()
-- ======================================================================
-- Release all storage for a tree.  Reset the Root Node lists and all
-- related storage information.  It's likely that we're resetting back
-- to a compact list -- which means that ItemCount remains, but other things
-- get reset.
-- ======================================================================
local function releaseTree( src, topRec, ldtCtrl )
  local meth = "releaseTree()";
  GP=E and trace("[ENTER]<%s:%s> LdtCtrl(%s)",
    MOD, meth, ldtSummaryString( ldtCtrl ));

  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local ldtBinName = propMap[PM.BinName];

  -- Remove the Root Info
  map.remove( ldtMap, LS.RootKeyList );
  map.remove( ldtMap, LS.RootDigestList );

  -- Restore the initial state in case we build up again.
  ldtMap[LS.RootKeyList] = list();
  ldtMap[LS.RootDigestList] = list();

  -- Remove the Left and Right Leaf pointers
  ldtMap[LS.LeftLeafDigest] = 0;
  ldtMap[LS.RightLeafDigest] = 0;

  -- Set the tree level back to its initial state.
  ldtMap[LS.TreeLevel] = 1;

  -- Remove the ESR, which will trigger the removal of all sub-records.
  -- This function also sets the PM_EsrDigest entry to zero.
  ldt_common.removeEsr( src, topRec, propMap, ldtBinName);
  propMap[PM.SubRecCount] = 0; -- No More Sub-Recs

  -- Reset the Tree Node and Leaft stats.
  ldtMap[LS.NodeCount] = 0;
  ldtMap[LS.LeafCount] = 0;

  GP=E and trace("[EXIT]<%s:%s>", MOD, meth );

end -- releaseTree()

-- ======================================================================
-- collapseToCompact()
-- ======================================================================
-- We're at the point where we've removed enough items that put us UNDER
-- the compact list threshold.  So, we're going to scan the tree and place
-- the contents into the compact list.
-- RETURN:
-- void on success, error() if problems
-- ======================================================================
local function collapseToCompact( src, topRec, ldtCtrl )
  local meth = "collapseToCompact()";
  GP=E and trace("[ENTER]<%s:%s> LdtCtrl(%s)",
    MOD, meth, ldtSummaryString( ldtCtrl ));

  local propMap = ldtCtrl[1]
  local ldtMap  = ldtCtrl[2];

  -- Get all of the tree contents and store it in scanList.
  local scanList = list();
  if (propMap[PM.ItemCount] > 0) then
    fullTreeScan( src, scanList, topRec, ldtCtrl );
  else
    GP=F and debug("[DEBUG]<%s:%s> ItemCount is zero, or less(%d)", MOD, meth,
      propMap[PM.ItemCount]);
  end

  -- scanList is the new Compact List.  Change the state back to Compact.
  ldtMap[LS.CompactList] = scanList;
  ldtMap[LS.StoreState] = SS_COMPACT;

  -- Erase the old tree.  Null out the Root list in the main record, and
  -- release all of the subrecs.
  releaseTree( src, topRec, ldtCtrl );
  
  GP=F and trace("[EXIT]<%s:%s>LdtSummary(%s) rc(0)",
    MOD, meth, ldtSummaryString(ldtCtrl));

end -- collapseToCompact()

-- ======================================================================
-- leafDelete()
-- ======================================================================
-- Collapse the list to get rid of the entry in the leaf.
-- We're not in the mode of "NULLing" out the entry, so we'll pay
-- the extra cost of collapsing the list around the item.  The SearchPath
-- parm shows us where the item is.
-- Parms: 
-- (*) src: SubRec Context (in case we have to open more leaves)
-- (*) sp: Search Path structure
-- (*) topRec:
-- (*) ldtCtrl:
-- (*) key: the key -- in case we need to look for more dups
-- ======================================================================
local function leafDelete( src, sp, topRec, ldtCtrl, key )
  local meth = "leafDelete()";
  GP=E and trace("[ENTER]<%s:%s> Key(%s) SearchPath(%s)", MOD, meth,
    tostring(key), tostring(sp));

  GP=D and trace("[DEBUG]<%s:%s> LdtCtrl(%s)", MOD, meth,
    ldtSummaryString( ldtCtrl ));

  local rc = 0;

  -- Our list and map has already been validated.  Just use it.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local leafLevel = sp.LevelCount;
  local leafSubRec = sp.RecList[leafLevel];
  local objectList = leafSubRec[LSR_LIST_BIN];
  local position = sp.PositionList[leafLevel];
  local endPos = sp.LeafEndPosition;
  local resultList;
  
  GP=F and trace("[DUMP]Before delete: ObjectList(%s) Key(%s) Position(%d)",
    tostring(objectList), tostring(key), position);

  -- Delete is easy if it's a single value -- more difficult if MANY items
  -- (with the same value) are deleted.
  local numRemoved;
  if( ldtMap[LS.KeyUnique] == AS_TRUE ) then
    resultList = ldt_common.listDelete(objectList, position )
    leafSubRec[LSR_LIST_BIN] = resultList;
    numRemoved = 1;
  else
    -- If it's MULTI-DELETE, then we have to check the neighbors and the
    -- parent to see if we have to merge leaves after the delete.
    resultList = ldt_common.listDeleteMultiple(objectList,position,endPos);
    leafSubRec[LSR_LIST_BIN] = resultList;
    numRemoved = endPos - position + 1;
  end

  -- If this last remove has dropped us BELOW the "reverse threshold", then
  -- collapse the tree into a new compact list.  Otherwise, do the regular
  -- tree/node checking after a delete.  Notice that "collapse" will also
  -- handle the EMPTY tree case (which will probably be rare).
  if ((propMap[PM.ItemCount] - numRemoved) <= ldtMap[LS.RevThreshold]) then
    collapseToCompact( src, topRec, ldtCtrl );
  else
    -- ok -- regular delete processing.  if we're left with NOTHING in the
    -- leaf then collapse this leaf and release the entry in the parent.
    if #resultList == 0 and ldtMap[LS.LeafCount] > 2 then
      releaseLeaf(src, sp, topRec, ldtCtrl)
    else
      -- Mark this page as dirty and possibly write it out if needed.
      ldt_common.updateSubRec( src, leafSubRec );
    end
  end

  GP=D and trace("[DUMP]After delete: Key(%s) Result: Sz(%d) ObjectList(%s)",
    tostring(key), list.size(resultList), tostring(resultList));

  GP=F and trace("[EXIT]<%s:%s>LdtSummary(%s) key(%s) rc(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl), tostring(key), tostring(rc));
  return rc;
end -- leafDelete()


-- ======================================================================
-- treeDelete()
-- ======================================================================
-- Perform a delete:  Remove this object from the tree. 
-- Two cases:
-- (1) Unique Key
-- (2) Duplicates Allowed.
-- Case 1: Unique Key :: For this case, just collapse the object list in the
-- leaf to remove the item.  If this empties the leaf, then we remove this
-- SubRecord and remove the entry from the parent.
-- Case 2: Duplicate Keys:
-- When we do Duplicates, then we have to address the case that the leaf
-- is completely empty, which means we also need remove the subrec from
-- the leaf chain.  HOWEVER, for now, we'll just remove the items from the
-- leaf objectList, but leave the Tree Leaves in place.  And, in either
-- case, we won't update the upper nodes.
-- We will have both a COMPACT storage mode and a TREE storage mode. 
-- When in COMPACT mode, the root node holds the list directly.
-- When in Tree mode, the root node holds the top level of the tree.
-- Parms:
-- (*) src: SubRec Context
-- (*) topRec:
-- (*) ldtCtrl: The LDT Control Structure
-- (*) key:  Find and Delete the objects that match this key
-- (*) createSpec:
-- Return:
-- ERR.OK(0): if found
-- ERR.NOT_FOUND(-2): if NOT found
-- ERR.GENERAL(-1): For any other error 
-- =======================================================================
local function treeDelete( src, topRec, ldtCtrl, key )
  local meth = "treeDelete()";
  GP=E and trace("[ENTER]<%s:%s> LDT(%s) key(%s)", MOD, meth,
    ldtSummaryString( ldtCtrl ), tostring( key ));
  local rc = 0;

  -- Our list and map has already been validated.  Just use it.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local sp = createSearchPath(ldtMap);
  local status = treeSearch( src, topRec, sp, ldtCtrl, key );

  if( status == ST.FOUND ) then
    -- leafDelete() always returns zero.
    leafDelete( src, sp, topRec, ldtCtrl, key );
  else
    rc = ERR.NOT_FOUND;
  end

  -- NOTE: The caller will take care of updating the parent Record (topRec).
  GP=F and trace("[EXIT]<%s:%s>LdtSummary(%s) key(%s) rc(%s)",
    MOD, meth, ldtSummaryString(ldtCtrl), tostring(key), tostring(rc));
  return rc;
end -- treeDelete()

-- ======================================================================
-- processModule( ldtCtrl, moduleName )
-- ======================================================================
-- We expect to see several things from a user module.
-- (*) An adjust_settings() function: where a user overrides default settings
-- (*) Various filter functions (callable later during search)
-- (*) Transformation functions
-- (*) UnTransformation functions
-- The settings and transformation/untransformation are all set from the
-- adjust_settings() function, which puts these values in the control map.
-- ======================================================================
local function processModule( ldtCtrl, moduleName )
  local meth = "processModule()";
  GP=E and trace("[ENTER]<%s:%s> Process User Module(%s)", MOD, meth,
    tostring( moduleName ));

  local propMap = ldtCtrl[1];
  local ldtMap = ldtCtrl[2];
  local userModule;

  if( moduleName ~= nil ) then
    if( type(moduleName) ~= "string" ) then
      warn("[ERROR]<%s:%s>User Module(%s) not valid::wrong type(%s)",
        MOD, meth, tostring(moduleName), type(moduleName));
      error( ldte.ERR_USER_MODULE_BAD );
    end

    userModule = require(moduleName);
    if( userModule == nil ) then
      warn("[ERROR]<%s:%s>User Module(%s) not valid", MOD, meth, moduleName);
      error( ldte.ERR_USER_MODULE_NOT_FOUND );
    else
      local userSettings =  userModule[G_SETTINGS];
      if( userSettings ~= nil ) then
        userSettings( ldtMap ); -- hope for the best.
        ldtMap[LC.UserModule] = moduleName;
      end
    end
  else
    warn("[ERROR]<%s:%s>User Module is NIL", MOD, meth );
  end

  GP=E and trace("[EXIT]<%s:%s> Module(%s) LDT CTRL(%s)", MOD, meth,
  tostring( moduleName ), ldtSummaryString(ldtCtrl));

end -- processModule()

-- ======================================================================
-- setupKeyType()
-- ======================================================================
-- If the Key Type is not already setup (because we did a Create vs an add),
-- then we have to set it based on the first value (either atomic or complex).
-- Note that this function must be updated if we add NEW atomic types to
-- Lua language support.
-- ======================================================================
local function setupKeyType( ldtMap, firstValue )
--   local meth="setupKeyType()";
--   info("[ENTER]<%s:%s> firstValue(%s)", MOD, meth, tostring(firstValue));

  -- Based on the first value (if not nul), set the key type.
  if firstValue ~= nil then
    local valType = type(firstValue);

--     info("[TYPE]<%s:%s> KeyType(%s)", MOD, meth, valType);

    if valType=="number" or valType=="string" or valType=="bytes" then
      ldtMap[LC.KeyType] = KT_ATOMIC;
    else
      ldtMap[LC.KeyType] = KT_COMPLEX;
    end
  end
end -- setupKeyType()

-- ======================================================================
-- setupLdtBin()
-- Caller has already verified that there is no bin with this name,
-- so we're free to allocate and assign a newly created LDT CTRL
-- in this bin.
-- ALSO:: Caller write out the LDT bin after this function returns.
-- ======================================================================
local function setupLdtBin( topRec, ldtBinName, createSpec, firstValue) 
  local meth = "setupLdtBin()";
  GP=E and trace("[ENTER]<%s:%s> ldtBinName(%s) UserMod(%s) FirstVal(%s)", MOD,
    meth, tostring(ldtBinName), tostring(createSpec), tostring(firstValue));

  local ldtCtrl = initializeLdtCtrl( topRec, ldtBinName );
  local propMap = ldtCtrl[1]; 
  local ldtMap = ldtCtrl[2]; 
  
  -- Remember that record.set_type() for the TopRec
  -- is handled in initializeLdtCtrl()
  
  -- If the user has passed in settings that override the defaults
  -- (the createSpec), then process that now.
  if( createSpec ~= nil )then
    local createSpecType = type(createSpec);
    if( createSpecType == "string" ) then
      processModule( ldtCtrl, createSpec );
    elseif ( getmetatable(createSpec) == Map ) then
      ldt_common.adjustLdtMap( ldtCtrl, createSpec, llistPackage);
    else
      warn("[WARNING]<%s:%s> Unknown Creation Object(%s)",
        MOD, meth, tostring( createSpec ));
    end
  end

  GP=F and trace("[DEBUG]: <%s:%s> : CTRL Map after Adjust(%s)",
                 MOD, meth , tostring(ldtMap));

  -- Set up our Bin according to which type of storage we're starting with.
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Compact Mode -- set up the List.
    ldtMap[LS.CompactList] = list();
  else
    -- Tree Mode -- set up an empty tree.

  end

  -- Sets the topRec control bin attribute to point to the 2 item list
  -- we created from InitializeLSetMap() : 
  -- Item 1 :  the property map & Item 2 : the ldtMap
  topRec[ldtBinName] = ldtCtrl; -- store in the record
  record.set_flags( topRec, ldtBinName, BF.LDT_BIN );

  -- Based on the first value, set the key type
  if firstValue then
    local valType = type(firstValue);

    if valType=="number" or valType=="string" or valType=="bytes" then
      ldtMap[LC.KeyType] = KT_ATOMIC;
    else
      ldtMap[LC.KeyType] = KT_COMPLEX;
    end
  end

  -- NOTE: The Caller will write out the LDT bin.
  return 0;
end -- setupLdtBin( topRec, ldtBinName ) 

-- =======================================================================
-- treeMinGet()
-- =======================================================================
-- Get or Take the object that is associated with the MINIMUM (for now, we
-- assume this means left-most) key value.  We've been passed in a search
-- path object (sp) and we use that to look at the leaf and return the
-- first value in the list.
-- =======================================================================
local function treeMinGet( sp, ldtCtrl, take )
  local meth = "treeMinGet()";
  local resultObject;
  GP=E and trace("[ENTER]<%s:%s> searchPath(%s) ", MOD, meth, tostring(sp));

  -- Extract the property map and control map from the ldt bin list.
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local leafLevel = sp.LevelCount;
  local leafSubRec = sp.RecList[leafLevel]; -- already open from the search.
  local objectList = leafSubRec[LSR_LIST_BIN];
  if( list.size(objectList) == 0 ) then
    warn("[ERROR]<%s:%s> Unexpected Empty List in Leaf", MOD, meth );
    error(ldte.ERR_INTERNAL);
  end

  -- We're here.  Get the minimum Object.  And, if "take" is true, then also
  -- remove it -- and we do that by generating a new list that excludes the
  -- first element.  We assume that the caller will update the SubRec.
  resultObject = objectList[1];
  if ( take ) then
    leafSubRec[LSR_LIST_BIN] = ldt_common.listDelete( objectList, 1 );
  end

  GP=E and trace("[EXIT]<%s:%s> ResultObject(%s) ",
    MOD, meth, tostring(resultObject));
  return resultObject;

end -- treeMinGet()

-- =======================================================================
-- treeMin()
-- =======================================================================
-- Drop down to the Left Leaf and then either TAKE or FIND the FIRST element.
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) take: True if we are DELETE the MIN (first) item.
-- Result:
-- Success: Object is returned
-- Error: Error Code/String
-- =======================================================================
local function treeMin( topRec,ldtBinName, take )
  local meth = "treeMin()";
  GP=E and trace("[ENTER]<%s:%s> bin(%s) take(%s)",
    MOD, meth, tostring( ldtBinName), tostring(take));

  -- Define our return value;
  local resultObject;
  
  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );
  
  -- Extract the property map and control map from the ldt bin list.
  local ldtCtrl = topRec[ldtBinName];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- If our itemCount is ZERO, then quickly return NIL before we get into
  -- any trouble.
  if( propMap[PM.ItemCount] == 0 ) then
    debug("[ATTENTION]<%s:%s> Searching for MIN of EMPTY TREE", MOD, meth );
    return nil;
  end

  -- set up the Read Functions (UnTransform, Filter)
  G_KeyFunction = ldt_common.setKeyFunction( ldtMap, false, G_KeyFunction ); 
  G_Filter, G_UnTransform =
      ldt_common.setReadFunctions( ldtMap, nil, nil );
  G_FunctionArgs = nil;

  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  local src = ldt_common.createSubRecContext();

  local resultA;
  local resultB;
  local storeObject;

  -- If our state is "compact", just get the first element.
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Do the COMPACT LIST SEARCH
    local objectList = ldtMap[LS.CompactList];
    -- If we have a transform/untransform, do that here.
    storeObject = objectList[1];
    if( G_UnTransform ~= nil ) then
      resultObject = G_UnTransform( storeObject );
    else
      resultObject = storeObject;
    end
  else
    -- It's a "regular" Tree State, so do the Tree Operation.
    -- Note that "Left-Most" is a special case, where by using a nil key
    -- we automatically go to the "minimal" position.  We can pull
    -- the value from our Search Path (sp) Object.
    GP=F and trace("[DEBUG]<%s:%s> Searching Tree", MOD, meth );
    local sp = createSearchPath(ldtMap);
    treeSearch( src, topRec, sp, ldtCtrl, nil );
    -- We're just going to assume there's a MIN found, given that there's a
    -- non-zero tree present.  Any other error will kick out of Lua.
    resultObject = treeMinGet( sp, ldtCtrl, take );
  end -- tree extract

  GP=F and trace("[EXIT]<%s:%s>: ReturnObj(%s)",
    MOD, meth, tostring(resultObject));
  
  -- We have either jumped out of here via error() function call, or if
  -- we got this far, then we are supposed to have a valid resultObject.
  return resultObject;
end -- treeMin();

-- ======================================================================
-- localWrite() -- Write a new value into the Ordered List.
-- ======================================================================
-- This function does the work of both calls:
-- (1) Regular LLIST add(), which either adds a new value, or complains
--     if an existing value would violate the unique property (when turned on)
-- (2) LLIST update(), which either adds a new value, or OVERWRITES an
--     existing value with a new value, when UNIQUE is true and a value
--     is found.
--
-- Insert a value into the list (into the B+ Tree).  We will have both a
-- COMPACT storage mode and a TREE storage mode.  When in COMPACT mode,
-- the root node holds the list directly (Ordered search and insert).
-- When in Tree mode, the root node holds the top level of the tree.
-- ======================================================================
-- NOTE: All List Objects should be in "Storage Mode", which means that if
-- we have a Transform/Untransform pair, they should be used to Write To 
-- and Read from the Object List.  This includes the Compact List.
-- ======================================================================
-- Parms:
-- (*) src: Sub-Rec Context - Needed for repeated calls from caller
-- (*) topRec:
-- (*) ldtBinName:
-- (*) ldtCtrl: 
-- (*) newValue:
-- (*) update: When true, allow overwrite
-- =======================================================================
local function localWrite(src, topRec, ldtBinName, ldtCtrl, newValue, update)
  local meth = "localWrite()";
  GP=E and trace("[ENTER]<%s:%s> BIN(%s) NwVal(%s) Upd(%s) src(%s)",
    MOD, meth, tostring(ldtBinName), tostring( newValue ),
    tostring(update), tostring(src));

  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];
  local rc = 0;

  -- When we're in "Compact" mode, before each insert, look to see if 
  -- it's time to turn our single list into a tree.
  local itemCount = propMap[PM.ItemCount];

  -- This is an expensive operation that takes apart the value (if it is
  -- map or list) and prints out each component.  Always OFF in production.
  -- GP=DEBUG and ldt_common.dumpValue(newValue);

  -- If we're in "compact mode", but we've accumulated enough inserts (or if
  -- Threshold is zero), then we convert our compact list, empty or
  -- not, into a tree.
  if(( ldtMap[LS.StoreState] == SS_COMPACT ) and
     ( itemCount > ldtMap[LS.Threshold] )) 
  then
    convertList(src, topRec, ldtBinName, ldtCtrl );
  end
 
  -- Do the local insert.
  local key;
  local update_done = false;

  -- If our state is "compact", do a simple list insert, otherwise do a
  -- real tree insert.
  local insertResult = 0;
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Do the COMPACT LIST INSERT
    GP=D and trace("[NOTICE]<%s:%s> Using >>>  LIST INSERT  <<<", MOD, meth);
    local objectList = ldtMap[LS.CompactList];
    key = getKeyValue( ldtMap, newValue );
    local resultMap = searchObjectList( ldtMap, objectList, key );
    local position = resultMap.Position;
    if( resultMap.Status == ERR.OK ) then
      -- If FOUND, then if UNIQUE, it's either an ERROR, or we are doing
      -- an Update (overwrite in place).
      -- Otherwise, if not UNIQUE, do the insert.
      if( resultMap.Found and ldtMap[LS.KeyUnique] == AS_TRUE ) then
        if update then
          ldt_common.listUpdate( objectList, newValue, position );
          update_done = true;
        else
          debug("[ERROR]<%s:%s> Unique Key Violation", MOD, meth );
          error( ldte.ERR_UNIQUE_KEY );
        end
      else
        ldt_common.listInsert( objectList, newValue, position );
        GP=F and trace("[DEBUG]<%s:%s> Insert List rc(%d)", MOD, meth, rc );
        if( rc < 0 ) then
          warn("[ERROR]<%s:%s> Problems with Insert: RC(%d)", MOD, meth, rc );
          error( ldte.ERR_INTERNAL );
        end
      end
    else
      warn("[Internal ERROR]<%s:%s> Key(%s), List(%s)", MOD, meth,
        tostring( key ), tostring( objectList ) );
      error( ldte.ERR_INTERNAL );
    end
  else
    -- Do the TREE INSERT
    GP=D and trace("[NOTICE]<%s:%s> Using >>>  TREE INSERT  <<<", MOD, meth);
    insertResult = treeInsert(src, topRec, ldtCtrl, newValue, update);
    update_done = insertResult == 1;
  end

  -- update our count statistics, as long as we're not in UPDATE mode.
  if( not update_done and insertResult >= 0 ) then -- Update Stats if success
    local itemCount = propMap[PM.ItemCount];
    -- local totalCount = ldtMap[LS.TotalCount];
    propMap[PM.ItemCount] = itemCount + 1; -- number of valid items goes up
    -- ldtMap[LS.TotalCount] = totalCount + 1; -- Total number of items goes up
    GP=F and trace("[DEBUG]: <%s:%s> itemCount(%d)", MOD, meth, itemCount );
  end

  -- Close ALL of the subrecs that might have been opened (just the read-only
  -- ones).  All of the dirty ones will stay open.
  -- This will Always return zero.
  ldt_common.closeAllSubRecs( src );

  -- All done, store the record
  -- Update the Top Record with the new Tree Contents.
  topRec[ldtBinName] = ldtCtrl;
  record.set_flags(topRec, ldtBinName, BF.LDT_BIN );--Must set every time
  -- With recent changes, we know that the record is now already created
  -- so all we need to do is perform the update (no create needed).
  GP=F and trace("[DEBUG]:<%s:%s>:Update Record()", MOD, meth );
  rc = aerospike:update( topRec );
  if ( rc and rc ~= 0 ) then
    warn("[ERROR]<%s:%s>TopRec Update Error rc(%s)",MOD,meth,tostring(rc));
    error( ldte.ERR_TOPREC_UPDATE );
  end 

  GP=E and trace("[EXIT]:<%s:%s> rc(0)", MOD, meth);
  return 0;
end -- function localWrite()

-- ======================================================================
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- Large List (LLIST) Library Functions
-- ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
-- See top of file for details.
-- ======================================================================
-- ======================================================================
-- We define a table of functions that are visible to both INTERNAL UDF
-- calls and to the EXTERNAL LDT functions.  We define this table, "lmap",
-- which contains the functions that will be visible to the module.
local llist = {};

-- ======================================================================
-- llist.create()
-- ======================================================================
-- Create/Initialize a Large Ordered List  structure in a bin, using a
-- single LLIST -- bin, using User's name, but Aerospike TYPE (AS_LLIST)
--
-- We will use a LLIST control object, which contains control information and
-- two lists (the root note Key and pointer lists).
-- (*) Namespace Name
-- (*) Set Name
-- (*) Tree Node Size
-- (*) Inner Node Count
-- (*) Data Leaf Node Count
-- (*) Total Item Count
-- (*) Storage Mode (Binary or List Mode): 0 for Binary, 1 for List
-- (*) Key Storage
-- (*) Value Storage
--
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) LdtBinName: The user's chosen name for the LDT bin
-- (3) createSpec: The map that holds a package for adjusting LLIST settings.
-- ======================================================================
function llist.create( topRec, ldtBinName, createSpec )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST CREATE ] <<<<<<<<<< \n");
  local meth = "listCreate()";
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );
  local rc = 0;

  if createSpec == nil then
    GP=E and trace("[ENTER1]: <%s:%s> ldtBinName(%s) NULL createSpec",
      MOD, meth, tostring(ldtBinName));
  else
    GP=E and trace("[ENTER2]: <%s:%s> ldtBinName(%s) createSpec(%s) ",
    MOD, meth, tostring( ldtBinName), tostring( createSpec ));
  end

  -- Validate the BinName -- this will kick out if there's anything wrong
  -- with the bin name.
  ldt_common.validateBinName( ldtBinName );

  -- Check to see if LDT Structure (or anything) is already there,
  -- and if so, error
  if topRec[ldtBinName] ~= nil  then
    warn("[ERROR EXIT]: <%s:%s> LDT BIN(%s) Already Exists",
      MOD, meth, tostring(ldtBinName) );
    error( ldte.ERR_BIN_ALREADY_EXISTS );
  end

  -- Set up a new LDT Bin
  local ldtCtrl = setupLdtBin( topRec, ldtBinName, createSpec, nil);

  GP=DEBUG and ldtDebugDump( ldtCtrl );

  -- All done, store the record
  -- With recent changes, we know that the record is now already created
  -- so all we need to do is perform the update (no create needed).
  GP=F and trace("[DEBUG]:<%s:%s>:Update Record()", MOD, meth );
  rc = aerospike:update( topRec );
  if ( rc ~= 0 ) then
    warn("[ERROR]<%s:%s>TopRec Update Error rc(%s)",MOD,meth,tostring(rc));
    error( ldte.ERR_TOPREC_UPDATE );
  end 

  GP=F and trace("[EXIT]: <%s:%s> : Done.  RC(%d)", MOD, meth, rc );
  return rc;
end -- function llist.create()

-- ======================================================================
-- llist.add() -- Insert an element into the ordered list.
-- ======================================================================
-- This function does the work of both calls -- with and without inner UDF.
--
-- Insert a value into the list (into the B+ Tree).  We will have both a
-- COMPACT storage mode and a TREE storage mode.  When in COMPACT mode,
-- the root node holds the list directly (Ordered search and insert).
-- When in Tree mode, the root node holds the top level of the tree.
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) newValue:
-- (*) createSpec:
-- (*) src: Sub-Rec Context - Needed for repeated calls from caller
-- =======================================================================
function llist.add( topRec, ldtBinName, newValue, createSpec, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST ADD ] <<<<<<<<<<< \n");
  local meth = "llist.add()";
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  GP=E and trace("[ENTER]<%s:%s>LLIST BIN(%s) NwVal(%s) createSpec(%s) src(%s)",
    MOD, meth, tostring(ldtBinName), tostring( newValue ),
    tostring(createSpec), tostring(src));

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  -- This function does not build, save or update.  It only checks.
  -- Check to see if LDT Structure (or anything) is already there.  If there
  -- is an LDT BIN present, then it MUST be valid.
  validateRecBinAndMap( topRec, ldtBinName, false );

  -- If the record does not exist, or the BIN does not exist, then we must
  -- create it and initialize the LDT map. Otherwise, use it.
  if( topRec[ldtBinName] == nil ) then
    GP=F and trace("[INFO]<%s:%s>LLIST CONTROL BIN does not Exist:Creating",
         MOD, meth );

    -- set up our new LDT Bin
    setupLdtBin( topRec, ldtBinName, createSpec, newValue );
  end

  local ldtCtrl = topRec[ ldtBinName ];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  GP=D and trace("[DEBUG]<%s:%s> LDT Summary(%s)", MOD, meth,
    ldtSummaryString(ldtCtrl));

  -- We have to check to see if our KeyType is set, and if not, set it based
  -- on the first value.  In most cases, it will already have been set by
  -- setupLdtBin(), but if the LDT was created with create(), then we won't
  -- see a first value until the first insert, even though the LDT is set up.
  if ldtMap[LC.KeyType] == KT_NONE then
    setupKeyType(ldtMap, newValue);
  end

  -- Set up the Read/Write Functions (KeyFunction, Transform, Untransform)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction(ldtMap, false, G_KeyFunction); 
  end
  G_Filter, G_UnTransform = ldt_common.setReadFunctions( ldtMap, nil, nil );
  G_Transform = ldt_common.setWriteFunctions( ldtMap );
  
  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- call localWrite() with UPDATE flag turned OFF.
  return localWrite(src, topRec, ldtBinName, ldtCtrl, newValue, false);

end -- function llist.add()

-- =======================================================================
-- llist.add_all(): Add each item in valueList to the LLIST.
-- =======================================================================
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) valueList
-- (*) createSpec:
-- Return:
-- On Success:  The number of successful inserts.
-- On Error: Error Code, Error Msg
-- =======================================================================
-- TODO: Convert this to use a COMMON local INSERT() function, not just
-- call llist.add() and do all of its validation each time.
-- REMEMBER to set KeyType on the First insert.
-- =======================================================================
function llist.add_all( topRec, ldtBinName, valueList, createSpec, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST ADD_ALL ] <<<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local meth = "insert_all()";

  if valueList == nil or getmetatable(valueList) ~= List or #valueList == 0 then
    info("[ERROR]<%s:%s> Input Parameter <valueList> is bad", MOD, meth);
    info("[ERROR]<%s:%s>  valueList(%s)", MOD, meth, tostring(valueList));
    error(ldte.ERR_INPUT_PARM);
  end

  local valListSize = #valueList;
  local firstValue = valueList[1];

  GP=E and trace("[ENTER]:<%s:%s>BIN(%s) valueListSize(%d) createSpec(%s)",
  MOD, meth, tostring(ldtBinName), valListSize, tostring(createSpec));

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  -- This function does not build, save or update.  It only checks.
  -- Check to see if LDT Structure (or anything) is already there.  If there
  -- is an LDT BIN present, then it MUST be valid.
  validateRecBinAndMap( topRec, ldtBinName, false );

  -- If the record does not exist, or the BIN does not exist, then we must
  -- create it and initialize the LDT map. Otherwise, use it.
  if( topRec[ldtBinName] == nil ) then
    GP=F and trace("[INFO]<%s:%s>LLIST CONTROL BIN does not Exist:Creating",
         MOD, meth );

    -- set up our new LDT Bin
    local firstValue = 
    setupLdtBin( topRec, ldtBinName, createSpec, firstValue );
  end

  local ldtCtrl = topRec[ ldtBinName ];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  GP=D and trace("[DEBUG]<%s:%s> LDT Summary(%s)", MOD, meth,
    ldtSummaryString(ldtCtrl));

  -- We have to check to see if our KeyType is set, and if not, set it based
  -- on the first value.  In most cases, it will already have been set by
  -- setupLdtBin(), but if the LDT was created with create(), then we won't
  -- see a first value until the first insert, even though the LDT is set up.
  if ldtMap[LC.KeyType] == KT_NONE then
    setupKeyType(ldtMap, firstValue);
  end

  -- Set up the Read/Write Functions (KeyFunction, Transform, Untransform)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction(ldtMap, false, G_KeyFunction); 
  end
  G_Filter, G_UnTransform = ldt_common.setReadFunctions( ldtMap, nil, nil );
  G_Transform = ldt_common.setWriteFunctions( ldtMap );
  
  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  local rc = 0;
  local successCount = 0;
    for i = 1, valListSize, 1 do
--    rc = llist.add( topRec, ldtBinName, valueList[i], createSpec, src );
      rc = localWrite(src, topRec, ldtBinName, ldtCtrl, valueList[i], false);
      if( rc < 0 ) then
        info("[ERROR]<%s:%s> Problem Inserting Item #(%d) [%s]", MOD, meth, i,
          tostring( valueList[i] ));
        -- Skip the errors for now -- just report them, don't die.
        -- error(ldte.ERR_INSERT);
      else
        successCount = successCount + 1;
      end
    end -- for each value in the list
  
  return successCount;
end -- llist.add_all()

-- ======================================================================
-- llist.update() -- Insert an element into the ordered list if the
-- element is not already there, otherwise OVERWRITE that element
-- when UNIQUE is turned on.  If UNIQUE is turned off, then simply add
-- another duplicate value.
-- ======================================================================
-- This function does the work of both calls -- with and without inner UDF.
--
-- Insert a value into the list (into the B+ Tree).  We will have both a
-- COMPACT storage mode and a TREE storage mode.  When in COMPACT mode,
-- the root node holds the list directly (Ordered search and insert).
-- When in Tree mode, the root node holds the top level of the tree.
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) newValue:
-- (*) createSpec:
-- (*) src: Sub-Rec Context - Needed for repeated calls from caller
-- =======================================================================
function llist.update( topRec, ldtBinName, newValue, createSpec, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST UPDATE ] <<<<<<<<<<< \n");
  local meth = "llist.add()";
  GP=E and trace("[ENTER]<%s:%s>LLIST BIN(%s) NwVal(%s) createSpec(%s) src(%s)",
    MOD, meth, tostring(ldtBinName), tostring( newValue ),
    tostring(createSpec), tostring(src));

  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  -- This function does not build, save or update.  It only checks.
  -- Check to see if LDT Structure (or anything) is already there.  If there
  -- is an LDT BIN present, then it MUST be valid.
  validateRecBinAndMap( topRec, ldtBinName, false );

  -- If the record does not exist, or the BIN does not exist, then we must
  -- create it and initialize the LDT map. Otherwise, use it.
  if( topRec[ldtBinName] == nil ) then
    GP=F and trace("[INFO]<%s:%s>LLIST CONTROL BIN does not Exist:Creating",
         MOD, meth );

    -- set up our new LDT Bin
    setupLdtBin( topRec, ldtBinName, createSpec, newValue );
  end

  local ldtCtrl = topRec[ ldtBinName ];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  GP=D and trace("[DEBUG]<%s:%s> LDT Summary(%s)", MOD, meth,
    ldtSummaryString(ldtCtrl));

  -- We have to check to see if our KeyType is set, and if not, set it based
  -- on the first value.  In most cases, it will already have been set by
  -- setupLdtBin(), but if the LDT was created with create(), then we won't
  -- see a first value until the first insert, even though the LDT is set up.
  if ldtMap[LC.KeyType] == KT_NONE then
    setupKeyType(ldtMap, newValue);
  end

  -- Set up the Read/Write Functions (KeyFunction, Transform, Untransform)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction(ldtMap, false, G_KeyFunction); 
  end
  G_Filter, G_UnTransform = ldt_common.setReadFunctions( ldtMap, nil, nil );
  G_Transform = ldt_common.setWriteFunctions( ldtMap );
  
  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- call localWrite() with UPDATE flag turned ON.
  return localWrite(src, topRec, ldtBinName, ldtCtrl, newValue, true);

end -- function llist.update()

-- =======================================================================
-- llist.update_all(): Update each item in valueList in the LLIST.
-- =======================================================================
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) valueList
-- (*) createSpec:
-- Return:
-- Success: Count of successful operations
-- Error:  Error Code, Error Message
-- =======================================================================
function llist.update_all( topRec, ldtBinName, valueList, createSpec, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST ADD_ALL ] <<<<<<<<<<< \n");

  aerospike:set_context( topRec, UDF_CONTEXT_LDT );
  local meth = "llist.update_all()";
  GP=E and trace("[ENTER]:<%s:%s>BIN(%s) valueList(%s) createSpec(%s)",
  MOD, meth, tostring(ldtBinName), tostring(valueList), tostring(createSpec));
  
  if valueList == nil or getmetatable(valueList) ~= List or #valueList == 0 then
    info("[ERROR]<%s:%s> Input Parameter <valueList> is bad", MOD, meth);
    info("[ERROR]<%s:%s>  valueList(%s)", MOD, meth, tostring(valueList));
    error(ldte.ERR_INPUT_PARM);
  end

  local valListSize = #valueList;
  local firstValue = valueList[1];

  GP=E and trace("[ENTER]:<%s:%s>BIN(%s) valueListSize(%d) createSpec(%s)",
  MOD, meth, tostring(ldtBinName), valListSize, tostring(createSpec));

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  -- This function does not build, save or update.  It only checks.
  -- Check to see if LDT Structure (or anything) is already there.  If there
  -- is an LDT BIN present, then it MUST be valid.
  validateRecBinAndMap( topRec, ldtBinName, false );

  -- If the record does not exist, or the BIN does not exist, then we must
  -- create it and initialize the LDT map. Otherwise, use it.
  if( topRec[ldtBinName] == nil ) then
    GP=F and trace("[INFO]<%s:%s>LLIST CONTROL BIN does not Exist:Creating",
         MOD, meth );

    -- set up our new LDT Bin
    setupLdtBin( topRec, ldtBinName, createSpec, firstValue );
  end

  local ldtCtrl = topRec[ ldtBinName ];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  GP=D and trace("[DEBUG]<%s:%s> LDT Summary(%s)", MOD, meth,
    ldtSummaryString(ldtCtrl));

  -- We have to check to see if our KeyType is set, and if not, set it based
  -- on the first value.  In most cases, it will already have been set by
  -- setupLdtBin(), but if the LDT was created with create(), then we won't
  -- see a first value until the first insert, even though the LDT is set up.
  if ldtMap[LC.KeyType] == KT_NONE then
    setupKeyType(ldtMap, firstValue);
  end

  -- Set up the Read/Write Functions (KeyFunction, Transform, Untransform)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction(ldtMap, false, G_KeyFunction); 
  end
  G_Filter, G_UnTransform = ldt_common.setReadFunctions( ldtMap, nil, nil );
  G_Transform = ldt_common.setWriteFunctions( ldtMap );
  
  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  local rc = 0;
  local successCount = 0;
  if( valueList ~= nil and list.size(valueList) > 0 ) then
    local listSize = list.size( valueList );
    for i = 1, listSize, 1 do
--    rc = llist.update( topRec, ldtBinName, valueList[i], createSpec, src );
      rc = localWrite(src, topRec, ldtBinName, ldtCtrl, valueList[i], true);
      if( rc < 0 ) then
        warn("[ERROR]<%s:%s> Problem Updating Item #(%d) [%s]", MOD, meth, i,
          tostring( valueList[i] ));
        -- Don't "error out".  Just count the successes.
        -- error(ldte.ERR_INSERT);
      else
        successCount = successCount + 1;
      end
    end -- for each value in the list
  else
    warn("[ERROR]<%s:%s> Invalid Input Value List(%s)",
      MOD, meth, tostring(valueList));
    error(ldte.ERR_INPUT_PARM);
  end
  
  return successCount;
end -- llist.update_all()

-- =======================================================================
-- llist.find() - Locate all items corresponding to searchKey
-- =======================================================================
-- Return all objects that correspond to this SINGLE key value.
--
-- Note that a key of "nil" will search to the leftmost part of the tree
-- and then will match ALL keys, so it is effectively a scan.
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) value
-- (*) userModule
-- (*) func:
-- (*) fargs:
-- (*) src: Sub-Rec Context - Needed for repeated calls from caller
-- Result:
-- (*) Success: resultList
-- (*) Error:   error() function is called to jump out of Lua.
-- =======================================================================
-- The find() function can do multiple things. 
-- =======================================================================
function llist.find(topRec,ldtBinName,value,userModule,filter,fargs, src)
  GP=B and info("\n\n >>>>>>>>>>>> API[ LLIST FIND ] <<<<<<<<<<< \n");
  local meth = "llist.find()";
  GP=E and trace("[ENTER]<%s:%s> bin(%s) Value(%s) UM(%s) Fltr(%s) Fgs(%s)",
    MOD, meth, tostring(ldtBinName), tostring(value), tostring(userModule),
    tostring(filter), tostring(fargs));

  aerospike:set_context( topRec, UDF_CONTEXT_LDT );
  local rc = 0;

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );
  
  -- Extract the property map and control map from the ldt bin list.
  local ldtCtrl = topRec[ldtBinName];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- Nothing to find in an empty tree
  if( propMap[PM.ItemCount] == 0 ) then
    debug("[NOTICE]<%s:%s> EMPTY LIST: Not Found: value(%s)", MOD, meth,
      tostring( value ) );
    error( ldte.ERR_NOT_FOUND );
  end

  -- Define our return list.  If the search value is NIL, then we will
  -- return the whole thing.  When that is the case, we want to be sure
  -- to define our resultList IN ADVANCE to be large.
  local resultList;
  
  -- Set up our resultList and populate the read functions.
  -- If search value is null, we don't need to set up a key function, since
  -- everything will qualify.
  if value ~= nil then
    -- Regular (probably small) resultList.
    resultList = list();
    if ldtMap[LC.KeyType] == KT_COMPLEX then
      G_KeyFunction = ldt_common.setKeyFunction(ldtMap,false,G_KeyFunction); 
    end
  else
    -- Full Size ResultList -- probably the size of the entire LDT.
    resultList = list.new(propMap[PM.ItemCount]);
  end

  -- set up the Read Functions (UnTransform, Filter)
  G_Filter, G_UnTransform =
      ldt_common.setReadFunctions( ldtMap, userModule, filter );
  G_FunctionArgs = fargs;

  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- We expect the user to pass in a KEY to search for, but if they pass in
  -- an OBJECT, then we can still deal with that.  If the input value is an
  -- object, we'll extract a key from it.  Otherwise, we'll pass it thru.
  local key = getKeyValue(ldtMap, value);
  GP=D and trace("[DEBUG]<%s:%s> Key(%s) from Value(%s)", MOD, meth,
    tostring(key), tostring(value));

  local resultA;
  local resultB;

  -- If our state is "compact", do a simple list search, otherwise do a
  -- full tree search.
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Do the COMPACT LIST SEARCH
    local objectList = ldtMap[LS.CompactList];
    local resultMap = searchObjectList( ldtMap, objectList, key );
    if( resultMap.Status == ERR.OK and resultMap.Found ) then
      local position = resultMap.Position;
      resultA, resultB = 
          listScan(objectList, position, ldtMap, resultList, key, CR.EQUAL);
      GP=F and trace("[DEBUG]<%s:%s> Scan Compact List:Res(%s) A(%s) B(%s)",
        MOD, meth, tostring(resultList), tostring(resultA), tostring(resultB));
      if( resultB < 0 ) then
        warn("[ERROR]<%s:%s> Problems with Scan: Key(%s), List(%s)", MOD, meth,
          tostring( key ), tostring( objectList ) );
        error( ldte.ERR_INTERNAL );
      end
    else
      debug("[NOTICE]<%s:%s> Search Not Found: Key(%s), List(%s)", MOD, meth,
        tostring( key ), tostring( objectList ) );
      error( ldte.ERR_NOT_FOUND );
    end
  else
    -- Do the TREE Search
    GP=F and trace("[DEBUG]<%s:%s> Searching Tree", MOD, meth );
    local sp = createSearchPath(ldtMap);
    rc = treeSearch( src, topRec, sp, ldtCtrl, key );
    if( rc == ST.FOUND ) then
      rc = treeScan( src, resultList, topRec, sp, ldtCtrl, key, CR.EQUAL);
      if( rc < 0 or list.size( resultList ) == 0 ) then
          warn("[ERROR]<%s:%s> Tree Scan Problem: RC(%d) after a good search",
            MOD, meth, rc );
      end
    else
      debug("[NOTICE]<%s:%s> Tree Search Not Found: Key(%s)", MOD, meth,
        tostring( key ) );
      error( ldte.ERR_NOT_FOUND );
    end
  end -- tree search

  -- Close ALL of the subrecs that might have been opened
  rc = ldt_common.closeAllSubRecs( src );
  if( rc < 0 ) then
    warn("[EARLY EXIT]<%s:%s> Problem closing subrec in search", MOD, meth );
    error( ldte.ERR_SUBREC_CLOSE );
  end

  GP=D and trace("[EXIT]: <%s:%s>: Search Key(%s) Result: Sz(%d) List(%s)",
    MOD, meth, tostring(key), list.size(resultList), tostring(resultList));
  
  GP=F and trace("[EXIT]: <%s:%s>: Search Key(%s) Result: Sz(%d) List(%s)",
    MOD, meth, tostring(key), list.size(resultList), tostring(resultList));
  
  -- We have either jumped out of here via error() function call, or if
  -- we got this far, then we are supposed to have a valid resultList.
  return resultList;
end -- function llist.find() 

-- =======================================================================
-- These functions are UNDER CONSTRUCTION
-- =======================================================================
-- (*) Object = llist.find_min(topRec,ldtBinName)
-- (*) Object = llist.find_max(topRec,ldtBinName)

-- =======================================================================
-- llist.find_min() - Locate the MINIMUM item and return it
-- =======================================================================
-- Drop down to the Left Leaf and return the FIRST element.
-- all of the work.
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) src: Sub-Rec Context - Needed for repeated calls from caller
-- Result:
-- Success: Object is returned
-- Error: Error Code/String
-- =======================================================================
function llist.find_min( topRec,ldtBinName, src)
  GP=B and info("\n\n >>>>>>>>>>>> API[ LLIST FIND MIN ] <<<<<<<<<<< \n");
  local meth = "llist.find_min()";
  GP=E and trace("[ENTER]<%s:%s> bin(%s) ", MOD, meth, tostring( ldtBinName));
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local result = treeMin( topRec, ldtBinName, false );
  local resultList = list();

  local rc = 0;
  -- Define our return value;
  local resultValue = "THIS FUNCTION UNDER CONSTRUCTION ";
  
  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );
  
  -- Extract the property map and control map from the ldt bin list.
  local ldtCtrl = topRec[ldtBinName];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- If our itemCount is ZERO, then quickly return NIL before we get into
  -- any trouble.
  if( propMap[PM.ItemCount] == 0 ) then
    debug("[ATTENTION]<%s:%s> Searching for MIN of EMPTY TREE", MOD, meth );
    return nil;
  end

  -- set up the Read Functions (UnTransform, Filter)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction( ldtMap, false, G_KeyFunction ); 
  end
  G_Filter, G_UnTransform =
      ldt_common.setReadFunctions( ldtMap, nil, nil );
  G_FunctionArgs = nil;

  -- Init our subrecContext, if necessary.  The SRC tracks all open
  -- SubRecords during the call. Then, allows us to close them all at the end.
  -- For the case of repeated calls from Lua, the caller must pass in
  -- an existing SRC that lives across LDT calls.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  local resultA;
  local resultB;
  local storeObject;
  local resultObject;
  local key = nil; -- this takes us to the left-most element.

  -- If our state is "compact", just get the first element.
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Do the COMPACT LIST SEARCH
    local objectList = ldtMap[LS.CompactList];
    -- If we have a transform/untransform, do that here.
    storeObject = objectList[1];
    if( G_UnTransform ~= nil ) then
      resultObject = G_UnTransform( storeObject );
    else
      resultObject = storeObject;
    end
    list.append(resultList, resultObject);
  else
    -- It's a "regular" Tree State, so do the Tree Operation.
    -- Note that "Left-Most" is a special case, where by using a nil key
    -- we automatically go to the "minimal" position.  We can pull
    -- the value from our Search Path (sp) Object.
    GP=F and trace("[DEBUG]<%s:%s> Searching Tree", MOD, meth );
    local sp = createSearchPath(ldtMap);
    rc = treeSearch( src, topRec, sp, ldtCtrl, nil );
    -- We're just going to assume there's a MIN found, given that
    -- there's a non-zero tree present.

    if( rc == ST.FOUND ) then
      rc = treeScan( src, resultList, topRec, sp, ldtCtrl, key, CR.EQUAL );
      if( rc < 0 or list.size( resultList ) == 0 ) then
          warn("[ERROR]<%s:%s> Tree Scan Problem: RC(%d) after a good search",
            MOD, meth, rc );
      end
    else
      debug("[NOTICE]<%s:%s> Tree Search Not Found: Key(%s)", MOD, meth,
        tostring( key ) );
      error( ldte.ERR_NOT_FOUND );
    end
  end -- tree search

  -- Close ALL of the subrecs that might have been opened
  rc = ldt_common.closeAllSubRecs( src );
  if( rc < 0 ) then
    warn("[EARLY EXIT]<%s:%s> Problem closing subrec in search", MOD, meth );
    error( ldte.ERR_SUBREC_CLOSE );
  end

  -- NOTE: No need to write the TopRec for a Query operation.

  GP=F and trace("[EXIT]: <%s:%s>: Search Key(%s) Result: Sz(%d) List(%s)",
  MOD, meth, tostring(key), list.size(resultList), tostring(resultList));
  
  -- We have either jumped out of here via error() function call, or if
  -- we got this far, then we are supposed to have a valid resultList.
  return resultList;
end -- function llist.find_min() 

-- =======================================================================
-- llist.exists()
-- =======================================================================
-- Return 1 if the value (object/key) exists, otherwise return 0.
--
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) value
-- (*) src
-- Result:
-- (*) 1 if value exists, 0 if it does not.
-- (*) Error:   error() function is called to jump out of Lua.
-- =======================================================================
function llist.exists(topRec,ldtBinName,value,src)
  GP=B and info("\n\n >>>>>>>>>>>> API[ LLIST EXISTS ] <<<<<<<<<<< \n");
  local meth = "llist.exists()";
  GP=E and trace("[ENTER]<%s:%s> bin(%s) Value(%s)",
    MOD, meth, tostring(ldtBinName), tostring(value));
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  warn("[ERROR]<%s:%s> Function Under Construction", MOD, meth);
  error(ldte.ERR_INTERNAL);

  return 0;

end -- llist.exists()

-- =======================================================================
-- llist.range() - Locate all items in the range of minKey to maxKey.
-- =======================================================================
-- Do the initial search to find minKey, then perform a scan until maxKey
-- is found.  Return all values that pass any supplied filters.
-- If minKey is null -- scan starts at the LEFTMOST side of the list or tree.
-- If maxKey is null -- scan will continue to the end of the list or tree.
-- Parms:
-- (*) topRec: The Aerospike Top Record
-- (*) ldtBinName: The Bin of the Top Record used for this LDT
-- (*) minKey: The starting value of the range: Nil means neg infinity
-- (*) maxKey: The end value of the range: Nil means infinity
-- (*) userModule: The module possibly holding the user's filter
-- (*) filter: the optional predicate filter
-- (*) fargs: Arguments to the filter
-- (*) src: Sub-Rec Context - Needed for repeated calls from caller
-- Result:
-- Success: resultList holds the result of the range query
-- Error: Error string to outside Lua caller.
-- =======================================================================
function
llist.range(topRec, ldtBinName,minKey,maxKey,userModule,filter,fargs,src)
  GP=B and info("\n\n >>>>>>>>>>>> API[ LLIST RANGE ] <<<<<<<<<<< \n");
  local meth = "llist.range()";
  GP=E and trace("[ENTER]<%s:%s> bin(%s) minKey(%s) maxKey(%s)", MOD, meth,
      tostring( ldtBinName), tostring(minKey), tostring(maxKey));

  aerospike:set_context( topRec, UDF_CONTEXT_LDT );
  local rc = 0;
  -- Define our return list.  Note that this is an unknown size, but
  -- we want to handle reasonable growth.  Go with an initial size of 50
  -- and a growth of 100.
  local resultList = list.new(50, 100);
  
  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );
  
  -- Extract the property map and control map from the ldt bin list.
  local ldtCtrl = topRec[ldtBinName];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  -- set up the Read Functions (UnTransform, Filter)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction(ldtMap, false, G_KeyFunction); 
  end
  G_Filter, G_UnTransform =
      ldt_common.setReadFunctions( ldtMap, userModule, filter );
  G_FunctionArgs = fargs;

  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  local resultA; -- instruction: stop or keep scanning
  local resultB; -- Result: 0: ok,  < 0: error.
  local position;-- location where the item would be (found or not)

  -- If our state is "compact", do a simple list search, otherwise do a
  -- full tree search.
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Do the <><><> COMPACT LIST SEARCH <><><>
    local objectList = ldtMap[LS.CompactList];
    -- This search only finds the place to start the scan (range scan), it does
    -- NOT need to find the first element.
    local resultMap = searchObjectList( ldtMap, objectList, minKey );
    position = resultMap.Position;

    if( resultMap.Status == ERR.OK and resultMap.Found ) then
      GP=F and trace("[FOUND]<%s:%s> CL: Found first element at (%d)",
        MOD, meth, position);
    end

    resultA, resultB = 
        listScan(objectList,position,ldtMap,resultList,maxKey,CR.GREATER_THAN);
    GP=F and trace("[DEBUG]<%s:%s> Scan Compact List:Res(%s) A(%s) B(%s)",
      MOD, meth, tostring(resultList), tostring(resultA), tostring(resultB));
    if( resultB < 0 ) then
      warn("[ERROR]<%s:%s> Problems with Scan: MaxKey(%s), List(%s)", MOD,
        meth, tostring( maxKey ), tostring( objectList ) );
      error( ldte.ERR_INTERNAL );
    end

  else
    -- Do the <><><> TREE Search <><><>
    GP=F and trace("[DEBUG]<%s:%s> Searching Tree", MOD, meth );
    local sp = createSearchPath(ldtMap);
    rc = treeSearch( src, topRec, sp, ldtCtrl, minKey );
    -- Recall that we don't need to find the first element for a Range Scan.
    -- The search ONLY finds the place where we start the scan.
    if( rc == ST.FOUND ) then
      GP=F and trace("[FOUND]<%s:%s> TS: Found: SearchPath(%s)", MOD, meth,
        tostring( sp ));
    end

    rc = treeScan(src,resultList,topRec,sp,ldtCtrl,maxKey,CR.GREATER_THAN);
    if( rc < 0 or list.size( resultList ) == 0 ) then
        warn("[ERROR]<%s:%s> Tree Scan Problem: RC(%d) after a good search",
          MOD, meth, rc );
    end
  end -- tree search

  -- Close ALL of the subrecs that might have been opened
  rc = ldt_common.closeAllSubRecs( src );
  if( rc < 0 ) then
    warn("[EARLY EXIT]<%s:%s> Problem closing subrec in search", MOD, meth );
    error( ldte.ERR_SUBREC_CLOSE );
  end

  GP=F and trace("[EXIT]<%s:%s>Range: MnKey(%s) MxKey(%s) ==> Sz(%d) List(%s)",
    MOD, meth, tostring(minKey), tostring(maxKey), list.size(resultList),
    tostring(resultList));
  
  -- We have either jumped out of here via error() function call, or if
  -- we got this far, then we are supposed to have a valid resultList.
  return resultList;
end -- function llist.range() 

-- =======================================================================
-- scan(): Return all elements (no filter).
-- =======================================================================
-- Return:
-- Success: the Result List.
-- Error: Error String to outer Lua Caller (long jump)
-- =======================================================================
function llist.scan( topRec, ldtBinName, src )
  GP=B and info("\n\n  >>>>>>>>>>>> API[ SCAN ] <<<<<<<<<<<<<< \n");
  local meth = "scan()";
  GP=E and trace("[ENTER]<%s:%s> BIN(%s)", MOD, meth, tostring(ldtBinName) );
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  return llist.find( topRec, ldtBinName,nil, nil, nil, nil, src );
end -- llist.scan()

-- =======================================================================
-- filter(): Pass all elements thru the filter and return all that qualify.
-- =======================================================================
-- Do a full scan and pass all elements thru the filter, returning all
-- elements that match.
-- Return:
-- Success: the Result List.
-- Error: error()
-- =======================================================================
function llist.filter( topRec, ldtBinName, userModule, filter, fargs, src )
  GP=B and info("\n\n  >>>>>>>>>>>> API[ FILTER ]<<<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local meth = "filter()";
  GP=E and trace("[ENTER]<%s:%s> BIN(%s) module(%s) func(%s) fargs(%s)",
    MOD, meth, tostring(ldtBinName), tostring(userModule),
    tostring(filter), tostring(fargs));

  return llist.find( topRec, ldtBinName, nil, userModule, filter, fargs, src );
end -- llist.filter()

-- ======================================================================
-- llist.remove() -- remove the item(s) corresponding to key.
-- ======================================================================
-- Delete the specified item(s).
--
-- Parms 
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) LdtBinName
-- (3) value: The value/key we'll search for
-- (4) src: Sub-Rec Context - Needed for repeated calls from caller
-- ======================================================================
function llist.remove( topRec, ldtBinName, value, src )
  GP=F and trace("\n\n  >>>>>>>>>>>> API[ REMOVE ]<<<<<<<<<<< \n");
  local meth = "llist.remove()";
  local rc = 0;
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  GP=E and trace("[ENTER]<%s:%s>ldtBinName(%s) value(%s)",
      MOD, meth, tostring(ldtBinName), tostring(value));

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );
  
  -- Extract the property map and control map from the ldt bin list.
  ldtCtrl = topRec[ ldtBinName ];
  local propMap = ldtCtrl[1];
  local ldtMap  = ldtCtrl[2];

  local resultMap;

  -- Set up the Read Functions (KeyFunction, Transform, Untransform)
  if ldtMap[LC.KeyType] == KT_COMPLEX then
    G_KeyFunction = ldt_common.setKeyFunction(ldtMap, false, G_KeyFunction); 
  end
  G_Filter, G_UnTransform = ldt_common.setReadFunctions( ldtMap, nil, nil );

  -- Init our subrecContext, if necessary.  The SRC tracks all open
  -- SubRecords during the call. Then, allows us to close them all at the end.
  -- For the case of repeated calls from Lua, the caller must pass in
  -- an existing SRC that lives across LDT calls.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- This must be turned OFF in production.
  -- GP=DEBUG and printTree( src, topRec, ldtBinName );
  
  -- We expect the user to pass in a KEY to search for, but if they pass in
  -- an OBJECT, then we can still deal with that.  If the input value is an
  -- object, we'll extract a key from it.  Otherwise, we'll pass it thru.
  local key = getKeyValue(ldtMap, value);
  GP=D and trace("[DEBUG]<%s:%s> Key(%s) from Value(%s)", MOD, meth,
    tostring(key), tostring(value));

  -- If our state is "compact", do a simple list delete, otherwise do a
  -- real tree delete.
  if( ldtMap[LS.StoreState] == SS_COMPACT ) then 
    -- Search the compact list, find the location, then delete it.
    GP=D and trace("[NOTICE]<%s:%s> Using COMPACT DELETE", MOD, meth);
    local objectList = ldtMap[LS.CompactList];
    resultMap = searchObjectList( ldtMap, objectList, key );
    if( resultMap.Status == ERR.OK and resultMap.Found ) then
      ldtMap[LS.CompactList] =
        ldt_common.listDelete(objectList, resultMap.Position);
    else
      error( ldte.ERR_NOT_FOUND );
    end
  else
    GP=D and trace("[NOTICE]<%s:%s> Using >>>  TREE DELETE  <<<", MOD, meth);
    rc = treeDelete(src, topRec, ldtCtrl, key );
  end

  -- update our count statistics if successful
  if( rc >= 0 ) then 
    local itemCount = propMap[PM.ItemCount];
    -- local totalCount = ldtMap[LS.TotalCount];
    propMap[PM.ItemCount] = itemCount - 1; 
    -- ldtMap[LS.TotalCount] = totalCount - 1;
    GP=F and trace("[DEBUG]: <%s:%s> itemCount(%d)", MOD, meth, itemCount );
    rc = 0;
  end

  -- Validate results -- if anything bad happened, then the record
  -- probably did not change -- we don't need to update.
  if( rc == 0 ) then
    -- Close ALL of the subrecs that might have been opened
    rc = ldt_common.closeAllSubRecs( src );
    if( rc < 0 ) then
      warn("[ERROR]<%s:%s> Problems closing subrecs in delete", MOD, meth );
      error( ldte.ERR_SUBREC_CLOSE );
    end

    -- All done, Update and store the record
    topRec[ ldtBinName ] = ldtCtrl;
    record.set_flags(topRec, ldtBinName, BF.LDT_BIN );--Must set every time
    GP=F and trace("[DEBUG]:<%s:%s>:Update Record()", MOD, meth );
    rc = aerospike:update( topRec );
    if  rc ~= 0 then
      warn("[ERROR]<%s:%s>TopRec Update Error rc(%s)",MOD,meth,tostring(rc));
      error( ldte.ERR_TOPREC_UPDATE );
    end 

    GP=F and trace("[Normal EXIT]:<%s:%s> Return(0)", MOD, meth );
    return 0;
  else
    GP=F and trace("[ERROR EXIT]:<%s:%s> Return(%s)", MOD, meth,tostring(rc));
    error( ldte.ERR_DELETE );
  end
end -- function llist.remove()

-- =======================================================================
-- llist.remove_all(): Remove each item in valueList from the LLIST.
-- =======================================================================
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) valueList
-- =======================================================================
function llist.remove_all( topRec, ldtBinName, valueList, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST REMOVE_ALL ] <<<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local meth = "remove_all()";
  local valListSize = valueList ~= nil and #valueList or 0;
  GP=E and trace("[ENTER]:<%s:%s>BIN(%s) valueListSize(%d)",
  MOD, meth, tostring(ldtBinName), valListSize);
  
  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  local rc = 0;
  if( valueList ~= nil and list.size(valueList) > 0 ) then
    local listSize = list.size( valueList );
    for i = 1, listSize, 1 do
      rc = llist.remove( topRec, ldtBinName, valueList[i], src );
      if( rc < 0 ) then
        warn("[ERROR]<%s:%s> Problem Removing Item #(%d) [%s]", MOD, meth, i,
          tostring( valueList[i] ));
        error(ldte.ERR_DELETE);
      end
    end -- for each value in the list
  else
    warn("[ERROR]<%s:%s> Invalid Delete Value List(%s)",
      MOD, meth, tostring(valueList));
    error(ldte.ERR_INPUT_PARM);
  end
  
  return rc;
end -- llist.remove_all()


-- =======================================================================
-- llist.remove_range(): Remove all items in the given range
-- =======================================================================
-- Perform a range query, and if any values are returned, remove each one
-- of them individually.
-- Parms:
-- (*) topRec:
-- (*) ldtBinName:
-- (*) valueList
-- Return:
-- Success: Count of values removed
-- Error:   Error Code and message
-- =======================================================================
function llist.remove_range( topRec, ldtBinName, minKey, maxKey, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST REMOVE_RANGE ] <<<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local meth = "remove_range()";
  GP=E and trace("[ENTER]:<%s:%s>BIN(%s) minKey(%s) maxKey(%s)",
  MOD, meth, tostring(ldtBinName), tostring(minKey), tostring(maxKey));
  
  -- Create our subrecContext, which tracks all open SubRecords during
  -- the call.  Then, allows us to close them all at the end.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  local valueList  = llist.range( topRec, ldtBinName, minKey, maxKey,
                                  nil, nil, nil, src);
  local deleteCount = 0;

  local rc = 0;
  if( valueList ~= nil and list.size(valueList) > 0 ) then
    local listSize = list.size( valueList );
    for i = 1, listSize, 1 do
      rc = llist.remove( topRec, ldtBinName, valueList[i], src );
      if( rc < 0 ) then
        warn("[ERROR]<%s:%s> Problem Removing Item #(%d) [%s]", MOD, meth, i,
          tostring( valueList[i] ));
        -- error(ldte.ERR_DELETE);
      else
        deleteCount = deleteCount + 1;
      end
    end -- for each value in the list
  else
    debug("[ERROR]<%s:%s> Invalid Delete Value List(%s)",
      MOD, meth, tostring(valueList));
    error(ldte.ERR_INPUT_PARM);
  end
  
  return deleteCount;
end -- llist.remove_range()

-- ========================================================================
-- llist.destroy(): Remove the LDT entirely from the record.
-- ========================================================================
-- Release all of the storage associated with this LDT and remove the
-- control structure of the bin.  If this is the LAST LDT in the record,
-- then ALSO remove the HIDDEN LDT CONTROL BIN.
--
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- (3) src: Sub-Rec Context - Needed for repeated calls from caller
-- Result:
--   res = 0: all is well
--   res = -1: Some sort of error
-- ========================================================================
-- NOTE: This could eventually be moved to COMMON, and be "ldt_destroy()",
-- since it will work the same way for all LDTs.
-- Remove the ESR, Null out the topRec bin.
-- ========================================================================
function llist.destroy( topRec, ldtBinName, src)
  GP=B and info("\n\n >>>>>>>>> API[ LLIST DESTROY ] <<<<<<<<<< \n");
  local meth = "llist.destroy()";
  GP=E and trace("[ENTER]: <%s:%s> Bin(%s)", MOD, meth, tostring(ldtBinName));
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );
  local rc = 0; -- start off optimistic

  -- Validate the BinName before moving forward
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );

  -- Init our subrecContext, if necessary.  The SRC tracks all open
  -- SubRecords during the call. Then, allows us to close them all at the end.
  -- For the case of repeated calls from Lua, the caller must pass in
  -- an existing SRC that lives across LDT calls.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  ldt_common.destroy( src, topRec, ldtBinName, ldtCtrl );

  GP=E and trace("[Normal EXIT]:<%s:%s> Return(0)", MOD, meth );
  return 0;
end -- llist.destroy()

-- ========================================================================
-- llist.size() -- return the number of elements (item count) in the set.
-- ========================================================================
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- Result:
--   SUCCESS: The number of elements in the LDT
--   ERROR: The Error code via error() call
-- ========================================================================
function llist.size( topRec, ldtBinName )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST SIZE ] <<<<<<<<<\n");
  local meth = "llist.size()";
  GP=E and trace("[ENTER1]<%s:%s> Bin(%s)", MOD, meth, tostring(ldtBinName));
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

--  COMMENTED OUT BECAUSE QAA/JETPACK has problems with this.
--  return ldt_common.size( topRec, ldtBinName, LDT_TYPE, G_LDT_VERSION);

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );

  -- Extract the property map and control map from the ldt bin list.
  -- local ldtCtrl = topRec[ ldtBinName ];
  local propMap = ldtCtrl[1];
  local itemCount = propMap[PM.ItemCount];

  GP=F and trace("[EXIT]: <%s:%s> : size(%d)", MOD, meth, itemCount );

  return itemCount;
end -- llist.size()

-- ========================================================================
-- llist.config() -- return the config settings
-- ========================================================================
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- Result:
--   SUCCESS: The MAP of the config.
--   ERROR: The Error code via error() call
-- ========================================================================
function llist.config( topRec, ldtBinName )
  GP=B and info("\n\n >>>>>>>>>>> API[ LLIST CONFIG ] <<<<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local meth = "llist.config()";
  GP=E and trace("[ENTER1]: <%s:%s> ldtBinName(%s)",
    MOD, meth, tostring(ldtBinName));

  -- Validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );

  local config = ldtSummary( ldtCtrl );

  GP=F and trace("[EXIT]<%s:%s> config(%s)", MOD, meth, tostring(config) );

  return config;
end -- function llist.config()

-- ========================================================================
-- llist.get_capacity() -- return the current capacity setting for this LDT
-- Capacity is in terms of Number of Elements.
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- Result:
--   rc >= 0  (the current capacity)
--   rc < 0: Aerospike Errors
-- ========================================================================
function llist.get_capacity( topRec, ldtBinName )
  GP=B and info("\n\n  >>>>>>>> API[ GET CAPACITY ] <<<<<<<<<<<<<<<<<< \n");
  local meth = "llist.get_capacity()";
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  -- Note that we could use the common get_capacity() function.
--return ldt_common.get_capacity( topRec, ldtBinName, LDT_TYPE, G_LDT_VERSION);

  GP=E and trace("[ENTER]: <%s:%s> ldtBinName(%s)",
    MOD, meth, tostring(ldtBinName));

  -- validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );

  local ldtCtrl = topRec[ ldtBinName ];
  -- Extract the property map and LDT control map from the LDT bin list.
  local ldtMap = ldtCtrl[2];
  local capacity = ldtMap[LC.StoreLimit];
  if( capacity == nil ) then
    capacity = 0;
  end

  GP=E and trace("[EXIT]: <%s:%s> : size(%d)", MOD, meth, capacity );

  return capacity;
end -- function llist.get_capacity()

-- ========================================================================
-- llist.set_capacity() -- set the current capacity setting for this LDT
-- ========================================================================
-- Parms:
-- (*) topRec: the user-level record holding the LDT Bin
-- (*) ldtBinName: The name of the LDT Bin
-- (*) capacity: the new capacity (in terms of # of elements)
-- Result:
--   rc >= 0  (the current capacity)
--   rc < 0: Aerospike Errors
-- ========================================================================
function llist.set_capacity( topRec, ldtBinName, capacity )
  GP=B and info("\n\n  >>>>>>>> API[ SET CAPACITY ] <<<<<<<<<<<<<<<<<< \n");

  local meth = "llist.set_capacity()";
  local rc = 0;
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  GP=E and trace("[ENTER]: <%s:%s> ldtBinName(%s) newCapacity(%s)",
    MOD, meth, tostring(ldtBinName), tostring(capacity));

  -- validate the topRec, the bin and the map.  If anything is weird, then
  -- this will kick out with a long jump error() call.
  local ldtCtrl = validateRecBinAndMap( topRec, ldtBinName, true );

  local ldtCtrl = topRec[ ldtBinName ];
  -- Extract the property map and LDT control map from the LDT bin list.
  local ldtMap = ldtCtrl[2];
  if( capacity ~= nil and type(capacity) == "number" and capacity >= 0 ) then
    ldtMap[LC.StoreLimit] = capacity;
  else
    warn("[ERROR]<%s:%s> Bad Capacity Value(%s)",MOD,meth,tostring(capacity));
    error( ldte.ERR_INTERNAL );
  end

  -- All done, store the record
  -- Update the Top Record with the new control info
  topRec[ldtBinName] = ldtCtrl;
  record.set_flags(topRec, ldtBinName, BF.LDT_BIN );--Must set every time
  rc = aerospike:update( topRec );
  if ( rc ~= 0 ) then
    warn("[ERROR]<%s:%s>TopRec Update Error rc(%s)",MOD,meth,tostring(rc));
    error( ldte.ERR_TOPREC_UPDATE );
  end 

  GP=E and trace("[EXIT]: <%s:%s> : new size(%d)", MOD, meth, capacity );
  return 0;
end -- function llist.set_capacity()

-- ========================================================================
-- llist.ldt_exists() --
-- ========================================================================
-- return 1 if there is an llist object here, otherwise 0
-- ========================================================================
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- Result:
--   True:  (LLIST exists in this bin) return 1
--   False: (LLIST does NOT exist in this bin) return 0
-- ========================================================================
function llist.ldt_exists( topRec, ldtBinName )
  GP=B and info("\n\n >>>>>>>>>>> API[ LLIST EXISTS ] <<<<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  local meth = "llist.ldt_exists()";
  GP=E and trace("[ENTER1]: <%s:%s> ldtBinName(%s)",
    MOD, meth, tostring(ldtBinName));

  if ldt_common.ldt_exists(topRec, ldtBinName, LDT_TYPE ) then
    GP=F and trace("[EXIT]<%s:%s> Exists", MOD, meth);
    return 1
  else
    GP=F and trace("[EXIT]<%s:%s> Does NOT Exist", MOD, meth);
    return 0
  end
end -- function llist.ldt_exists()

-- ========================================================================
-- <<< NEW (Experimental) FUNCTIONS >>>====================================
-- ========================================================================
-- (1) llist.write_bytes( topRec, ldtBinName, inputArray, offset, src )
-- (2) llist.read_bytes( topRec, ldtBinName, offset, src )
-- ========================================================================

-- ======================================================================
-- llist.write_bytes( topRec, ldtBinName, inputArray, offset )
-- ======================================================================
-- Take the input array (which may be a string, bytes, or something
-- else) and store it as pieces in the LLIST.  Use a Map Object as the
-- thing we're storing, where the "key" is the sequence number and the
-- "data" is the binary byte array.
--
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- (3) inputArray: The input data
-- (4) offset: Not used yet, but eventually will be the point at which
--             we start writing (or appending).  For now, assumed to be
--             zero, which means WRITE NEW every time.
-- (5) src: Sub-Rec context
--
-- Result:
--   Success: Return number of bytes written
--   Failure: Return error.
-- ======================================================================
function llist.write_bytes( topRec, ldtBinName, inputArray, offset, src)
  GP=B and info("\n\n  >>>>>>>> API[ WRITE BYTES ] <<<<<<<<<<<<<<<<<< \n");

  local meth = "store_bytes()";
  GP=E and info("[ENTER]<%s:%s> Bin(%s)", MOD, meth );

  local Bytes = getmetatable( bytes() );

  -- Depending on the input type, we process the inputArray differently.
  local inputType;
  if type(inputArray) == "string" then
    GP=D and debug("Processing STRING array");
    inputType = 1;
  elseif getmetatable( inputArray ) == Bytes then
    GP=D and debug("Processing BYTES array");
    inputType = 2;
  else
    GP=D and debug("Processing OTHER array(%s)", type(inputArray));
    inputType = 3;
  end

  -- Init our subrecContext, if necessary.  The SRC tracks all open
  -- SubRecords during the call. Then, allows us to close them all at the end.
  -- For the case of repeated calls from Lua, the caller must pass in
  -- an existing SRC that lives across LDT calls.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- Take the byte array and break it into fixed size chunks.  Put that
  -- chunk into an array that is part of a map.  Make a list of those maps
  -- and write that list to our LDT.
  local rc = 0;
  local amountLeft = #inputArray;
  local chunkSize = 1024 * 64;  -- Use 64k chunks
  local keySize = 8;  -- simple number key
  local numChunks = math.ceil(amountLeft / chunkSize);
  local targetPageSize = 1024 * 700;
  local writeBlockSize = 1024 * 1024;
  local maxChunkCount = 200;
  local amountWritten = 0;

  GP=D and debug("[DEBUG]<%s:%s> ByteLen(%d) CH Size(%d) Num CH(%d)", MOD,
    meth, amountLeft, chunkSize, numChunks);

  local mapChunk;
  local bytePayload;
  local stringIndex;
  local configMap = map();
  configMap["Compute"]         = "compute_settings";
  configMap["AveObjectSize"]   = chunkSize;
  configMap["MaxObjectSize"]   = chunkSize;
  configMap["AveKeySize"]      = keySize;
  configMap["MaxKeySize"]      = keySize;
  configMap["AveObjectCount"]  = maxChunkCount;
  configMap["MaxObjectCount"]  = maxChunkCount;
  configMap["TargetPageSize"]  = targetPageSize;
  configMap["WriteBlockSize"]  = writeBlockSize;

  local bytePayLoad;
  local fullStride = chunkSize;
  for c = 0, (numChunks - 1) do
    -- For all full size chunks, we'll stride by the full chunk and offset
    -- thru the string array by that amount.  For either small sizes or
    -- the last chunk, we will have a partial chunk.
    if amountLeft < chunkSize then
      chunkSize = amountLeft;
    end

    -- Create a new Map to hold our data
    mapChunk = map();
    mapChunk["key"] = c;
    stringIndex = (c * fullStride);
    bytePayLoad = bytes(chunkSize);

    for i = 1, chunkSize do
      bytePayLoad[i] =  string.byte(inputArray, (stringIndex + i));
    end -- for each byte in chunk

    mapChunk["data"] = bytePayLoad;
    llist.add( topRec, ldtBinName, mapChunk, configMap, src);
    configMap = nil; -- no need to pass in next time around.
    amountLeft = amountLeft - chunkSize;

    amountWritten = amountWritten + chunkSize;

    GP=D and debug("[DEBUG]<%s:%s> StoredChunk(%d) AmtLeft(%d) ChunkSize(%d)",
      MOD, meth, c, amountLeft, chunkSize);
  end -- end for each Data Chunk

  GP=E and info("[EXIT]<%s:%s> Bin(%s)", MOD, meth, tostring(ldtBinName));

  return amountWritten;
end -- llist.write_bytes()

-- ======================================================================
-- llist.read_bytes( topRec, ldtBinName, offset )
-- ======================================================================
-- From the LLIST object that is holding a list of MAPS that contain
-- binary data, read them and return the binary data.
--
-- Parms:
-- (1) topRec: the user-level record holding the LDT Bin
-- (2) ldtBinName: The name of the LDT Bin
-- (3) offset: Not used yet, but eventually will be the point at which
--             we start writing (or appending).  For now, assumed to be
--             zero, which means WRITE NEW every time.
-- (4) src: Sub-Rec context
-- Result:
--   Success: Return number of bytes written
--   Failure: Return error.
-- ======================================================================
function llist.read_bytes( topRec, ldtBinName, offset, src )
  local meth = "read_bytes()";

  GP=E and info("[ENTER]<%s:%s> Bin(%s) Offset(%d)", MOD, meth,
    tostring(ldtBinName), offset);

  -- Init our subrecContext, if necessary.  The SRC tracks all open
  -- SubRecords during the call. Then, allows us to close them all at the end.
  -- For the case of repeated calls from Lua, the caller must pass in
  -- an existing SRC that lives across LDT calls.
  if ( src == nil ) then
    src = ldt_common.createSubRecContext();
  end

  -- Create a byte array that is the size of the full LDT.  Then fill it
  -- up from the pieces that we've stored in it.
  local ldtSize = llist.size( topRec, ldtBinName );
  GP=D and debug("[DEBUG]<%s:%s> LDT Size(%d)", MOD, meth, ldtSize);

  local resultArray = bytes(ldtSize);

  local ldtScanResult = llist.scan( topRec, ldtBinName, src );

  -- Process our Scan Result and fill up the resultArray.
  local mapObject;
  local outputIndex = 0;
  local byteData;
  local amountRead = 0;

  for i = 1, #ldtScanResult do
    -- Each scan object is a map that contains byte data.  Copy that byte
    -- data into our result.
    mapObject = ldtScanResult[i];
    -- Look inside the map object
    GP=D and debug("[DEBUG]<%s:%s> Obj(%d) Contents(%s)",
      MOD, meth, i, tostring(mapObject));

    byteData = mapObject["data"];
    local byteDataSize = bytes.size(byteData);
    GP=D and debug("[DEBUG]<%s:%s> Reading Chunk(%d) Amount(%d) byteData(%s)",
      MOD, meth, i, byteDataSize, tostring(byteData));
    
    for j = 1, byteDataSize do
      resultArray[outputIndex + j] = byteData[j];
    end -- for each byte in chunk
    outputIndex = outputIndex + byteDataSize;
  end -- for each scan object

  amountRead = outputIndex;

  GP=D and debug("[DEBUG]<%s:%s> Read a total of (%d) bytes", MOD, meth, outputIndex);

  GP=E and info("[EXIT]<%s:%s> Bin(%s) Result Size(%d) Result(%s)", MOD, meth,
    tostring(ldtBinName), #resultArray, tostring(resultArray));

  return resultArray;
end -- read_bytes()

-- ========================================================================
-- llist.dump(): Debugging/Tracing mechanism -- show the WHOLE tree.
-- ========================================================================
-- ========================================================================
function llist.dump( topRec, ldtBinName, src )
  GP=B and info("\n\n >>>>>>>>> API[ LLIST DUMP ] <<<<<<<<<< \n");
  aerospike:set_context( topRec, UDF_CONTEXT_LDT );

  if( src == nil ) then
    src = ldt_common.createSubRecContext();
  end
  printTree( src, topRec, ldtBinName );
  return 0;
end -- llist.dump()

-- ======================================================================
-- This is needed to export the function table for this module
-- Leave this statement at the end of the module.
-- ==> Define all functions before this end section.
-- ======================================================================
return llist;

-- ========================================================================
--   _      _     _____ _____ _____ 
--  | |    | |   |_   _/  ___|_   _|
--  | |    | |     | | \ `--.  | |  
--  | |    | |     | |  `--. \ | |  
--  | |____| |_____| |_/\__/ / | |  
--  \_____/\_____/\___/\____/  \_/   (LIB)
--                                  
-- ========================================================================
-- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> -- <EOF> --
