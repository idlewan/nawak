import os, strutils, strtabs, json
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

    #return HTTP_FORMAT % [$code, status, headers_strs.join("\r\n"), body]
    return optFormat("HTTP/1.1 $1 $2\r\n$3\r\n\r\n$4", [$code, status, headers_strs.join("\r\n"), body])

proc send*(uuid, conn_id, msg: string) =
    #let payload = "$1 $2:$3, $4" % [uuid, $conn_id.len, conn_id, msg]
    let payload = optFormat("$1 $2:$3, $4", [uuid, $conn_id.len, conn_id, msg])
    zmq4.send(to_mongrel, payload)

#proc deliver(uuid: string, idents: openArray[string], data: string) =
#    send(uuid, idents.join(" "), data)

proc deliver(uuid, conn_id, data: string) =
    send(uuid, conn_id, data)

proc deliver_shortcut(uuid, conn_id, headers, body, status_msg: string,
                   status_code: int) =
    let payload = optFormat("$1 $2:$3, HTTP/1.1 $4 $5\r\n$6\r\n\r\n$7",
                            [uuid, $conn_id.len, conn_id,
                             $status_code, status_msg, headers, body])
    zmq4.send(to_mongrel, payload)

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
            var request: TRequest
            request.path = req.headers["PATH"].str
            request.query = {:}.newStringTable
            if req.headers.hasKey("QUERY"):
                parseUrlQuery(req.headers["QUERY"].str, request.query)

            for g in nawak.gets:
                let (matched, res) = g.match(request.path, request)
                #echo "\t", g.path, " :  ", matched
                if matched:
                    has_matched = matched
                    resp = res
                    break

        of "POST":
            var request: TRequest
            request.path = req.headers["PATH"].str
            request.query = {:}.newStringTable
            if req.headers.hasKey("QUERY"):
                parseUrlQuery(req.headers["QUERY"].str, request.query)
            #let request: TRequest = (req.headers["PATH"].str, "sdf")
            for p in nawak.posts:
                let (matched, res) = p.match(request.path, request)
                if matched:
                    has_matched = matched
                    resp = res
                    break
        else:
            echo "METHOD NOT AVAILABLE"
            send(req.uuid, req.id, "")  # disconnect

        if not has_matched:
            var headers = newStringTable({:})
            deliver(req.uuid, req.id,
                    http_response("I deny any responsibility in this 404.",
                                  404, "Not Found", headers))
        else:
            if resp.headers == nil:
                resp.headers = {:}.newStringTable
            if resp.body == nil or resp.code == 0:
                resp.body = "Error 500"
                resp.code = 500

            deliver(req.uuid, req.id, http_response(
                resp.body, resp.code, "OK", resp.headers
            ))

            #deliver(req.uuid, req.id, optFormat("HTTP/1.1 $1 $2\r\n$3\r\n\r\n$4",
            #    [$resp.code, "OK",
            #    "Content-Type: application/json\r\nContent-Length: " & $(resp.body.len),
            #    resp.body]))

            #deliver_shortcut(req.uuid, req.id,
            #    "Content-Type: application/json\r\nContent-Length: " & $resp.body.len,
            #    resp.body, "OK", resp.code)


when isMainModule:
    #var headers = newStringTable({"Content-Type": "text/plain"})
    #echo http_response("Hello", 200, "OK", headers)
    run()
