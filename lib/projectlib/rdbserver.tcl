#-----------------------------------------------------------------------
# TITLE:
#    rdbserver.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n): Run-time Database myserver(i) Server
#
#    This is an object that presents a unified view of the data resources
#    contained in an SQLite3 database.  It's intended more developer
#    use than end-user use, as the data isn't beautified in any way.
#
# URLs:
#
#    Resources are identified by URLs, as in a web server, using the
#    "my://" scheme.  If this server were registered as "rdb", for
#    example, it could be queried using "my://rdb/...".  
#
#    Point a mybrowser(n) at this, and query "/" to get the overview
#    page.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export rdbserver
}

#-----------------------------------------------------------------------
# myserver type

snit::type ::projectlib::rdbserver {
    #-------------------------------------------------------------------
    # Components

    component server ;# myserver(n) instance
    component ht     ;# htools(n) instance
    component rdb    ;# The -rdb

    #-------------------------------------------------------------------
    # Options

    # -rdb
    #
    # The run-time database to query.

    option -rdb \
        -configuremethod ConfigRDB

    method ConfigRDB {opt val} {
        set options($opt) $val
        set rdb $val
        $ht configure -rdb $val
    }

    #-------------------------------------------------------------------
    # Instance Variables

    # TBD

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, create the server
        set server [myserver ${selfns}::server]

        # NEXT, create the htools buffer.
        install ht using htools ${selfns}::ht \
            -footercmd [mymethod FooterCmd]

        # NEXT, save options
        $self configurelist $args

        # NEXT, register the resources
        $server register / {/?} \
            text/html [mymethod html_Overview] {
                An overview of the tables, views, and triggers defined
                in the database.  If the query portion of the URL 
                is present, it is a wildcard pattern; the overview includes 
                only the tables, views, and triggers whose names match the 
                pattern, e.g, "/?*data*" will match all entities whose names
                include "data".  Queries are case-sensitive.
            }

        $server register /main {(main)/?} \
            text/html [mymethod html_Overview] {
                An overview of the persistent tables, views, and triggers 
                defined
                in the database.  If the query portion of the URL 
                is present, it is a wildcard pattern; the overview include 
                only the tables, views, and triggers whose names match the 
                pattern.
            }

        $server register /temp {(temp)/?} \
            text/html [mymethod html_Overview] {
                An overview of the temporary tables, views, and triggers 
                defined
                in the database.  If the query portion of the URL 
                is present, it is a wildcard pattern; the overview include 
                only the tables, views, and triggers whose names match the 
                pattern.
            }

        $server register /schema/{name} {schema/(\w+)} \
            text/html [mymethod html_Schema]           \
            "Schema for database table, view, or trigger {name}."

        $server register /content/{name} {content/(\w+)} \
            text/html [mymethod html_Content]            {
                Content for database table or view {name}.  The URL 
                may include a query string of the form 
                "{parm}={value}+{parm}={value}..."; the parameters
                are "page_size" and "page".
            }

    }


    #-------------------------------------------------------------------
    # Callbacks

    # FooterCmd
    #
    # Formats footer text for generated pages.

    method FooterCmd {} {
        $ht putln <p>
        $ht putln <hr>
        $ht putln "<font size=2><i>"

        $ht put [format "Page generated at %s" [clock format [clock seconds]]]

        $ht put "</i></font>"
    }

    #-------------------------------------------------------------------
    # Content Handlers

    # html_Overview udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    # 
    # Produces an HTML page with a table of the RDB tables, views,
    # etc., for which schema text is available.
    #
    # match(1)  determines the subset of the schema 
    # to display:
    #
    #   ""         - All items are displayed
    #   main       - Items from sqlite_master
    #   temp       - Items from sqlite_temp_master
    #
    # If the query is not "", it is a wildcard pattern; only items
    # whose names match the pattern are included.

    method html_Overview {udict matchArray} {
        upvar 1 $matchArray ""

        set subset $(1)
        set pattern [dict get $udict query]

        set main {
            SELECT type, 
                   name, 
                   "Persistent",
                   CASE WHEN type IN ('table', 'view')
                   THEN link('/schema/' || name, 'Schema') || ', ' ||
                        link('/content/' || name, 'Content')
                   ELSE link('/schema/' || name, 'Schema') END
            FROM sqlite_master
            WHERE name NOT GLOB 'sqlite_*'
            AND   type != 'index'
            AND   sql IS NOT NULL
        }

        set temp {
            SELECT type, 
                   name, 
                   "Temporary",
                   CASE WHEN type IN ('table', 'view')
                   THEN link('/schema/' || name, 'Schema') || ', ' ||
                        link('/content/' || name, 'Content')
                   ELSE link('/schema/' || name, 'Schema') END
            FROM sqlite_temp_master
            WHERE name NOT GLOB 'sqlite_*'
            AND   type != 'index'
            AND   sql IS NOT NULL
        }
        
        switch -exact -- $subset {
            "" { 
                if {$pattern eq ""} {
                    set sql "$main UNION $temp ORDER BY name"
                    set text ""
                } else {
                    set sql "
                        $main AND name GLOB \$pattern UNION
                        $temp AND name GLOB \$pattern ORDER BY name
                    "

                    set text "Items matching \"<code>$pattern</code>\".<p>"
                }
            }

            main { 
                if {$pattern eq ""} {
                    set sql "$main ORDER BY name"
                    set text "Persistent items only.<p>"
                } else {
                    set sql "
                        $main AND name GLOB \$pattern ORDER BY name
                    "

                    set text "Persistent items matching \"<code>$pattern</code>\".<p>"
                }
            }

            temp { 
                if {$pattern eq ""} {
                    set sql "$temp ORDER BY name"
                    set text "Temporary items only.<p>"
                } else {
                    set sql "
                        $temp AND name GLOB \$pattern ORDER BY name
                    "

                    set text "Temporary items matching \"<code>$pattern</code>\".<p>"
                }
            }
        }

        $ht page "Database Overview: $rdb"
        $ht h1 "Database Overview: $rdb"

        $ht putln $text

        $ht query $sql -labels {Type Name Persistence Links} -maxcolwidth 0

        $ht /page

        return [$ht get]
    }

    # html_Schema udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    # 
    # Produces an HTML page with the schema of a particular 
    # table, view, or trigger for which schema text is available.

    method html_Schema {udict matchArray} {
        upvar 1 $matchArray ""

        set name $(1)

        $rdb eval {
            SELECT sql,type FROM sqlite_master
            WHERE name=$name
            UNION
            SELECT sql,type FROM sqlite_temp_master
            WHERE name=$name
        } {
            $ht page "Database Schema: $rdb, $name" {
                $ht h1 "Database Schema: $rdb, $name"

                if {$type in {table view}} {
                    $ht linkbar [list \
                                     /content/$name "View Content"       \
                                     /              "Database Overview"]
                } else {
                    $ht linkbar {/ "Database Overview"}
                }
                             
                $ht pre $sql
            }

            return [$ht get]
        }

        return -code error -errorcode NOTFOUND \
            "The requested database entity was not found."
    }


    # html_Content udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    # 
    # Produces an HTML page with the content of a particular 
    # table or view.  
    #
    # The following query parameters may be used:
    #
    #   page_size    - The number of rows to display on one page.
    #   page         - The page number, 1 to N, to display
    #
    # 

    method html_Content {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the entity to query, and make sure it exists.
        set name $(1)

        if {![$rdb exists {
            SELECT name FROM sqlite_master
            WHERE name=$name AND type in ('table','view')
            UNION
            SELECT name FROM sqlite_temp_master
            WHERE name=$name AND type in ('table','view')
        }]} {
            return -code error -errorcode NOTFOUND [normalize {
                The requested database entity was not found,
                or is not a table or view.
            }]
        }

        # NEXT, get the query parameters
        set query [dict get $udict query]
        set qdict [urlquery get $query {page_size page}]

        dict with qdict {
            restrict page_size epagesize 20
            restrict page      ipositive 1
        }

        # NOTE: The qdict field values are now visible.

        # NEXT, begin the page.

        $ht page "Database Content: $rdb, $name"
        $ht h1 "Database Content: $rdb, $name"
        $ht linkbar [list \
                         /schema/$name  "View Schema"        \
                         /              "Database Overview"]

        # NEXT, insert the control form.
        $ht hr
        $ht form -autosubmit 1
        $ht label page_size "Page Size:"
        $ht input page_size enum $page_size -src enum/pagesize -content tcl/enumdict
        $ht /form
        $ht hr
        $ht para

        # NEXT, get output stats
        set items [rdb onecolumn "SELECT count(*) FROM $name"]
     
        if {$page_size eq "ALL"} {
            set page_size $items
        }

        let pages {entier(ceil(double($items)/$page_size))}

        if {$page > $pages} {
            set page 1
        }

        let offset {($page - 1)*$page_size}

        $ht pager $qdict $page $pages

        $ht query "
            SELECT * FROM $name 
            ORDER BY rowid
            LIMIT \$page_size OFFSET \$offset 
        " -escape yes

        $ht para
        $ht pager $qdict $page $pages


        $ht /page

        return [$ht get]
    }



    #-------------------------------------------------------------------
    # Public Methods

    delegate method ctypes    to server
    delegate method resources to server


    # get url ?contentTypes?
    #
    # url         - The URL of the resource to get.
    # contentType - The list of accepted content types.  Wildcards are
    #               allowed, e.g., text/*, */*
    #
    # This is a simple wrapper around the myserver(n)'s get that
    # ensures that the -rdb is defined.

    method get {url {contentTypes ""}} {
        if {$options(-rdb) eq ""} {
            return -code error -errorcode NOTFOUND \
                "No data available, -rdb is not set."
        }
        
        return [$server get $url $contentTypes]
    }
}



