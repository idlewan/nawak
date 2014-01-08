# nawak

A web micro-framework in Nimrod, heavily inspired by jester, flask and the like.
It is only compatible with the `Mongrel2` server for now.

## Minimal example
```nimrod
# helloworld.nim
import nawak_mongrel, strutils

get "/":
    return response("Hello World!")

get "/user/@username/":
    return response("Hello $1!" % url_params.username)

run()
```

## Installation
Install `Mongrel2` by following the instructions in the [manual](http://mongrel2.org/manual/book-finalch3.html). The bindings for `ZeroMQ` may only work with `ZeroMQ` version 4.

Start `Mongrel2` either with the provided Makefile in the `example/conf/` folder, or manually:

    $ cd example/conf
    $ mkdir -p run logs tmp
    $ m2sh load
    $ sudo m2sh start -every

Please check that you don't use the stable compiler version of `Nimrod`. *nawak* only works with a fresh Nimrod compiler. The `0.9.2` stable version is not enough, you have to go all `git clone https://github.com/Araq/Nimrod.git` on it.

You can now compile and execute the examples from the `example` folder:

    $ cd example
    $ nimrod c -d:release helloworld.nim
    $ ./helloworld
    $ firefox http://localhost:6767/

The [nawak_app.nim](https://github.com/idlewan/nawak/blob/master/example/nawak_app.nim) example answers the requirements of the [web framework benchmarks](http://www.techempower.com/benchmarks/). You will want to install PostgreSQL and create the [database and tables](https://github.com/TechEmpower/FrameworkBenchmarks/tree/master/config) to test it out.

## Performance test
If you want to make changes and see how it performs, you can use `wrk` to have a preview of the performance.
The command-line options you will want to use are (from the web framework benchmarks):

    $ wrk -H 'Host: localhost' -H 'Accept: application/json,text/html;q=0.9,application/xhtml+xml;q=0.9,application/xml;q=0.8,*/*;q=0.7' -H 'Connection: keep-alive' -d 15 -c 256 -t 1 http://localhost:6767/json
