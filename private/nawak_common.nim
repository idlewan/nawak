import strtabs, times
import cookies

proc addCookie*(headers: var StringTableRef, key, value: string;
                expires: TimeInfo, domain = "", path = "",
                secure = false, httpOnly = false) =
    if headers.hasKey("Set-Cookie"):
        headers.mget("Set-Cookie").add "\c\L" & setCookie(key, value,
            expires, domain, path, noName=false, secure, httpOnly)
    else:
        headers["Set-Cookie"] = setCookie(key, value, expires, domain, path,
                                                  noName=true, secure, httpOnly)

proc addCookie*(headers: var StringTableRef; key, value: string; domain="",
                path="", secure=false, httpOnly=false) =
    if headers.hasKey("Set-Cookie"):
        headers.mget("Set-Cookie").add "\c\L" &
            setCookie(key, value, domain=domain, path=path, noName=false,
                              secure=secure, httpOnly=httpOnly)
    else:
        headers["Set-Cookie"] = setCookie(key, value, domain=domain,
            path=path, noName=true, secure=secure, httpOnly=httpOnly)

proc deleteCookie*(headers: var StringTableRef, key: string, domain="", path="",
                   secure=false, httpOnly=false) =
    var tim = Time(0).getGMTime()
    addCookie(headers, key, "deleted", expires=tim, domain, path, secure, httpOnly)

proc daysFromNow*(days: int): TimeInfo =
    return Time(int(getTime()) + days * (60*60*24)).getGMTime()
