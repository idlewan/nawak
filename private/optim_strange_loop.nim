# From Araq's talk: 
# http://nimrod-lang.org/talk01/slides.html
# http://nimrod-lang.org/talk01/corrections.html

import macros

proc invalidFormatString() {.noinline.} =
    raise newException(EInvalidValue, "invalid format string")

template optAdd1*{x = y; add(x, z)}(x, y, z: string) =
  x = y & z

template optAdd2*{add(x, y); add(x, z)}(x, y, z: string) =
  #x.add(y & z)
  add(x, y & z)

macro optFormat*{`%`(f, a)}(f: string{lit}, a: openArray[string]): expr =
  result = newNimNode(nnkBracket)
  let f = f.strVal
  var i = 0
  while i < f.len:
    if f[i] == '$':
      case f[i+1]
      of '1'..'9':
        var j = 0
        i += 1
        while f[i] in {'0'..'9'}:
          j = j * 10 + ord(f[i]) - ord('0'); i += 1
        result.add(a[j-1])
      else:
        invalidFormatString()
    else:
      result.add(newLit(f[i])); i += 1
  
  result = nestList(!"&", result)

when isMainModule:
    import strutils, times
    type str {.shallow.} = string
    var bla: str = "somebla"
    var t0 = cpuTime()
    for i in 0..1_000_000:
        #var s: str = `%`("$1 $2:$3 $4,", ["stuff", "yeah", bla, $12345])
        var s: str = optFormat("$1 $2:$3 $4,", ["stuff", "yeah", bla, $12345])
    echo "CPU time [s] ", cpuTime() - t0
