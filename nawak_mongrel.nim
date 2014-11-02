import os, posix, tables, strutils, strtabs, json, cookies
import zmq, uuid
import private/optim_strange_loop, private/netstrings, private/jesterutils
import private/nawak_mg as n_mg,
       private/nawak_common as n_cm
export n_mg.get, n_mg.post, n_mg.response, n_mg.redirect, n_mg.custom_page
export n_cm.addCookie, n_cm.deleteCookie, n_cm.daysFromNow


const HTTP_FORMAT = "HTTP/1.1 $1 $2\r\n$3\r\n\r\n$4"

var context {.global.} : PContext


var interrupted {.global.} = false
proc signal_handler(signal_value: cint) {.noconv.} =
    interrupted = true
    echo "Interruption captured, force quit in 2 seconds"
    sleep(2000)
    if ctx_term(context) != 0:
        zmqError()

# register interrupt callbacks
var action: TSigAction
var nilaction: TSigAction
action.sa_handler = signal_handler
action.sa_flags = 0
discard sigemptyset(action.sa_mask)
discard sigaction(SIGINT, action, action)
discard sigaction(SIGTERM, action, action)


proc set_linger(to_mongrel: PSocket) =
    var delay = 1500
    discard setsockopt(to_mongrel, LINGER, addr delay, sizeof(delay))


proc http_response(body:string, code: int, status: string,
                   headers: var StringTableRef): string =
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

proc send*(to_mongrel: TConnection, uuid, conn_id, msg: string) =
    let payload = "$1 $2:$3, $4" % [uuid, $conn_id.len, conn_id, msg]
    #let payload = optFormat("$1 $2:$3, $4", [uuid, $conn_id.len, conn_id, msg])
    zmq.send(to_mongrel, payload)

#proc deliver(uuid: string, idents: openArray[string], data: string) =
#    send(uuid, idents.join(" "), data)

proc deliver(to_mongrel: TConnection, uuid, conn_id, data: string) =
    send(to_mongrel, uuid, conn_id, data)


proc prepare_request_obj(req: TMongrelMsg): TRequest =
    result.path = req.headers["PATH"].str
    result.query = {:}.newStringTable
    if req.headers.hasKey("QUERY"):
        parseUrlQuery(req.headers["QUERY"].str, result.query)
    if req.headers.hasKey("cookie"):
        result.cookies = parseCookies(req.headers["cookie"].str)
    else:
        result.cookies = {:}.newStringTable

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
        resp = arg.nawak.custom_pages[500](msg & "\L" & stacktrace)
        break

type ThrArgs = tuple
    init: proc()
    from_addr, to_addr: string
    nawak: TNawak

proc run_thread*(arg: ThrArgs) {.thread.} =
    var my_uuid: Tuuid
    uuid_generate_random(my_uuid)
    let sender_uuid = my_uuid.to_hex
    #echo "I am: ", sender_uuid

    var from_mongrel = connect(arg.from_addr, PULL, context)
    var to_mongrel = connect(arg.to_addr, PUB, context)
    discard setsockopt(to_mongrel.s, IDENTITY, cstring(sender_uuid),
                       sender_uuid.len)

    arg.init()

    while not interrupted:
        #echo ""
        var msg: string
        try:
            msg = receive(from_mongrel)
        except EZmq:
            set_linger(to_mongrel.s)
            break

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
            for it in arg.nawak.gets:
                try_match()

        of "POST":
            let request = prepare_request_obj(req)
            for it in arg.nawak.posts:
                try_match()

        else:
            echo "METHOD NOT AVAILABLE"
            to_mongrel.send(req.uuid, req.id, "")  # disconnect

        if not has_matched:
            resp = arg.nawak.custom_pages[404]("""
            <i>&quot;And they took the road less traveled.
            Unfortunately, there was nothing there.&quot;</i>
            """)

        if resp.headers == nil:
            resp.headers = {:}.newStringTable
        if resp.body == nil or resp.code == 0:
            resp = arg.nawak.custom_pages[500]("""
            The programmer forgot to add a status code or to return some data
            in the body of the response.""")

        if interrupted:
            set_linger(to_mongrel.s)

        try:
            to_mongrel.send(req.uuid, req.id, http_response(
                resp.body, resp.code, "OK", resp.headers
            ))
        except EZmq:
            set_linger(to_mongrel.s)
            break

    #var thread_id = cast[int](myThreadId[type(arg)]())
    #echo "Quit thread $#" % $thread_id

    let status_from = close(from_mongrel.s)
    let status_to = close(to_mongrel.s)
    if  status_from != 0 or status_to != 0:
        zmqError()

proc run*(init: proc(), from_addr="tcp://localhost:9999", to_addr="tcp://localhost:9998", nb_threads=32) =
    context = ctx_new()
    if context == nil:
        zmqError()
    
    ## the following only executes (number of cpu cores) threads at a time maximum
    #let nb_cpu = 4
    #for i in 0 .. nb_cpu:
    #    spawn run_thread(from_addr, to_addr)
    #system.sync()

    var thr: seq[TThread[ThrArgs]]
    thr.newSeq(nb_threads)

    for i in 0 .. <nb_threads:
        createThread(thr[i], run_thread, (init, from_addr, to_addr, nawak))
    echo "Started with $# threads" % $nb_threads

    joinThreads(thr)

    #if ctx_term(context) != 0:
    #    zmqError()

proc run*(init: proc(), from_addr, to_addr: int, nb_threads=32) =
    run(init, "tcp://localhost:" & $from_addr, "tcp://localhost:" & $to_addr, nb_threads)

proc empty_init() =
    discard

proc run*(from_addr = 9999, to_addr = 9998, nb_threads=32) =
    run(empty_init, from_addr, to_addr, nb_threads)

