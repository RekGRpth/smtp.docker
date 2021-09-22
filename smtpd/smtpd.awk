function connect() {
    conn = pg_connect("application_name=smtp target_session_attrs=read-write")
    if (!conn) {
        print("!pg_connect") > "/dev/stderr"
        exit 1
    }
    task = pg_prepare(conn, "UPDATE task SET output = output||'\r\n'||$1 WHERE output LIKE $2||'%'")
    if (!task) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        print("!pg_prepare") > "/dev/stderr"
        exit 1
    }
    email = pg_prepare(conn, "UPDATE email SET result[array_position(recipient, $3)] = $2 WHERE message_id = ('x'||$1)::bit(28)::int")
    if (!email) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        print("!pg_prepare") > "/dev/stderr"
        exit 1
    }
}
BEGIN {
    FS = "|"
    OFS = FS
    _ = FS
    connect()
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
    if (NF < 6) {
        print("invalid filter command: expected >5 fields!") > "/dev/stderr"
        exit 1
    }
}
"report|smtp-in|protocol-server" == $1_$4_$5 {
    protocol[$6] = sprintf("%s%s\r\n", protocol[$6], $7)
    next
}
"report|smtp-in|tx-begin" == $1_$4_$5 {
    message[$6] = $7
    next
}
"report|smtp-in|tx-reset" == $1_$4_$5 {
    protocol[message[$6]] = protocol[$6]
    next
}
"report|smtp-in|link-disconnect" == $1_$4_$5 {
    delete message[$6]
    delete protocol[$6]
    next
}
"report|smtp-out|protocol-client" == $1_$4_$5 {
    protocol[$6] = sprintf("%s%s\r\n", protocol[$6], $7)
    next
}
"report|smtp-out|protocol-server" == $1_$4_$5 {
    protocol[$6] = sprintf("%s%s\r\n", protocol[$6], $7)
    next
}
"report|smtp-out|tx-begin" == $1_$4_$5 {
    message[$6] = $7
    next
}
"report|smtp-out|tx-rcpt" == $1_$4_$5 {
    val[1] = $7
    val[2] = $8
    val[3] = $9
    res = pg_execprepared(conn, email, 3, val)
    if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
        connect()
        res = pg_execprepared(conn, email, 3, val)
    }
    print(res) > "/dev/stderr"
    if (res) {
        if (res != "OK 1") {
            print(pg_errormessage(conn)) > "/dev/stderr"
        }
        pg_clear(res)
    } else {
        print(pg_errormessage(conn)) > "/dev/stderr"
    }
    delete val
    next
}
"report|smtp-out|link-disconnect" == $1_$4_$5 {
    if (protocol[message[$6]]) {
        val[1] = protocol[$6]
        val[2] = protocol[message[$6]]
        res = pg_execprepared(conn, task, 2, val)
        if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
            connect()
            res = pg_execprepared(conn, task, 2, val)
        }
        print(res) > "/dev/stderr"
        if (res) {
            if (res != "OK 1") {
                print(pg_errormessage(conn)) > "/dev/stderr"
            }
            pg_clear(res)
        } else {
            print(pg_errormessage(conn)) > "/dev/stderr"
        }
        delete val
        delete protocol[message[$6]]
    }
    delete message[$6]
    delete protocol[$6]
    next
}
END {
    pg_disconnect(conn)
}
