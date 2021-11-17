BEGIN {
    FS = "|"
    OFS = FS
    _ = FS
}
"config|ready" == $0 {
    print($0) > "/dev/stderr"
    print("register|ready") > "/dev/stderr"
    print("register|ready")
    fflush()
    next
}
"config|subsystem" == $1_$2 {
    print($0) > "/dev/stderr"
    print("register", "report", $3, "*") > "/dev/stderr"
    print("register", "report", $3, "*")
    next
}
"report" == $1 {
    print($0) > "/dev/stderr"
    val[1] = $0
    if (!conn) {
        conn = pg_connect("application_name=smtp target_session_attrs=read-write")
    }
    if (!conn) {
        print("!pg_connect") > "/dev/stderr"
        exit 1
    }
    if (!smtp) {
        smtp = pg_prepare(conn, "INSERT INTO smtp (report) VALUES ($1)")
    }
    if (!smtp) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        exit 1
    }
    res = pg_execprepared(conn, smtp, 1, val)
    if (!res) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        exit 1
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
