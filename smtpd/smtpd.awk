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
    history = pg_prepare(conn, "UPDATE history SET result = $1 WHERE recipient = $2 AND email_id = (SELECT id FROM email WHERE message_id = ('x'||$3)::bit(28)::int)")
    if (!history) {
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
    subsystem = $3
    print("register", "report", subsystem, "*") > "/dev/stderr"
    print("register", "report", subsystem, "*")
    next
}
"report" == $1 {
    print($0) > "/dev/stderr"
    if (NF < 6) {
        print("invalid filter command: expected >5 fields!") > "/dev/stderr"
        exit 1
    }
    subsystem = $4
    event = $5
    session = $6
}
"report|smtp-in|protocol-server" == $1_$4_$5 {
    protocol[session] = sprintf("%s%s\r\n", protocol[session], $7)
    next
}
"report|smtp-in|tx-begin" == $1_$4_$5 {
    message[session] = $7
    next
}
"report|smtp-in|tx-reset" == $1_$4_$5 {
    protocol[message[session]] = protocol[session]
    next
}
"report|smtp-in|link-disconnect" == $1_$4_$5 {
    delete message[session]
    delete protocol[session]
    next
}
"report|smtp-out|protocol-client" == $1_$4_$5 {
    protocol[session] = sprintf("%s%s\r\n", protocol[session], $7)
    next
}
"report|smtp-out|protocol-server" == $1_$4_$5 {
    protocol[session] = sprintf("%s%s\r\n", protocol[session], $7)
    next
}
"report|smtp-out|tx-begin" == $1_$4_$5 {
    message[session] = $7
    next
}
"report|smtp-out|tx-rcpt" == $1_$4_$5 {
    val[1] = $8
    val[2] = $9
    val[3] = $7
    res = pg_execprepared(conn, history, 3, val)
    if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
        connect()
        res = pg_execprepared(conn, history, 3, val)
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
    if (protocol[message[session]]) {
        val[1] = protocol[session]
        val[2] = protocol[message[session]]
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
        delete protocol[message[session]]
    }
    delete message[session]
    delete protocol[session]
    next
}
END {
    pg_disconnect(conn)
}
