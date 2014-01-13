import strutils, json

type
    TMongrelMsg* = tuple[uuid: string, id: string, path: string,
                        headers: PJsonNode, body: string]

proc parse_netstring(ns: string, split_idx: var int): string =
    var len_s: string
    for s in ns.split(':'):
        len_s = s
        break
    let header_len = parseInt(len_s)
    split_idx = len_s.len + 1 + header_len

    assert(ns[split_idx] == ',')

    return ns[len_s.len + 1 .. split_idx - 1]

proc parse*(msg: string): TMongrelMsg =
    #let msg_splitted = msg.split(' ')
    #result.uuid = msg_splitted[0]
    #result.id = msg_splitted[1]
    #result.path = msg_splitted[2]
    var i = 0
    for str in msg.split(' '):
        case i
        of 0: result.uuid = str
        of 1: result.id = str
        of 2: result.path = str
        else: break
        inc(i)

    var split_idx = 0
    ## rest != msg_splitted[3] because the rest can contain spaces
    let rest = msg[result.uuid.len + result.id.len + result.path.len + 3 .. msg.len-1]
    let head = parse_netstring(rest, split_idx)
    result.headers = parseJson(head)

    let body_ns = rest[split_idx + 1 .. rest.len]
    result.body = parse_netstring(body_ns, split_idx)

#proc `$`(s: seq[string]): string =
#    result = "["
#    for item in s.items:
#        result.add($item & ", ")
#    result.add "]"

when isMainModule:
    let msg = "18510ea21k 123 /index.html 20:{\"Content-Length\":5},5:Hello,"
    var msg_parsed = parse(msg)
    echo msg_parsed
    echo ""
    echo ""

    let msg2 = "0138a43-micro-nimrod 3 / 426:{\"PATH\":\"/\",\"x-forwarded-for\":\"127.0.0.1\",\"accept-language\":\"en-US,en;q=0.5\",\"connection\":\"keep-alive\",\"accept-encoding\":\"gzip, deflate\",\"accept\":\"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\",\"user-agent\":\"Mozilla/5.0 (X11; Linux x86_64; rv:26.0) Gecko/20100101 Firefox/26.0\",\"host\":\"localhost:6767\",\"METHOD\":\"GET\",\"VERSION\":\"HTTP/1.1\",\"URI\":\"/\",\"PATTERN\":\"/\",\"URL_SCHEME\":\"http\",\"REMOTE_ADDR\":\"127.0.0.1\"},0:,"
    var msg2_parsed = parse(msg2)
    echo msg2_parsed
