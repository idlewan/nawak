import strtabs, times
import ../lib/cookies

proc addCookie*(headers: var PStringTable, key, value: string;
                expires: TTimeInfo, domain = "", path = "",
                secure = false, httpOnly = false) =
    if headers.hasKey("Set-Cookie"):
        headers.mget("Set-Cookie").add "\c\L" & setCookie(key, value,
            expires, domain, path, noName=false, secure, httpOnly)
    else:
        headers["Set-Cookie"] = setCookie(key, value, expires, domain, path,
                                                  noName=true, secure, httpOnly)

proc addCookie*(headers: var PStringTable; key, value: string; domain="",
                path="", secure=false, httpOnly=false) =
    if headers.hasKey("Set-Cookie"):
        headers.mget("Set-Cookie").add "\c\L" &
            setCookie(key, value, domain=domain, path=path, noName=false,
                              secure=secure, httpOnly=httpOnly)
    else:
        headers["Set-Cookie"] = setCookie(key, value, domain=domain,
            path=path, noName=true, secure=secure, httpOnly=httpOnly)

proc deleteCookie*(headers: var PStringTable, key: string, domain="", path="",
                   secure=false, httpOnly=false) =
    var tim = TTime(0).getGMTime()
    addCookie(headers, key, "deleted", expires=tim, domain, path, secure, httpOnly)

proc daysFromNow*(days: int): TTimeInfo =
    return TTime(int(getTime()) + days * (60*60*24)).getGMTime()
