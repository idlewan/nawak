import macros, tables, strtabs, parseutils
from strutils import `%`, replace
from xmltree import escape
import jesterpatterns
import tuple_index_setter

# I can only support one level of magic without going insane.
# Thus, any template/macro that is not user-facing begins with ``inject_``
# to make crystal clear that it is not a standard function call and more stuff ends up
# in the scope.
# (user-facing: user == the programmer using the framework, not developing it)

type
    THttpCode* = int
    TRequest* = tuple[path: string, query: StringTableRef, cookies: StringTableRef]
    TResponse* = tuple[code: THttpCode,
                      headers: StringTableRef,
                      body: string]
    TMatcher = proc(s: string, request: TRequest):
        tuple[matched: bool, response: TResponse]
    TCallback = proc(request: TRequest): TResponse
    TSpecialPageCallback* = proc(msg: string): TResponse
    THttpMethod = enum
        TGET = "GET", TPOST = "POST"
    TNawak* = tuple[gets: seq[tuple[match: TMatcher, path: string]],
                   posts: seq[tuple[match: TMatcher, path: string]],
                   custom_pages: Table[int, TSpecialPageCallback] ]

var nawak* {.global.} : TNawak

proc default_404_handler(msg: string): TResponse =
    return (404, {:}.newStringTable,
            "The server says: <b>404 not found.</b><br><br>" & msg)

proc default_500_handler(msg: string): TResponse =
    echo msg
    let msg_html = msg.replace("\n", "<br>\L")
    return (500, {:}.newStringTable,
            "The server says: <b>500 internal error.</b><br><br>" & msg_html)

proc init_nawak(nawak: ptr TNawak) =
    nawak.gets = @[]
    nawak.posts = @[]
    nawak.custom_pages = initTable[int, TSpecialPageCallback]()
    nawak.custom_pages[404] = default_404_handler
    nawak.custom_pages[500] = default_500_handler

init_nawak(addr nawak)

proc register_custom_page(code: THttpCode, callback: TSpecialPageCallback) =
    nawak.custom_pages[code] = callback

template custom_page*(code: int, body: stmt): stmt {.immediate.} =
    bind register_custom_page
    register_custom_page(code, proc(msg: string): TResponse =
        body
    )

proc response*(body: string): TResponse =
    #result.code = 200
    #result.headers = nil
    #shallowCopy(result.body, body)
    return (200, nil, body)

proc response*(body: string, content_type: string): TResponse =
    return (200, {"Content-Type": content_type}.newStringTable, body)

proc response*(code: THttpCode, body: string): TResponse =
    return (code, nil, body)

proc response*(code: THttpCode, body: string, headers: StringTableRef): TResponse =
    return (code, headers, body)

proc response*(body: string, headers: StringTableRef): TResponse =
    return (200, headers, body)

proc redirect*(path: string, code = 303): TResponse =
    let path = escape(path)
    result.code = code
    result.headers = {:}.newStringTable
    result.headers["Location"] = path
    result.body = "Redirecting to <a href=\"$1\">$1</a>." % [path]

proc register(http_method: THttpMethod, matcher: TMatcher, path: string) =
    case http_method
    of TGET:
        nawak.gets.add((matcher, path))
    of TPOST:
        nawak.posts.add((matcher, path))

    # debug purposes:
    echo "registered: ", http_method, " ", path

template inject_matcher(path: string, pattern: TPattern,
                        callback: proc(r: TRequest):TResponse,
                        url_params: tuple) {.dirty, immediate.} =
    # (if not dirty, macros inside don't compile)
    ## injects the proc ``match`` in the current scope.
    ## The variables ``pattern``, ``callback`` and ``url_params`` are closed over,
    ## and are supposed to be declared before this template is called.
    bind TRequest, TResponse, TNode, TNodeText, TNodeField, check, findNextText,
         parseUntil, inject_tuple_setter_by_index
    proc match(s: string, request: TRequest):
        tuple[matched: bool, response: TResponse] {.closure.} =
      var i = 0 # Location in ``s``.

      result.matched = true
      var field_count = 0
      
      for ncount, node in pattern:
        case node.typ
        of TNodeText:
          if node.optional:
            if check(node, s, i):
              inc(i, node.text.len) # Skip over this optional character.
            else:
              # If it's not there, we have nothing to do. It's optional after all.
              discard
          else:
            if check(node, s, i):
              inc(i, node.text.len) # Skip over this
            else:
              # No match.
              result.matched = false
              return
        of TNodeField:
          var nextTxtNode: TNode
          var stopChar = '/'
          if findNextText(pattern, ncount, nextTxtNode):
            stopChar = nextTxtNode.text[0]
          var matchNamed = ""
          i += s.parseUntil(matchNamed, stopChar, i)
          if matchNamed != "":
            #url_params[field_count] = matchNamed
            ## this line doesn't work cause tuple index cannot be dynamic.
            ## solution: case switch macro injecter!
            inject_tuple_setter_by_index(field_count, url_params, matchNamed, path)
          elif matchNamed == "" and not node.optional:
            result.matched = false
            return
          inc(field_count)

      if s.len != i:
        result.matched = false
      else:
        result.response = callback(request)
        result.matched = true
        # cleanup the url parameters for the next request
        # (because of optional params that could find
        #  themselves filled even if they shouldn't)
        let emptystring = ""
        for j in 0..field_count-1:
            ## same impossibility with tuple index that cannot be dynamic
            #url_params[j] = ""
            #url_params[0] = ""
            inject_tuple_setter_by_index(j, url_params, emptystring, path)


macro inject_urlparams_tuple*(path: string): stmt =
    ## for a path like "/show/@user/@id/?"
    ## it will injects the following lines in the current scope:
    ##      var url_params {.threadvar.}: tuple[user: string, id: string]
    var path_str = $toStrLit(path)
    # remove the quotes at the beginning and end
    path_str = path_str[1 .. path_str.len - 2]

    var pattern = parsePattern(path_str)
    var fields_total = 0

    var pragmaexpr = newNimNode(nnkPragmaExpr)
    var pragma = newNimNode(nnkPragma)
    pragma.add(newIdentNode("threadvar"))
    pragmaexpr.add(newIdentNode("url_params"))
    pragmaexpr.add(pragma)

    var tuple_ty = newNimNode(nnkTupleTy)
    for i, node in pattern:
        case node.typ
        of TNodeField:
            inc(fields_total)
            tuple_ty.add(
                newIdentDefs(
                    newIdentNode( node.text ),
                    newIdentNode("string")
                )
            )
        else:
            discard

    if fields_total == 0:
        result = newEmptyNode()
        return

    result = newNimNode(nnkVarSection)
    result.add(newIdentDefs(
        pragmaexpr,
        tuple_ty
    ))

    # debug the constructed macro:
    #echo toStrLit(result)
    #echo result.treeRepr


template register_route(http_method: THttpMethod, path: string,
                        body: stmt): stmt {.immediate, dirty.} =
    bind parsePattern, TRequest, TResponse, inject_matcher,
         inject_urlparams_tuple, register
    block:
        let pattern = parsePattern(path)
        inject_urlparams_tuple(path)

        proc callback(request: TRequest): TResponse =
            body

        inject_matcher(path, pattern, callback, url_params)
        register(http_method, match, path)


template get*(path: string, body: stmt): stmt {.immediate, dirty.} =
    bind register_route, TGET
    register_route(TGET, path, body)

template post*(path: string, body: stmt): stmt {.immediate, dirty.} =
    bind register_route, TPOST
    register_route(TPOST, path, body)

