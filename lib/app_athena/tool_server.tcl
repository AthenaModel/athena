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
    usage       {0 0 TBD}
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

        ahttpd::server init \
            -docroot ~/github/athena/htdocs
        vwait forever
    }
}




