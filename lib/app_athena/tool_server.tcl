#-----------------------------------------------------------------------
# TITLE:
#   tool_server.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena "server" tool.  This tool starts a simple web server.
#   * EXPERIMENTAL *
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::SERVER

tool define SERVER {
    usage       {0 - "?options...?"}
    description "Athena Web Server"
} {
    EXPERIMENTAL.
} {
    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        puts "Starting web server"

        # server specific version of bgerror
        proc ::bgerror {msg} {
            global errorInfo

            set msg "[clock format [clock seconds]]\n$errorInfo"
            if [catch {::ahttpd::log add nosock bgerror $msg}] {
                ::ahttpd::Stderr $msg
            }
        }


        foroption opt argv {
            -gui {
                package require marsgui
                wm withdraw .
                ::marsgui::debugger new
            }
        }

        ahttpd::server init \
            -docroot ~/github/athena/htdocs

        # TBD: Need better API for this kind of thing.
        ahttpd::direct url /welcome.html [myproc Welcome]



        if {[ahttpd::server port] ne ""} {
            puts "http started on port [ahttpd::server port]"
        }

        if {[ahttpd::server secureport] ne ""} {
            puts "https started on port [ahttpd::server secureport]"
        }

        vwait forever
    }

    proc Welcome {args} {
        upvar 1 env env
        append result [outdent {
            <html>
            <head>
            <title>Welcome!</title>
            </head>
            <body>
            Welcome!  The arguments are:<p>

        }]

        append result "<pre>[list $args]</pre><p>"

        append result "The environment is:<p>"
        append result "<pre>[::ahttpd::parray env]</pre>"
        append result "</body></html>"

        return $result

    }
}




