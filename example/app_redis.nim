import strtabs, strutils, math, algorithm
import nawak_mongrel, jdump
import model, fortunes_tmpl
import redis

var db = open(host="localhost")

proc getTWorld(id: int): TWorld =
    let s = redis.get(db, "world:" & $id)
    if s == redisNil:
        raise newException(ERedis, "World Not Found")
    return (id, s.parseInt)

proc getAllFortunes(): seq[TFortune] =
    result = @[]
    var i = 1
    for s in db.lrange("fortunes", 0, -1):
        result.add((id: i, message: s))
        inc(i)


get "/json":
    var j: THello
    j.message = "Hello, World!"
    # jdump serialize tuples as json
    return response(jdump(j), "application/json")

get "/plaintext":
    return response("Hello, World!", "text/plain")

get "/db":
    let w = getTWorld(random(10_000) + 1)
    return response(jdump(w), "application/json")

get "/queries":
    var queries = 1
    if request.query.hasKey("queries"):
        try:
            queries = parseInt(request.query["queries"])
        except EInvalidValue: discard
        if queries < 1: queries = 1
        elif queries > 500: queries = 500

    var world: seq[TWorld]
    world.newSeq(queries)
    for i in 0.. <queries:
        world[i] = getTWorld(random(10_000) + 1)
    return response(jdump(world), "application/json")

get "/fortunes":
    var fortunes = getAllFortunes()
    let new_fortune: TFortune = (id: fortunes.len + 1,
                                 message: "Additional fortune added at request time.")
    fortunes.add new_fortune
    sort(fortunes, proc(x, y: TFortune): int =
        return cmp(x.message, y.message))

    return response(fortunes_tmpl(fortunes), "text/html; charset=utf-8")

get "/updates":
    var queries = 1
    if request.query.hasKey("queries"):
        try:
            queries = parseInt(request.query["queries"])
        except EInvalidValue: discard
        if queries < 1: queries = 1
        elif queries > 500: queries = 500

    var world: seq[TWorld]
    world.newSeq(queries)
    for i in 0.. <queries:
        world[i] = getTWorld(random(10_000) + 1)
        world[i].randomNumber = random(10_000) + 1
        db.setk("world:" & $world[i].id, $world[i].randomNumber)

    return response(jdump(world), "application/json")

run()
