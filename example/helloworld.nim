import nawak_mongrel

get "/":
    return response("Hello World!")

run()
