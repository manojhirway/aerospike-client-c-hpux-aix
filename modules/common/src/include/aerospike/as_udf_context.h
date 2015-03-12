/* 
 * Copyright 2008-2015 Aerospike, Inc.
 *
 * Portions may be licensed to Aerospike, Inc. under one or more contributor
 * license agreements.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License. You may obtain a copy of
 * the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations under
 * the License.
 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <aerospike/as_memtracker.h>
#include <aerospike/as_timer.h>
#include <aerospike/as_aerospike.h>

/******************************************************************************
 * TYPES
 ******************************************************************************/

typedef struct as_udf_context_s {
	as_aerospike  * as;
	as_timer      * timer; 
	as_memtracker * memtracker;
} as_udf_context;

#ifdef __cplusplus
} // end extern "C"
#endif