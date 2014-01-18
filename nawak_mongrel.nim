import os, tables, strutils, strtabs, json
import lib/zmq4, lib/uuid
import private/optim_strange_loop,
       private/netstrings,
       private/nawak_mg,
       private/jesterutils
export nawak_mg


const HTTP_FORMAT = "HTTP/1.1 $1 $2\r\n$3\r\n\r\n$4"

var from_mongrel, to_mongrel: TConnection

proc http_response(body:string, code: int, status: string,
                   headers: var PStringTable): string =
    ## formats the http part of the response payload to send on the zeromq socket
    headers["Content-Length"] = $len(body)
    if not headers.hasKey("Content-Type"):
        headers["Content-Type"] = "text/html"

    var headers_strs: seq[string] = @[]
    for k, v in headers.pairs:
        #headers_strs.add("$1: $2" % [k, $v])
        headers_strs.add(optFormat("$1: $2", [k, $v]))

    return HTTP_FORMAT % [$code, status, headers_strs.join("\r\n"), body]
    #return optFormat("HTTP/1.1 $1 $2\r\n$3\r\n\r\n$4", [$code, status, headers_strs.join("\r\n"), body])

proc send*(uuid, conn_id, msg: string) =
    let payload = "$1 $2:$3, $4" % [uuid, $conn_id.len, conn_id, msg]
    #let payload = optFormat("$1 $2:$3, $4", [uuid, $conn_id.len, conn_id, msg])
    zmq4.send(to_mongrel, payload)

#proc deliver(uuid: string, idents: openArray[string], data: string) =
#    send(uuid, idents.join(" "), data)

proc deliver(uuid, conn_id, data: string) =
    send(uuid, conn_id, data)


proc prepare_request_obj(req: TMongrelMsg): TRequest =
    result.path = req.headers["PATH"].str
    result.query = {:}.newStringTable
    if req.headers.hasKey("QUERY"):
        parseUrlQuery(req.headers["QUERY"].str, result.query)

template try_match(): stmt {.immediate.} =
    try:
        let (matched, res) = it.match(request.path, request)
        if matched:
            has_matched = matched
            resp = res
            break
    except:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
            stacktrace = getStackTrace(e)
        has_matched = true
        resp = nawak.custom_pages[500](msg & "\L" & stacktrace)
        break

proc run*(from_addr="tcp://localhost:9999", to_addr="tcp://localhost:9998") =
    var my_uuid: Tuuid
    uuid_generate_random(my_uuid)
    let sender_uuid = my_uuid.to_hex
    echo "I am: ", sender_uuid

    from_mongrel = connect(from_addr, PULL)
    to_mongrel = connect(to_addr, PUB)
    discard setsockopt(to_mongrel.s, ZMQ_IDENTITY, cstring(sender_uuid),
                       uint(sender_uuid.len))


    while True:
        #echo ""
        var msg = receive(from_mongrel)

        var req = parse(msg)
        #echo req.headers["PATH"].str
        #echo pretty(req.headers)

        var resp: TResponse
        var has_matched = false

        case req.headers["METHOD"].str
        of "JSON":
            if req.body == "{\"type\":\"disconnect\"}":
                #echo "DISCONNECT: a client didn't wait for the answer\n\tThe server did some work for nothing! Intolerable!"
                continue

        of "GET":
            let request = prepare_request_obj(req)
            for it in nawak.gets:
                try_match()

        of "POST":
            let request = prepare_request_obj(req)
            for it in nawak.posts:
                try_match()

        else:
            echo "METHOD NOT AVAILABLE"
            send(req.uuid, req.id, "")  # disconnect

        if not has_matched:
            resp = nawak.custom_pages[404]("""
            <i>&quot;And they took the road less traveled.
            Unfortunately, there was nothing there.&quot;</i>
            """)

        if resp.headers == nil:
            resp.headers = {:}.newStringTable
        if resp.body == nil or resp.code == 0:
            resp = nawak.custom_pages[500]("""
            The programmer forgot to add a status code or to return some data
            in the body of the response.""")

        deliver(req.uuid, req.id, http_response(
            resp.body, resp.code, "OK", resp.headers
        ))

proc run*(from_addr, to_addr: int) =
    run("tcp://localhost:" & $from_addr, "tcp://localhost:" & $to_addr)
