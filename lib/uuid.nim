#
#  Public include file for the UUID library
# 
#  Copyright (C) 1996, 1997, 1998 Theodore Ts'o.
# 
#  %Begin-Header%
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#  1. Redistributions of source code must retain the above copyright
#     notice, and the entire permission notice in its entirety,
#     including the disclaimer of warranties.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  3. The name of the author may not be used to endorse or promote
#     products derived from this software without specific prior
#     written permission.
# 
#  THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ALL OF
#  WHICH ARE HEREBY DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE
#  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
#  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
#  OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
#  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
#  USE OF THIS SOFTWARE, EVEN IF NOT ADVISED OF THE POSSIBILITY OF SUCH
#  DAMAGE.
#  %End-Header%
# 

import times
type Ttimeval {.importc: "struct timeval", header: "<sys/select.h>",
                final, pure.} = object

{.deadCodeElim: on.}
const libuuid = "libuuid.so"

type 
  Tuuid* = array[0..16 - 1, cuchar]

# UUID Variant definitions 

const 
  UUID_VARIANT_NCS* = 0
  UUID_VARIANT_DCE* = 1
  UUID_VARIANT_MICROSOFT* = 2
  UUID_VARIANT_OTHER* = 3

# UUID Type definitions 

const 
  UUID_TYPE_DCE_TIME* = 1
  UUID_TYPE_DCE_RANDOM* = 4

# clear.c 

proc uuid_clear*(uu: Tuuid) {.cdecl, importc: "uuid_clear", dynlib: libuuid.}
# compare.c 

proc uuid_compare*(uu1: Tuuid; uu2: Tuuid): cint {.cdecl, 
    importc: "uuid_compare", dynlib: libuuid.}
# copy.c 

proc uuid_copy*(dst: Tuuid; src: Tuuid) {.cdecl, importc: "uuid_copy", 
    dynlib: libuuid.}
# gen_uuid.c 

proc uuid_generate*(uuid_out: Tuuid) {.cdecl, importc: "uuid_generate", 
                                   dynlib: libuuid.}
proc uuid_generate_random*(uuid_out: Tuuid) {.cdecl, 
    importc: "uuid_generate_random", dynlib: libuuid.}
proc uuid_generate_time*(uuid_out: Tuuid) {.cdecl, importc: "uuid_generate_time", 
                                        dynlib: libuuid.}
proc uuid_generate_time_safe*(uuid_out: Tuuid): cint {.cdecl, 
    importc: "uuid_generate_time_safe", dynlib: libuuid.}
# isnull.c 

proc uuid_is_null*(uu: Tuuid): cint {.cdecl, importc: "uuid_is_null", 
                                       dynlib: libuuid.}
# parse.c 

proc uuid_parse*(in_cstr: cstring; uu: Tuuid): cint {.cdecl, importc: "uuid_parse", 
    dynlib: libuuid.}
# unparse.c 

proc uuid_unparse*(uu: Tuuid; uuid_out: cstring) {.cdecl, importc: "uuid_unparse", 
    dynlib: libuuid.}
proc uuid_unparse_lower*(uu: Tuuid; uuid_out: cstring) {.cdecl, 
    importc: "uuid_unparse_lower", dynlib: libuuid.}
proc uuid_unparse_upper*(uu: Tuuid; uuid_out: cstring) {.cdecl, 
    importc: "uuid_unparse_upper", dynlib: libuuid.}
# uuid_time.c 

proc uuid_time*(uu: Tuuid; ret_tv: ptr Ttimeval): TTime {.cdecl, 
    importc: "uuid_time", dynlib: libuuid.}
proc uuid_type*(uu: Tuuid): cint {.cdecl, importc: "uuid_type", dynlib: libuuid.}
proc uuid_variant*(uu: Tuuid): cint {.cdecl, importc: "uuid_variant", 
                                       dynlib: libuuid.}

# helpers for nimrod
const int_to_hexchar_mappings = ['0', '1', '2', '3', '4', '5', '6', '7',
                                 '8', '9', 'a', 'b', 'c', 'd', 'e', 'f']
import unsigned, strutils
proc to_hex*(uu: Tuuid): string =
    var hex = ""
    for c in uu:
        hex.add strutils.toHex(int(c), 2)
        #var first = int(uint(c) shr 4)
        #var second = int(uint(c) and 0x0f)
        #hex.add int_to_hexchar_mappings[first]
        #hex.add int_to_hexchar_mappings[second]
    #return "$1-$2-$3-$4-$5" % [hex[0..7], hex[8..11], hex[12..15],
    #                           hex[16..19], hex[20..31]]
    return toLower("$1-$2-$3-$4-$5" % [hex[0..7], hex[8..11], hex[12..15],
                               hex[16..19], hex[20..31]] )
