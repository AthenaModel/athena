#-----------------------------------------------------------------------
# TITLE:
#   tool_post.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   Athena "post" tool.  Posts a file to an arachne server.
#   * EXPERIMENTAL *
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# tool::POST

tool define POST {
    usage       {1 - "url filename ?options...?"}
    description "Athena Web Server"
} {
    Arachne Post Tool

    This tool posts files to an Arachne server given a URL.
    The following options may be used:

    -port <id>        - The server port on the local host; defaults to
                        port 8080.
    -type <mimetype>  - Specifies the content-type; defaults to 
                        text-plain.
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
        set ctype    text/plain
        
        foroption opt argv -all {
            -port {
                set port [lshift argv]
            }
            -ctype {
                set ctype [lshift argv]
            }
        }

        set fullurl http://localhost:$port/$url

        puts "Posting $filename to $fullurl"

        # TBD: should handle binary data files differently.

        set query [string trim [readfile $filename]]
        set token [http::geturl $fullurl -query $query -type $ctype]

        puts [::http::code $token]
        puts [::http::data $token]
    }

}



