function connect() {
    conn = pg_connect("application_name=smtp target_session_attrs=read-write")
    if (!conn) {
        print("!pg_connect") > "/dev/stderr"
        exit 1
    }
    smtp = pg_prepare(conn, "INSERT INTO smtp (report) VALUES ($1)")
    if (!smtp) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        exit 1
    }
}
BEGIN {
    FS = "|"
    OFS = FS
    connect()
}
{
    print($0) > "/dev/stderr"
}
"config|subsystem|smtp-in" == $0 {
    print("register|report|smtp-in|*")
    next
}
"config|subsystem|smtp-out" == $0 {
    print("register|report|smtp-out|*")
    next
}
"config|ready" == $0 {
    print("register|ready")
    fflush()
    next
}
"report" == $1 {
    val[1] = $0
    res = pg_execprepared(conn, smtp, 1, val)
    if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
        connect()
        res = pg_execprepared(conn, smtp, 1, val)
    }
    if (res != "OK 1") {
        print(pg_errormessage(conn)) > "/dev/stderr"
    }
    pg_clear(res)
    delete val
    next
}
END {
    pg_disconnect(conn)
}
