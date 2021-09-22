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
function update(message) {
    if (where[message]) {
        val[1] = output[message]
        val[2] = where[message]
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
        delete where[message]
    }
    delete output[message]
    for (i = 1; i <= len[message]; i++) {
        val[1] = message
        val[2] = array[message, i, 1]
        val[3] = array[message, i, 2]
        print(val[1]) > "/dev/stderr"
        print(val[2]) > "/dev/stderr"
        print(val[3]) > "/dev/stderr"
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
    }
    for (i = 1; i <= len[message]; i++) {
        delete array[message, i, 1]
        delete array[message, i, 2]
    }
    delete len[message]
    delete connected[message]
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
    where[$6] = sprintf("%s%s\r\n", where[$6], $7)
    next
}
"report|smtp-in|tx-begin" == $1_$4_$5 {
    message[$6] = $7
    connected[$7] ++
    next
}
"report|smtp-in|tx-reset" == $1_$4_$5 {
    where[message[$6]] = where[$6]
    next
}
"report|smtp-in|link-disconnect" == $1_$4_$5 {
    if (connected[message[$6]] == 1) {
        update(message[$6])
    } else {
        connected[message[$6]] --
    }
    delete message[$6]
    delete where[$6]
    next
}
"report|smtp-out|protocol-client" == $1_$4_$5 {
    output[$6] = sprintf("%s%s\r\n", output[$6], $7)
    next
}
"report|smtp-out|protocol-server" == $1_$4_$5 {
    output[$6] = sprintf("%s%s\r\n", output[$6], $7)
    if (match($7, /^550.+<(.+)>/, m)) {
        print(m[1]) > "/dev/stderr"
        len[message[$6]] ++
        array[message[$6], len[message[$6]], 1] = "permfail"
        array[message[$6], len[message[$6]], 2] = m[1]
    }
    next
}
"report|smtp-out|tx-begin" == $1_$4_$5 {
    message[$6] = $7
    connected[$7] ++
    next
}
"report|smtp-out|tx-reset" == $1_$4_$5 {
    output[message[$6]] = sprintf("%s%s\r\n", output[message[$6]], output[$6])
    next
}
"report|smtp-out|tx-rcpt" == $1_$4_$5 {
    len[$7] ++
    array[$7, len[$7], 1] = $8
    array[$7, len[$7], 2] = $9
    next
}
"report|smtp-out|link-disconnect" == $1_$4_$5 {
    if (connected[message[$6]] == 1) {
        update(message[$6])
    } else {
        connected[message[$6]] --
    }
    delete message[$6]
    delete output[$6]
    next
}
END {
    pg_disconnect(conn)
}
