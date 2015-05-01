#-----------------------------------------------------------------------
# TITLE:
#    helpserver.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n): help(5) Database mydomain(i) Server
#
#    This is an object that serves help pages and images from a 
#    help(5) help database.
#
# URLs:
#
#    Resources are identified by URLs, as in a web server, using the
#    "my://" scheme.  If this server were registered as "help", for
#    example, it could be queried using "my://help/...".  
#
#    Point a mybrowser(n) at this, and query "/" to get the main help
#    page.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export helpserver
}

#-----------------------------------------------------------------------
# mydomain type

snit::type ::projectlib::helpserver {
    #-------------------------------------------------------------------
    # Components

    component server ;# mydomain(n) instance
    component hdb    ;# The help database handle

    #-------------------------------------------------------------------
    # Options

    # -domain

    delegate option -domain to server

    # -helpdb
    #
    # The name of the help(5) .helpdb file.

    option -helpdb \
        -readonly yes

    # -headercmd
    #
    # A command called with the page's URL as its only argument when 
    # page is retrieved as text/html.  Returns an HTML header to go
    # at the top of the page.

    option -headercmd

    #-------------------------------------------------------------------
    # Instance Variables

    # Image Cache
    # 
    # Images are cached as Tk images in the 
    # imageCache array.  The keys are /image/{name} URLs; the 
    # values are Tk image names.

    variable imageCache -array {}

    #-------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, get the options
        set domain [from args -domain /help]
        $self configurelist $args

        if {$options(-helpdb) eq ""} {
            error "No -helpdb given!"
        }

        # NEXT, create the server
        install server using mydomain ${selfns}::server \
            -domain $domain

        # NEXT, register the resources
        $server register /image/{name} {image/(.+)} \
            tk/image [mymethod image_Image] \
            "Image {name} from the help database."

        $server register / {.*?} \
            text/html    [mymethod html_Page]     \
            tcl/linkdict [mymethod linkdict_Page] {
                The page with the given path from the help database.  If
                the {query} is included, then full-text search results will be
                returned.  The search will cover all pages in the database,
                regardless of referenced page.  If tcl/linkdict is requested,
                the result is a tcl/linkdict of the children of the page.
            }

        # NEXT, try to open the helpdb.
        install hdb using sqldocument ${selfns}::hdb \
            -readonly yes

        if {![file exists $options(-helpdb)]} {
            set hdb ""
            return
        }

        $hdb open $options(-helpdb)
    }

    #-------------------------------------------------------------------
    # Content Handlers

    # image_Image udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    #     (1) - image slug.
    #
    # Retrieves and caches the image, returning a tk/image.

    method image_Image {udict matchArray} {
        upvar 1 $matchArray ""

        $self CheckForHelpFile

        set path /[dict get $udict suffix]

        # FIRST, if we have it cached, just return it.
        if {[info exists imageCache($path)]} {
            return $imageCache($path)
        }

        # NEXT, try to retrieve it.
        $hdb eval {
            SELECT data FROM helpdb_images WHERE path=$path
        } {
            set imageCache($path) \
                [image create photo -format png -data $data]

            return $imageCache($path)
        }

        # NEXT, no such image was found.
        return -code error -errorcode NOTFOUND \
            "Image could not be found: [dict get $udict url]"
    }

    # html_Page udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    # Retrieves the page.

    method html_Page {udict matchArray} {
        upvar 1 $matchArray ""

        $self CheckForHelpFile

        # FIRST, handle queries
        set query [dict get $udict query]

        if {$query ne ""} {
            return [$self html_Search $udict]
        }

        # NEXT, return the page.
        set path /[dict get $udict suffix]

        $hdb eval {
            SELECT title, alias, text FROM helpdb_pages WHERE path=$path
        } {
            if {$alias ne ""} {
                set text [$hdb onecolumn {
                    SELECT text FROM helpdb_pages WHERE path=$alias
                }]
            }

            return [$self html_Wrap $udict $title $text]
        }

        # NEXT, no such page was found.
        return -code error -errorcode NOTFOUND \
            "Help page not found: [dict get $udict url]"
    }

    # html_Search udict
    #
    # udict   - A dictionary containing the URL components.
    #
    # Retrieves the search results.

    method html_Search {udict} {
        $self CheckForHelpFile

        set query [dict get $udict query]
        set host [dict get $udict host]

        # FIRST, is the query a page title?
        $hdb eval {
            SELECT title, text
            FROM helpdb_pages 
            WHERE lower(title)=lower($query)
        } {
            return [$self html_Wrap $udict $title $text]
        }


        # NEXT, do full text search
        set code [catch {
            set found [$hdb eval {
                SELECT path, 
                       title,
                       snippet(helpdb_search) AS snippet
                FROM helpdb_search
                WHERE text MATCH $query
                ORDER BY title COLLATE NOCASE;
            }]
        } result]

        if {$code} {
            return -code error -errorcode NOTFOUND \
                "Error in search term: \"$query\""
        }

        if {[llength $found] == 0} {
            set out "<b>No pages match '<code>$query</code>'.</b>"
        } else {
            set out "<b>Search results for '$query':</b><p>\n<dl>\n"

            foreach {path title snippet} $found {
                if {$host eq ""} {
                    set url $path
                } else {
                    set url "my://$host$path"
                }

                append out "<dt><a href=\"$url\">$title</a></dt>\n"
                append out "<dd>$snippet<p></dd>\n\n"
            }

            append out "</dl>\n"
        }

        return [$self html_Wrap $udict "Search" $out]
    }

    # html_Wrap udict title text
    #
    # udict    - A dictionary containing the URL components.
    # title    - The page's title
    # text     - The page's HTML text
    #
    # Wraps the page text in the normal HTML boilerplate, including
    # the result of calling the -headercmd.

    method html_Wrap {udict title text} {
        set out "<html><head><title>$title</title></head>"
        append out "<body>\n"

        append out [callwith $options(-headercmd) $udict]

        append out "$text\n"

        append out "</body>\n</html>"

        return $out
    }

    # linkdict_Page udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    # Retrieves a linkdict for the page's children.  Queries are
    # ignored.

    method linkdict_Page {udict matchArray} {
        upvar 1 $matchArray ""

        $self CheckForHelpFile

        set parent /[dict get $udict suffix]

        if {![$hdb exists {
            SELECT * FROM helpdb_pages WHERE path=$parent
        }]} {
            return -code error -errorcode NOTFOUND \
                "Help page not found: [dict get $udict url]"
        }

        set result [dict create]

        $hdb eval {
            SELECT path, title, leaf
            FROM helpdb_pages
            WHERE parent=$parent
            ORDER BY rowid
        } {
            if {$leaf} {
                set icon ::marsgui::icon::page12
            } else {
                set icon ::marsgui::icon::folder12
            }

            dict set result [$server domain]/$path label $title
            dict set result [$server domain]/$path listIcon $icon
        }

        return $result
    }

    # CheckForHelpFile
    #
    # Returns an error if there's no hdb.

    method CheckForHelpFile {} {
        if {$hdb eq ""} {
            return -code error -errorcode NOTFOUND \
                "Help DB not found: \"$options(-helpdb)\""
        }
    }


    #-------------------------------------------------------------------
    # Public Methods

    delegate method ctypes    to server
    delegate method domain    to server
    delegate method get       to server
    delegate method resources to server
}

