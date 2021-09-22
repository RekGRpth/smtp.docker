function connect() {
    conn = pg_connect("application_name=smtp target_session_attrs=read-write")
    if (!conn) {
        print("!pg_connect") > "/dev/stderr"
        exit 1
    }
    stmtName = pg_prepare(conn, "UPDATE task SET output = output||'\r\n'||$1 WHERE output LIKE $2||'%'")
    if (!stmtName) {
        print(pg_errormessage(conn)) > "/dev/stderr"
        print("!pg_prepare") > "/dev/stderr"
        exit 1
    }
    stmtName2 = pg_prepare(conn, "UPDATE history SET result = $1 WHERE recipient = $2 AND email_id = (SELECT id FROM email WHERE message_id = ('x'||$3)::bit(28)::int)")
    if (!stmtName2) {
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
"report|smtp-in|tx-begin" == $1_$4_$5 {
    message = $7
    message_session[session] = message
    next
}
"report|smtp-in|tx-reset" == $1_$4_$5 {
    if (message_session[session]) {
        status_message[message_session[session]] = status_session[session]
    }
    delete status_session[session]
    next
}
"report|protocol-server" == $1_$5 {
    status_session[session] = sprintf("%s%s\r\n", status_session[session], $7)
    next
}
"report|smtp-out|protocol-client" == $1_$4_$5 {
    status_session[session] = sprintf("%s%s\r\n", status_session[session], $7)
    next
}
"report|smtp-out|tx-begin" == $1_$4_$5 {
    message = $7
    message_session[session] = message
    count_message[message] ++
    next
}
"report|smtp-out|tx-rcpt" == $1_$4_$5 {
    message = $7
    result = $8
    address = $9
    nParams = 3
    paramValues[1] = result
    paramValues[2] = address
    paramValues[3] = message
    res = pg_execprepared(conn, stmtName2, nParams, paramValues)
    if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
        connect()
        res = pg_execprepared(conn, stmtName2, nParams, paramValues)
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
    delete paramValues
    next
}
"report|smtp-out|tx-reset" == $1_$4_$5 {
    if (status_message[message_session[session]]) {
        nParams = 2
        paramValues[1] = status_session[session]
        paramValues[2] = status_message[message_session[session]]
        res = pg_execprepared(conn, stmtName, nParams, paramValues)
        if (res == "ERROR BADCONN PGRES_FATAL_ERROR") {
            connect()
            res = pg_execprepared(conn, stmtName, nParams, paramValues)
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
        delete paramValues
    }
    delete status_session[session]
    count_message[message_session[session]] --
    if (count_message[message_session[session]] <= 0) {
        delete status_message[message_session[session]]
        delete count_message[message_session[session]]
    }
    delete message_session[session]
    next
}
END {
    pg_disconnect(conn)
}
