	.file	"cf_alloc.c"
	.pred.safe_across_calls p1-p5,p16-p63
	.section	.debug_abbrev,"",@progbits
.Ldebug_abbrev0:
	.section	.debug_info,"",@progbits
.Ldebug_info0:
	.section	.debug_line,"",@progbits
.Ldebug_line0:
	.section	.text,	"ax",	"progbits"
.Ltext0:
	.align 16
	.global cf_rc_count#
	.proc cf_rc_count#
cf_rc_count:
[.LFB21:]
	.file 1 "src/main/citrusleaf/cf_alloc.c"
	.loc 1 61 0
	.prologue
[.LVL0:]
	.body
	.loc 1 62 0
	.mmi
	adds r32 = -4, r32
[.LVL1:]
	.loc 1 64 0
	;;
	ld4.acq r8 = [r32]
	.loc 1 65 0
	nop 0
	;;
	.mib
	nop 0
	addp4 r8 = r8, r0
	br.ret.sptk.many b0
.LFE21:
	.endp cf_rc_count#
	.align 16
	.global cf_rc_reserve#
	.proc cf_rc_reserve#
cf_rc_reserve:
[.LFB22:]
	.loc 1 69 0
	.prologue
[.LVL2:]
	.body
	.loc 1 73 0
#APP
	mfence
	.loc 1 76 0
#NO_APP
	;;
	.mib
	nop 0
	addl r8 = 2, r0
	br.ret.sptk.many b0
.LFE22:
	.endp cf_rc_reserve#
	.align 16
	.global cf_rc_release#
	.proc cf_rc_release#
cf_rc_release:
[.LFB26:]
	.loc 1 118 0
	.prologue
[.LVL3:]
	.body
[.LBB10:]
[.LBB11:]
	.loc 1 110 0
#APP
	mfence
#NO_APP
[.LBE11:]
[.LBE10:]
	.loc 1 120 0
	;;
	.mib
	nop 0
	addl r8 = -2, r0
	br.ret.sptk.many b0
.LFE26:
	.endp cf_rc_release#
	.align 16
	.global cf_rc_free#
	.proc cf_rc_free#
cf_rc_free:
[.LFB24:]
	.loc 1 96 0
	.prologue 12, 33
[.LVL4:]
	.mmi
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 1, 3, 1, 0
	nop 0
	.save rp, r33
	mov r33 = b0
	.mmi
	mov r35 = r1
	.body
	.loc 1 98 0
	nop 0
	adds r36 = -4, r32
[.LVL5:]
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = free#
[.LVL6:]
	;;
	.mmi
	nop 0
	mov r1 = r35
	.loc 1 99 0
	mov b0 = r33
	.mib
	nop 0
	mov ar.pfs = r34
	br.ret.sptk.many b0
.LFE24:
	.endp cf_rc_free#
	.align 16
	.global cf_free#
	.proc cf_free#
cf_free:
[.LFB20:]
	.loc 1 55 0
	.prologue 12, 33
[.LVL7:]
	.mmi
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 1, 3, 1, 0
	nop 0
	.save rp, r33
	mov r33 = b0
	.mmi
	mov r35 = r1
	.body
	.loc 1 56 0
	nop 0
	mov r36 = r32
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = free#
	;;
	.mmi
	nop 0
	mov r1 = r35
	.loc 1 57 0
	mov b0 = r33
	.mib
	nop 0
	mov ar.pfs = r34
	br.ret.sptk.many b0
.LFE20:
	.endp cf_free#
	.align 16
	.global cf_rc_alloc#
	.proc cf_rc_alloc#
cf_rc_alloc:
[.LFB23:]
	.loc 1 82 0
	.prologue 12, 33
[.LVL8:]
	.mmi
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 1, 3, 1, 0
	nop 0
	.save rp, r33
	mov r33 = b0
	.mmi
	mov r35 = r1
	.body
	.loc 1 84 0
	nop 0
	adds r36 = 4, r32
[.LVL9:]
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = malloc#
[.LVL10:]
	.loc 1 86 0
	;;
	.mmi
	cmp.ne p6, p7 = 0, r8
	.loc 1 84 0
	mov r1 = r35
	.loc 1 92 0
	mov b0 = r33
	.loc 1 89 0
	;;
	.mii
	(p6) addl r14 = 1, r0
	.loc 1 92 0
	mov ar.pfs = r34
	.loc 1 89 0
	;;
	nop 0
	.mib
	(p6) st8.rel [r8] = r14, 4
	.loc 1 92 0
	nop 0
	br.ret.sptk.many b0
.LFE23:
	.endp cf_rc_alloc#
	.align 16
	.global cf_malloc#
	.proc cf_malloc#
cf_malloc:
[.LFB14:]
	.loc 1 31 0
	.prologue 12, 33
[.LVL11:]
	.mmi
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 1, 3, 1, 0
	nop 0
	.save rp, r33
	mov r33 = b0
	.mmi
	mov r35 = r1
	.body
	.loc 1 32 0
	nop 0
	mov r36 = r32
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = malloc#
	.loc 1 33 0
	;;
	.loc 1 32 0
	.mmi
	nop 0
	mov r1 = r35
	.loc 1 33 0
	mov b0 = r33
	.mib
	nop 0
	mov ar.pfs = r34
	br.ret.sptk.many b0
.LFE14:
	.endp cf_malloc#
	.align 16
	.global cf_valloc#
	.proc cf_valloc#
cf_valloc:
[.LFB19:]
	.loc 1 51 0
	.prologue 12, 33
[.LVL12:]
	.mmi
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 1, 3, 1, 0
	nop 0
	.save rp, r33
	mov r33 = b0
	.mmi
	mov r35 = r1
	.body
	.loc 1 52 0
	nop 0
	mov r36 = r32
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = valloc#
	.loc 1 53 0
	;;
	.loc 1 52 0
	.mmi
	nop 0
	mov r1 = r35
	.loc 1 53 0
	mov b0 = r33
	.mib
	nop 0
	mov ar.pfs = r34
	br.ret.sptk.many b0
.LFE19:
	.endp cf_valloc#
	.align 16
	.global cf_strdup#
	.proc cf_strdup#
cf_strdup:
[.LFB17:]
	.loc 1 43 0
	.prologue 12, 33
[.LVL13:]
	.mmi
	.save ar.pfs, r34
	alloc r34 = ar.pfs, 1, 3, 1, 0
	nop 0
	.save rp, r33
	mov r33 = b0
	.mmi
	mov r35 = r1
	.body
	.loc 1 44 0
	nop 0
	mov r36 = r32
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = strdup#
	.loc 1 45 0
	;;
	.loc 1 44 0
	.mmi
	nop 0
	mov r1 = r35
	.loc 1 45 0
	mov b0 = r33
	.mib
	nop 0
	mov ar.pfs = r34
	br.ret.sptk.many b0
.LFE17:
	.endp cf_strdup#
	.align 16
	.global cf_realloc#
	.proc cf_realloc#
cf_realloc:
[.LFB16:]
	.loc 1 39 0
	.prologue 12, 34
[.LVL14:]
	.mib
	.save ar.pfs, r35
	alloc r35 = ar.pfs, 2, 3, 2, 0
	.save rp, r34
	mov r34 = b0
	nop 0
	.mmi
	mov r36 = r1
	.body
	.loc 1 40 0
	mov r37 = r32
	mov r38 = r33
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = realloc#
	.loc 1 41 0
	;;
	.loc 1 40 0
	.mmi
	nop 0
	mov r1 = r36
	.loc 1 41 0
	mov b0 = r34
	.mib
	nop 0
	mov ar.pfs = r35
	br.ret.sptk.many b0
.LFE16:
	.endp cf_realloc#
	.align 16
	.global cf_calloc#
	.proc cf_calloc#
cf_calloc:
[.LFB15:]
	.loc 1 35 0
	.prologue 12, 34
[.LVL15:]
	.mib
	.save ar.pfs, r35
	alloc r35 = ar.pfs, 2, 3, 2, 0
	.save rp, r34
	mov r34 = b0
	nop 0
	.mmi
	mov r36 = r1
	.body
	.loc 1 36 0
	mov r37 = r32
	mov r38 = r33
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = calloc#
	.loc 1 37 0
	;;
	.loc 1 36 0
	.mmi
	nop 0
	mov r1 = r36
	.loc 1 37 0
	mov b0 = r34
	.mib
	nop 0
	mov ar.pfs = r35
	br.ret.sptk.many b0
.LFE15:
	.endp cf_calloc#
	.align 16
	.global strndup#
	.proc strndup#
strndup:
[.LFB2:]
	.file 2 "src/include/aerospike/strndup.h"
	.loc 2 8 0
	.prologue 12, 35
[.LVL16:]
	.mmi
	.save ar.pfs, r36
	alloc r36 = ar.pfs, 2, 4, 3, 0
	nop 0
	.save rp, r35
	mov r35 = b0
	.mmi
	mov r37 = r1
	.body
	.loc 2 10 0
	nop 0
	mov r38 = r32
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = strlen#
	;;
	.mmi
	mov r34 = r8
	cmp.leu p6, p7 = r8, r33
	mov r1 = r37
	;;
	.mii
	(p7) mov r34 = r33
[.LVL17:]
	.loc 2 15 0
	nop 0
	;;
	adds r38 = 1, r34
	.mmb
	nop 0
	nop 0
	br.call.sptk.many b0 = malloc#
	.loc 2 19 0
	;;
	.mmi
	add r14 = r8, r34
	.loc 2 15 0
	mov r1 = r37
	.loc 2 16 0
	cmp.ne p6, p7 = 0, r8
	.loc 2 20 0
	.mmb
	mov r39 = r32
	mov r40 = r34
	.loc 2 16 0
	(p7) br.cond.dpnt .L29
[.LVL18:]
	.loc 2 19 0
	;;
	.mmi
	nop 0
	st1 [r14] = r0
	.loc 2 20 0
	mov r38 = r8
[.LVL19:]
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = memcpy#
[.LVL20:]
	;;
	.mmi
	mov r1 = r37
	nop 0
	nop 0
[.LVL21:]
.L29:
	.loc 2 21 0
	.mii
	nop 0
	mov b0 = r35
	nop 0
	.mib
	nop 0
	mov ar.pfs = r36
	br.ret.sptk.many b0
.LFE2:
	.endp strndup#
	.align 16
	.global cf_strndup#
	.proc cf_strndup#
cf_strndup:
[.LFB18:]
	.loc 1 47 0
	.prologue 12, 34
[.LVL22:]
	.mib
	.save ar.pfs, r35
	alloc r35 = ar.pfs, 2, 3, 2, 0
	.save rp, r34
	mov r34 = b0
	nop 0
	.mmi
	mov r36 = r1
	.body
	.loc 1 48 0
	mov r37 = r32
	mov r38 = r33
	;;
	.mib
	nop 0
	nop 0
	br.call.sptk.many b0 = strndup#
	.loc 1 49 0
	;;
	.loc 1 48 0
	.mmi
	nop 0
	mov r1 = r36
	.loc 1 49 0
	mov b0 = r34
	.mib
	nop 0
	mov ar.pfs = r35
	br.ret.sptk.many b0
.LFE18:
	.endp cf_strndup#
	.align 16
	.global cf_rc_releaseandfree#
	.proc cf_rc_releaseandfree#
cf_rc_releaseandfree:
[.LFB27:]
	.loc 1 122 0
	.prologue
[.LVL23:]
	.body
[.LBB16:]
[.LBB17:]
	.loc 1 110 0
#APP
	mfence
#NO_APP
[.LBE17:]
[.LBE16:]
	.loc 1 124 0
	;;
	.mib
	nop 0
	addl r8 = -2, r0
	br.ret.sptk.many b0
.LFE27:
	.endp cf_rc_releaseandfree#
.Letext0:
	.section	.debug_loc,"",@progbits
.Ldebug_loc0:
.LLST1:
	data8.ua	.LVL0-.Ltext0
	data8.ua	.LVL1-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x20
	data8.ua	0x0
	data8.ua	0x0
.LLST5:
	data8.ua	.LVL5-.Ltext0
	data8.ua	.LVL6-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x24
	data8.ua	0x0
	data8.ua	0x0
.LLST8:
	data8.ua	.LVL9-.Ltext0
	data8.ua	.LVL10-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x24
	data8.ua	0x0
	data8.ua	0x0
.LLST15:
	data8.ua	.LVL16-.Ltext0
	data8.ua	.LVL18-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x20
	data8.ua	.LVL18-.Ltext0
	data8.ua	.LVL20-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x27
	data8.ua	.LVL20-.Ltext0
	data8.ua	.LFE2-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x20
	data8.ua	0x0
	data8.ua	0x0
.LLST16:
	data8.ua	.LVL19-.Ltext0
	data8.ua	.LVL20-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x26
	data8.ua	0x0
	data8.ua	0x0
.LLST17:
	data8.ua	.LVL17-.Ltext0
	data8.ua	.LVL18-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x22
	data8.ua	.LVL18-.Ltext0
	data8.ua	.LVL20-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x28
	data8.ua	.LVL20-.Ltext0
	data8.ua	.LFE2-.Ltext0
	data2.ua	0x2
	data1	0x90
	.uleb128 0x22
	data8.ua	0x0
	data8.ua	0x0
	.file 3 "/usr/include/sys/_inttypes.h"
	.file 4 "/usr/include/sys/_size_t.h"
	.file 5 "src/include/citrusleaf/cf_atomic.h"
	.section	.debug_info
	data4.ua	0x513
	data2.ua	0x2
	data4.ua	@secrel(.Ldebug_abbrev0)
	data1	0x8
	.uleb128 0x1
	data4.ua	@secrel(.LASF37)
	data1	0x1
	data4.ua	@secrel(.LASF38)
	data4.ua	@secrel(.LASF39)
	data8.ua	.Ltext0
	data8.ua	.Letext0
	data4.ua	@secrel(.Ldebug_line0)
	.uleb128 0x2
	data1	0x1
	data1	0x6
	data4.ua	@secrel(.LASF0)
	.uleb128 0x3
	data4.ua	@secrel(.LASF4)
	data1	0x3
	data1	0x53
	data4.ua	0x3f
	.uleb128 0x2
	data1	0x1
	data1	0x8
	data4.ua	@secrel(.LASF1)
	.uleb128 0x2
	data1	0x2
	data1	0x5
	data4.ua	@secrel(.LASF2)
	.uleb128 0x2
	data1	0x2
	data1	0x7
	data4.ua	@secrel(.LASF3)
	.uleb128 0x3
	data4.ua	@secrel(.LASF5)
	data1	0x3
	data1	0x56
	data4.ua	0x5f
	.uleb128 0x4
	data1	0x4
	data1	0x5
	stringz	"int"
	.uleb128 0x2
	data1	0x4
	data1	0x7
	data4.ua	@secrel(.LASF6)
	.uleb128 0x2
	data1	0x8
	data1	0x5
	data4.ua	@secrel(.LASF7)
	.uleb128 0x3
	data4.ua	@secrel(.LASF8)
	data1	0x3
	data1	0x60
	data4.ua	0x7f
	.uleb128 0x2
	data1	0x8
	data1	0x7
	data4.ua	@secrel(.LASF9)
	.uleb128 0x2
	data1	0x1
	data1	0x6
	data4.ua	@secrel(.LASF10)
	.uleb128 0x3
	data4.ua	@secrel(.LASF11)
	data1	0x4
	data1	0x19
	data4.ua	0x7f
	.uleb128 0x2
	data1	0x8
	data1	0x5
	data4.ua	@secrel(.LASF12)
	.uleb128 0x5
	data1	0x8
	data1	0x7
	.uleb128 0x6
	data1	0x8
	.uleb128 0x7
	data1	0x8
	data4.ua	0x86
	.uleb128 0x2
	data1	0x10
	data1	0x4
	data4.ua	@secrel(.LASF13)
	.uleb128 0x2
	data1	0x8
	data1	0x4
	data4.ua	@secrel(.LASF14)
	.uleb128 0x3
	data4.ua	@secrel(.LASF15)
	data1	0x5
	data1	0x49
	data4.ua	0x74
	.uleb128 0x8
	data4.ua	0x66
	.uleb128 0x9
	data4.ua	@secrel(.LASF19)
	data1	0x5
	data2.ua	0x148
	data1	0x1
	data4.ua	0x54
	data1	0x3
	data4.ua	0xf9
	.uleb128 0xa
	stringz	"a"
	data1	0x5
	data2.ua	0x148
	data4.ua	0xf9
	.uleb128 0xa
	stringz	"b"
	data1	0x5
	data2.ua	0x148
	data4.ua	0x54
	.uleb128 0xb
	stringz	"i"
	data1	0x5
	data2.ua	0x149
	data4.ua	0x54
	data1	0x0
	.uleb128 0x7
	data1	0x8
	data4.ua	0xc3
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF16)
	data1	0x1
	data1	0x3d
	data1	0x1
	data4.ua	0xb8
	data8.ua	.LFB21
	data8.ua	.LFE21
	data1	0x1
	data1	0x5c
	data4.ua	0x13f
	.uleb128 0xd
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x3d
	data4.ua	0xa2
	data4.ua	@secrel(.LLST1)
	.uleb128 0xe
	stringz	"rc"
	data1	0x1
	data1	0x3e
	data4.ua	0xf9
	data1	0x2
	data1	0x90
	.uleb128 0x20
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF17)
	data1	0x1
	data1	0x45
	data1	0x1
	data4.ua	0x5f
	data8.ua	.LFB22
	data8.ua	.LFE22
	data1	0x1
	data1	0x5c
	data4.ua	0x184
	.uleb128 0xf
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x45
	data4.ua	0xa2
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x10
	stringz	"rc"
	data1	0x1
	data1	0x46
	data4.ua	0xf9
	.uleb128 0x10
	stringz	"i"
	data1	0x1
	data1	0x47
	data4.ua	0x5f
	data1	0x0
	.uleb128 0x11
	data4.ua	@secrel(.LASF20)
	data1	0x1
	data1	0x67
	data1	0x1
	data4.ua	0xb8
	data1	0x3
	data4.ua	0x1c8
	.uleb128 0x12
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x67
	data4.ua	0xa2
	.uleb128 0x12
	data4.ua	@secrel(.LASF21)
	data1	0x1
	data1	0x67
	data4.ua	0x1c8
	.uleb128 0x10
	stringz	"c"
	data1	0x1
	data1	0x68
	data4.ua	0x74
	.uleb128 0x10
	stringz	"rc"
	data1	0x1
	data1	0x69
	data4.ua	0xf9
	.uleb128 0x13
	.uleb128 0x13
	.uleb128 0x14
	data4.ua	0xee
	data1	0x0
	data1	0x0
	data1	0x0
	.uleb128 0x2
	data1	0x1
	data1	0x2
	data4.ua	@secrel(.LASF22)
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF23)
	data1	0x1
	data1	0x76
	data1	0x1
	data4.ua	0x5f
	data8.ua	.LFB26
	data8.ua	.LFE26
	data1	0x1
	data1	0x5c
	data4.ua	0x23f
	.uleb128 0xf
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x76
	data4.ua	0xa2
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x15
	data4.ua	0x184
	data8.ua	.LBB10
	data8.ua	.LBE10
	data1	0x1
	data1	0x77
	.uleb128 0x16
	data4.ua	0x1a0
	.uleb128 0x16
	data4.ua	0x195
	.uleb128 0x17
	data8.ua	.LBB11
	data8.ua	.LBE11
	.uleb128 0x14
	data4.ua	0x1ab
	.uleb128 0x14
	data4.ua	0x1b4
	data1	0x0
	data1	0x0
	data1	0x0
	.uleb128 0x18
	data1	0x1
	data4.ua	@secrel(.LASF24)
	data1	0x1
	data1	0x60
	data1	0x1
	data8.ua	.LFB24
	data8.ua	.LFE24
	data1	0x1
	data1	0x5c
	data4.ua	0x27b
	.uleb128 0xf
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x60
	data4.ua	0xa2
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x19
	stringz	"rc"
	data1	0x1
	data1	0x61
	data4.ua	0xf9
	data4.ua	@secrel(.LLST5)
	data1	0x0
	.uleb128 0x18
	data1	0x1
	data4.ua	@secrel(.LASF25)
	data1	0x1
	data1	0x37
	data1	0x1
	data8.ua	.LFB20
	data8.ua	.LFE20
	data1	0x1
	data1	0x5c
	data4.ua	0x2a7
	.uleb128 0x1a
	stringz	"p"
	data1	0x1
	data1	0x37
	data4.ua	0xa2
	data1	0x2
	data1	0x90
	.uleb128 0x20
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF26)
	data1	0x1
	data1	0x52
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB23
	data8.ua	.LFE23
	data1	0x1
	data1	0x5c
	data4.ua	0x2f2
	.uleb128 0x1a
	stringz	"sz"
	data1	0x1
	data1	0x51
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x19
	stringz	"asz"
	data1	0x1
	data1	0x53
	data4.ua	0x8d
	data4.ua	@secrel(.LLST8)
	.uleb128 0x1b
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x54
	data4.ua	0x2f2
	data1	0x0
	.uleb128 0x7
	data1	0x8
	data4.ua	0x34
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF27)
	data1	0x1
	data1	0x1f
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB14
	data8.ua	.LFE14
	data1	0x1
	data1	0x5c
	data4.ua	0x329
	.uleb128 0x1a
	stringz	"sz"
	data1	0x1
	data1	0x1f
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x20
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF28)
	data1	0x1
	data1	0x33
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB19
	data8.ua	.LFE19
	data1	0x1
	data1	0x5c
	data4.ua	0x35a
	.uleb128 0x1a
	stringz	"sz"
	data1	0x1
	data1	0x33
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x20
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF29)
	data1	0x1
	data1	0x2b
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB17
	data8.ua	.LFE17
	data1	0x1
	data1	0x5c
	data4.ua	0x38a
	.uleb128 0x1a
	stringz	"s"
	data1	0x1
	data1	0x2b
	data4.ua	0x38a
	data1	0x2
	data1	0x90
	.uleb128 0x20
	data1	0x0
	.uleb128 0x7
	data1	0x8
	data4.ua	0x390
	.uleb128 0x1c
	data4.ua	0x86
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF30)
	data1	0x1
	data1	0x27
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB16
	data8.ua	.LFE16
	data1	0x1
	data1	0x5c
	data4.ua	0x3d4
	.uleb128 0x1a
	stringz	"ptr"
	data1	0x1
	data1	0x27
	data4.ua	0xa2
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x1a
	stringz	"sz"
	data1	0x1
	data1	0x27
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x21
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF31)
	data1	0x1
	data1	0x23
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB15
	data8.ua	.LFE15
	data1	0x1
	data1	0x5c
	data4.ua	0x413
	.uleb128 0xf
	data4.ua	@secrel(.LASF32)
	data1	0x1
	data1	0x23
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x1a
	stringz	"sz"
	data1	0x1
	data1	0x23
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x21
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF33)
	data1	0x2
	data1	0x8
	data1	0x1
	data4.ua	0xa4
	data8.ua	.LFB2
	data8.ua	.LFE2
	data1	0x1
	data1	0x5c
	data4.ua	0x46e
	.uleb128 0x1d
	stringz	"s"
	data1	0x2
	data1	0x7
	data4.ua	0x38a
	data4.ua	@secrel(.LLST15)
	.uleb128 0x1a
	stringz	"n"
	data1	0x2
	data1	0x7
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x21
	.uleb128 0x1e
	data4.ua	@secrel(.LASF34)
	data1	0x2
	data1	0x9
	data4.ua	0xa4
	data4.ua	@secrel(.LLST16)
	.uleb128 0x19
	stringz	"len"
	data1	0x2
	data1	0xa
	data4.ua	0x8d
	data4.ua	@secrel(.LLST17)
	data1	0x0
	.uleb128 0xc
	data1	0x1
	data4.ua	@secrel(.LASF35)
	data1	0x1
	data1	0x2f
	data1	0x1
	data4.ua	0xa2
	data8.ua	.LFB18
	data8.ua	.LFE18
	data1	0x1
	data1	0x5c
	data4.ua	0x4aa
	.uleb128 0x1a
	stringz	"s"
	data1	0x1
	data1	0x2f
	data4.ua	0x38a
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x1a
	stringz	"n"
	data1	0x1
	data1	0x2f
	data4.ua	0x8d
	data1	0x2
	data1	0x90
	.uleb128 0x21
	data1	0x0
	.uleb128 0x1f
	data1	0x1
	data4.ua	@secrel(.LASF36)
	data1	0x1
	data1	0x7a
	data1	0x1
	data4.ua	0x5f
	data8.ua	.LFB27
	data8.ua	.LFE27
	data1	0x1
	data1	0x5c
	.uleb128 0xf
	data4.ua	@secrel(.LASF18)
	data1	0x1
	data1	0x7a
	data4.ua	0xa2
	data1	0x2
	data1	0x90
	.uleb128 0x20
	.uleb128 0x15
	data4.ua	0x184
	data8.ua	.LBB16
	data8.ua	.LBE16
	data1	0x1
	data1	0x7b
	.uleb128 0x16
	data4.ua	0x1a0
	.uleb128 0x16
	data4.ua	0x195
	.uleb128 0x17
	data8.ua	.LBB17
	data8.ua	.LBE17
	.uleb128 0x14
	data4.ua	0x1ab
	.uleb128 0x14
	data4.ua	0x1b4
	data1	0x0
	data1	0x0
	data1	0x0
	data1	0x0
	.section	.debug_abbrev
	.uleb128 0x1
	.uleb128 0x11
	data1	0x1
	.uleb128 0x25
	.uleb128 0xe
	.uleb128 0x13
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x1b
	.uleb128 0xe
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x1
	.uleb128 0x10
	.uleb128 0x6
	data1	0x0
	data1	0x0
	.uleb128 0x2
	.uleb128 0x24
	data1	0x0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	data1	0x0
	data1	0x0
	.uleb128 0x3
	.uleb128 0x16
	data1	0x0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x4
	.uleb128 0x24
	data1	0x0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0x8
	data1	0x0
	data1	0x0
	.uleb128 0x5
	.uleb128 0x24
	data1	0x0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	data1	0x0
	data1	0x0
	.uleb128 0x6
	.uleb128 0xf
	data1	0x0
	.uleb128 0xb
	.uleb128 0xb
	data1	0x0
	data1	0x0
	.uleb128 0x7
	.uleb128 0xf
	data1	0x0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x8
	.uleb128 0x35
	data1	0x0
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x9
	.uleb128 0x2e
	data1	0x1
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0x5
	.uleb128 0x27
	.uleb128 0xc
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x20
	.uleb128 0xb
	.uleb128 0x1
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0xa
	.uleb128 0x5
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0x5
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0xb
	.uleb128 0x34
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0x5
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0xc
	.uleb128 0x2e
	data1	0x1
	.uleb128 0x3f
	.uleb128 0xc
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0xc
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x1
	.uleb128 0x40
	.uleb128 0xa
	.uleb128 0x1
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0xd
	.uleb128 0x5
	data1	0x0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x6
	data1	0x0
	data1	0x0
	.uleb128 0xe
	.uleb128 0x34
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0xa
	data1	0x0
	data1	0x0
	.uleb128 0xf
	.uleb128 0x5
	data1	0x0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0xa
	data1	0x0
	data1	0x0
	.uleb128 0x10
	.uleb128 0x34
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x11
	.uleb128 0x2e
	data1	0x1
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0xc
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x20
	.uleb128 0xb
	.uleb128 0x1
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x12
	.uleb128 0x5
	data1	0x0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x13
	.uleb128 0xb
	data1	0x1
	data1	0x0
	data1	0x0
	.uleb128 0x14
	.uleb128 0x34
	data1	0x0
	.uleb128 0x31
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x15
	.uleb128 0x1d
	data1	0x1
	.uleb128 0x31
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x1
	.uleb128 0x58
	.uleb128 0xb
	.uleb128 0x59
	.uleb128 0xb
	data1	0x0
	data1	0x0
	.uleb128 0x16
	.uleb128 0x5
	data1	0x0
	.uleb128 0x31
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x17
	.uleb128 0xb
	data1	0x1
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x1
	data1	0x0
	data1	0x0
	.uleb128 0x18
	.uleb128 0x2e
	data1	0x1
	.uleb128 0x3f
	.uleb128 0xc
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0xc
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x1
	.uleb128 0x40
	.uleb128 0xa
	.uleb128 0x1
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x19
	.uleb128 0x34
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x6
	data1	0x0
	data1	0x0
	.uleb128 0x1a
	.uleb128 0x5
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0xa
	data1	0x0
	data1	0x0
	.uleb128 0x1b
	.uleb128 0x34
	data1	0x0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x1c
	.uleb128 0x26
	data1	0x0
	.uleb128 0x49
	.uleb128 0x13
	data1	0x0
	data1	0x0
	.uleb128 0x1d
	.uleb128 0x5
	data1	0x0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x6
	data1	0x0
	data1	0x0
	.uleb128 0x1e
	.uleb128 0x34
	data1	0x0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x6
	data1	0x0
	data1	0x0
	.uleb128 0x1f
	.uleb128 0x2e
	data1	0x1
	.uleb128 0x3f
	.uleb128 0xc
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0xc
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x1
	.uleb128 0x40
	.uleb128 0xa
	data1	0x0
	data1	0x0
	data1	0x0
	.section	.debug_pubnames,"",@progbits
	data4.ua	0xe8
	data2.ua	0x2
	data4.ua	@secrel(.Ldebug_info0)
	data4.ua	0x517
	data4.ua	0xff
	stringz	"cf_rc_count"
	data4.ua	0x13f
	stringz	"cf_rc_reserve"
	data4.ua	0x1cf
	stringz	"cf_rc_release"
	data4.ua	0x23f
	stringz	"cf_rc_free"
	data4.ua	0x27b
	stringz	"cf_free"
	data4.ua	0x2a7
	stringz	"cf_rc_alloc"
	data4.ua	0x2f8
	stringz	"cf_malloc"
	data4.ua	0x329
	stringz	"cf_valloc"
	data4.ua	0x35a
	stringz	"cf_strdup"
	data4.ua	0x395
	stringz	"cf_realloc"
	data4.ua	0x3d4
	stringz	"cf_calloc"
	data4.ua	0x413
	stringz	"strndup"
	data4.ua	0x46e
	stringz	"cf_strndup"
	data4.ua	0x4aa
	stringz	"cf_rc_releaseandfree"
	data4.ua	0x0
	.section	.debug_aranges,"",@progbits
	data4.ua	0x2c
	data2.ua	0x2
	data4.ua	@secrel(.Ldebug_info0)
	data1	0x8
	data1	0x0
	data2.ua	0x0
	data2.ua	0x0
	data8.ua	.Ltext0
	data8.ua	.Letext0-.Ltext0
	data8.ua	0x0
	data8.ua	0x0
	.section	.debug_str,"MS",@progbits,1
.LASF27:
	stringz	"cf_malloc"
.LASF23:
	stringz	"cf_rc_release"
.LASF11:
	stringz	"size_t"
.LASF24:
	stringz	"cf_rc_free"
.LASF19:
	stringz	"cf_atomic32_add"
.LASF38:
	stringz	"src/main/citrusleaf/cf_alloc.c"
.LASF25:
	stringz	"cf_free"
.LASF3:
	stringz	"short unsigned int"
.LASF32:
	stringz	"nmemb"
.LASF8:
	stringz	"uint64_t"
.LASF17:
	stringz	"cf_rc_reserve"
.LASF15:
	stringz	"cf_atomic_int_t"
.LASF29:
	stringz	"cf_strdup"
.LASF33:
	stringz	"strndup"
.LASF9:
	stringz	"long unsigned int"
.LASF18:
	stringz	"addr"
.LASF35:
	stringz	"cf_strndup"
.LASF21:
	stringz	"autofree"
.LASF14:
	stringz	"double"
.LASF20:
	stringz	"cf_rc_release_x"
.LASF36:
	stringz	"cf_rc_releaseandfree"
.LASF1:
	stringz	"unsigned char"
.LASF6:
	stringz	"unsigned int"
.LASF30:
	stringz	"cf_realloc"
.LASF10:
	stringz	"char"
.LASF4:
	stringz	"uint8_t"
.LASF34:
	stringz	"result"
.LASF5:
	stringz	"int32_t"
.LASF12:
	stringz	"long long int"
.LASF37:
	stringz	"GNU C 4.2.3"
.LASF2:
	stringz	"short int"
.LASF16:
	stringz	"cf_rc_count"
.LASF28:
	stringz	"cf_valloc"
.LASF13:
	stringz	"__fpreg"
.LASF31:
	stringz	"cf_calloc"
.LASF7:
	stringz	"long int"
.LASF39:
	stringz	"/manoj/aerospike-client-c/modules/common"
.LASF0:
	stringz	"signed char"
.LASF22:
	stringz	"_Bool"
.LASF26:
	stringz	"cf_rc_alloc"
	.ident	"GCC: (GNU) 4.2.3"
	.global memcpy#
	.type	memcpy#,@function
	.global strlen#
	.type	strlen#,@function
	.global memcpy#
	.type	memcpy#,@function
	.global calloc#
	.type	calloc#,@function
	.global realloc#
	.type	realloc#,@function
	.global strdup#
	.type	strdup#,@function
	.global valloc#
	.type	valloc#,@function
	.global malloc#
	.type	malloc#,@function
	.global free#
	.type	free#,@function
