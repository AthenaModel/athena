#-----------------------------------------------------------------------
# TITLE:
#   tool_get.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena "get" tool.  Posts a file to an arachne server.
#   * EXPERIMENTAL *
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::GET

tool define GET {
    usage       {1 - "?options...? url"}
    description "Athena Web Server"
} {
    Arachne Post Tool

    This tool gets files to an Arachne server given a server-relative
    URL.  The following options may be used:

    -port <id>        - The server port on the local host; defaults to
                        port 8080.
} {
    #-------------------------------------------------------------------
    # Execution 

    # execute argv
    #
    # Executes the tool given the command line arguments.

    typemethod execute {argv} {
        package require http

        set url      [lshift argv]
        set filename [lshift argv]
        set port     8080
        
        foroption opt argv {
            -port {
                set port [lshift argv]
            }
        }

        set url http://localhost:$port/$url

        puts "Getting $url"

        set token [http::geturl $url]

        puts [::http::code $token]
        puts [::http::data $token]
    }

}



