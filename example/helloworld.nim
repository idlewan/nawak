import nawak_mongrel, strutils

get "/":
    return response("Hello World!")

get "/user/@username/":
    return response("Hello $1!" % url_params.username)

run()
