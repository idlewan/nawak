import strutils, unicode
import private/optim_strange_loop

# from the standard lib json
proc escapeJson(s: string): string = 
  ## Converts a string `s` to its JSON representation.
  result = newStringOfCap(s.len + s.len shr 3)
  result.add("\"")
  for x in runes(s):
    var r = int(x)
    if r >= 32 and r <= 127:
      var c = chr(r)
      case c
      of '"': result.add("\\\"")
      of '\\': result.add("\\\\")
      else: result.add(c)
    else:
      result.add("\\u")
      result.add(toHex(r, 4))
  result.add("\"")


proc jdump*(x: string): string = escapeJson(x)
proc jdump*(x: int): string = $x
proc jdump*(x: float): string = $x
#proc jdump*[T](x: seq[T] | openarray[T]): string =
proc jdump*[T](x: seq[T]): string =
    result = "["
    for i in 0.. x.len - 2:
        result.add jdump(x[i])
        result.add ","
    result.add jdump(x[x.len - 1])
    result.add "]"

proc jdump*[T: tuple](x: T): string =
    result = "{"
    for name, value in fieldPairs(x):
        #result.add("\"$1\":$2," % [name, jdump(value)])
        result.add(optFormat("\"$1\":$2,", [name, jdump(value)]))
    result[result.len - 1] = '}'

when isMainModule:
    type TTest = tuple[id: string, randomNumber: string]
    let t, t2: TTest = ("sdfg328asd", "10472")
    echo jdump(t)
    echo jdump(@[1, 2, 3])
    let t_seq = @[t, t2]
    echo jdump(t_seq)
