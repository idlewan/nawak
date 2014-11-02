# Copyright (C) 2012 Dominik Picheta
# with modifications by Erwan Ameil
# MIT License
import parseutils, strtabs
from cgi import decodeUrl

proc parseUrlQuery*(query: string, query_params: var StringTableRef) =
    query_params = {:}.newStringTable
    try:
        var i = 0
        let j = query.find('?')
        if j > 0:
            i = j + 1
        while i < query.len()-1:
            var key = ""
            var val = ""
            i += query.parseUntil(key, '=', i)
            if query[i] != '=':
                raise newException(ValueError, "Expected '=' at " & $i)
            inc(i) # Skip =
            i += query.parseUntil(val, '&', i)
            inc(i) # Skip &
            query_params[decodeUrl(key)] = decodeUrl(val)
    except ValueError: discard


when isMainModule:
  var r = {:}.newStringTable
  parseUrlQuery("FirstName=Mickey", r)
  echo r
  r = {:}.newStringTable
  parseUrlQuery("asdf?FirstName=Mickey", r)
  echo r
  r = {:}.newStringTable
  parseUrlQuery("/my/path?FirstName=Mickey", r)
  echo r
  r = {:}.newStringTable
  parseUrlQuery("/my/path?FirstName=", r)
  echo r
  r = {:}.newStringTable
  parseUrlQuery("/my/path?=", r)
  echo r
