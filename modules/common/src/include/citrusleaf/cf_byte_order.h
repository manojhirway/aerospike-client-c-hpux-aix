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


#if defined(__PPC__) || defined(__hpux)

#define ___my_swab16(x) \
((u_int16_t)( \
(((u_int16_t)(x) & (u_int16_t)0x00ffU) << 8) | \
(((u_int16_t)(x) & (u_int16_t)0xff00U) >> 8) ))
#define ___my_swab32(x) \
			((u_int32_t)( \
			(((u_int32_t)(x) & (u_int32_t)0x000000ffUL) << 24) | \
			(((u_int32_t)(x) & (u_int32_t)0x0000ff00UL) <<  8) | \
			(((u_int32_t)(x) & (u_int32_t)0x00ff0000UL) >>  8) | \
			(((u_int32_t)(x) & (u_int32_t)0xff000000UL) >> 24) ))
#define ___my_swab64(x) \
			((u_int64_t)( \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x00000000000000ffULL) << 56) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x000000000000ff00ULL) << 40) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x0000000000ff0000ULL) << 24) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x00000000ff000000ULL) <<  8) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x000000ff00000000ULL) >>  8) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x0000ff0000000000ULL) >> 24) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0x00ff000000000000ULL) >> 40) | \
			(u_int64_t)(((u_int64_t)(x) & (u_int64_t)0xff00000000000000ULL) >> 56) ))

#define __be64_to_cpu(x) (x)
#define __be32_to_cpu(x) (x)
#define __be16_to_cpu(x) (x)
#define __cpu_to_be64(x) (x)
#define __cpu_to_be32(x) (x)
#define __cpu_to_be16(x) (x)
#define __le64_to_cpu(x) ___my_swab64(x)
#define __le32_to_cpu(x) ___my_swab32(x)
#define __le16_to_cpu(x) ___my_swab16(x)
#define __cpu_to_le64(x) ___my_swab64(x)
#define __cpu_to_le32(x) ___my_swab32(x)
#define __cpu_to_le16(x) ___my_swab16(x)

typedef uint64_t u_int64_t;
typedef uint32_t u_int32_t;
typedef uint16_t u_int16_t;
typedef uint8_t  u_int8_t;

#define cf_swap_to_be16(_n) __cpu_to_be16(_n)
#define cf_swap_to_le16(_n) __cpu_to_le16(_n)
#define cf_swap_from_be16(_n) __be16_to_cpu(_n)
#define cf_swap_from_le16(_n) __le16_to_cpu(_n)

#define cf_swap_to_be32(_n) __cpu_to_be32(_n)
#define cf_swap_to_le32(_n) __cpu_to_le32(_n)
#define cf_swap_from_be32(_n) __be32_to_cpu(_n)
#define cf_swap_from_le32(_n) __le32_to_cpu(_n)

#define cf_swap_to_be64(_n) __cpu_to_be64(_n)
#define cf_swap_to_le64(_n) __cpu_to_le64(_n)
#define cf_swap_from_be64(_n) __be64_to_cpu(_n)
#define cf_swap_from_le64(_n) __le64_to_cpu(_n)

#endif // __PPC__ or __hpux

#ifdef __cplusplus
extern "C" {
#endif

#if defined(__linux__)

#include <netinet/in.h>
#include <asm/byteorder.h>

#define cf_swap_to_be16(_n) __cpu_to_be16(_n)
#define cf_swap_to_le16(_n) __cpu_to_le16(_n)
#define cf_swap_from_be16(_n) __be16_to_cpu(_n)
#define cf_swap_from_le16(_n) __le16_to_cpu(_n)

#define cf_swap_to_be32(_n) __cpu_to_be32(_n)
#define cf_swap_to_le32(_n) __cpu_to_le32(_n)
#define cf_swap_from_be32(_n) __be32_to_cpu(_n)
#define cf_swap_from_le32(_n) __le32_to_cpu(_n)

#define cf_swap_to_be64(_n) __cpu_to_be64(_n)
#define cf_swap_to_le64(_n) __cpu_to_le64(_n)
#define cf_swap_from_be64(_n) __be64_to_cpu(_n)
#define cf_swap_from_le64(_n) __le64_to_cpu(_n)

#endif // __linux__

#if defined(__APPLE__)
#include <libkern/OSByteOrder.h>
#include <arpa/inet.h>

#define cf_swap_to_be16(_n) OSSwapHostToBigInt16(_n)
#define cf_swap_to_le16(_n) OSSwapHostToLittleInt16(_n)
#define cf_swap_from_be16(_n) OSSwapBigToHostInt16(_n)
#define cf_swap_from_le16(_n) OSSwapLittleToHostInt16(_n)

#define cf_swap_to_be32(_n) OSSwapHostToBigInt32(_n)
#define cf_swap_to_le32(_n) OSSwapHostToLittleInt32(_n)
#define cf_swap_from_be32(_n) OSSwapBigToHostInt32(_n)
#define cf_swap_from_le32(_n) OSSwapLittleToHostInt32(_n)

#define cf_swap_to_be64(_n) OSSwapHostToBigInt64(_n)
#define cf_swap_to_le64(_n) OSSwapHostToLittleInt64(_n)
#define cf_swap_from_be64(_n) OSSwapBigToHostInt64(_n)
#define cf_swap_from_le64(_n) OSSwapLittleToHostInt64(_n)

#endif // __APPLE__

#if defined(CF_WINDOWS)
#include <stdint.h>
#include <stdlib.h>
#include <WinSock2.h>

#define cf_swap_to_be16(_n) _byteswap_uint16(_n)
#define cf_swap_to_le16(_n) (_n)
#define cf_swap_from_be16(_n) _byteswap_uint16(_n)
#define cf_swap_from_le16(_n) (_n)

#define cf_swap_to_be32(_n) _byteswap_uint32(_n)
#define cf_swap_to_le32(_n) (_n)
#define cf_swap_from_be32(_n) _byteswap_uint32(_n)
#define cf_swap_from_le32(_n) (_n)

#define cf_swap_to_be64(_n) _byteswap_uint64(_n)
#define cf_swap_to_le64(_n) (_n)
#define cf_swap_from_be64(_n) _byteswap_uint64(_n)
#define cf_swap_from_le64(_n) (_n)
#endif // CF_WINDOWS

#ifdef __cplusplus
} // end extern "C"
#endif
