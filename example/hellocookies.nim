import strtabs, times
import nawak_mongrel, cookies


get "/mmm_cookies":
    var headers = {:}.newStringTable
    headers.addCookie("a_cookie", "simple session cookie")
    headers.addCookie("another_cookie", "Persistent cookie that will stay a week",
                      7.daysFromNow)
    headers.addCookie("other_cookie",
                      "Only sent back on https and unaccessible from javascript",
                      secure=true, httpOnly=true)

    echo headers
    return response("Hi! I gave you cookies. <a href=\"/\">Go back.</a>", headers)

get "/":
    var msg = ""
    if request.cookies.hasKey("a_cookie"):
        # Here is how you get the value of a cookie
        msg = "Ha! I see you already got something for me (like a " &
              request.cookies["a_cookie"] & ").<br><br>"

    return response(msg & "Here are the cookies you sent me:<br>" & $request.cookies &
        """<br><br><a href="/mmm_cookies">Join the Dark Side</a>, we have cookies.
        <br><br>To destroy the cookies, <a href="/remove_cookies">go here</a>""")

get "/remove_cookies":
    var headers = {:}.newStringTable
    for key in request.cookies.keys:
        headers.deleteCookie(key)

    # If you're not on https, the loop won't have deleted the following cookie
    headers.deleteCookie("other_cookie")
                            
    return response("I have eaten all your cookies. <a href=\"/\">Go back.</a>",
                    headers)

run()
