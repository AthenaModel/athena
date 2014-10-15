#-----------------------------------------------------------------------
# TITLE:
#    appserver.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n): myserver(i) Server
#
#    This is an object that presents a unified view of the data resources
#    in the application, and consequently abstracts away the details of
#    the RDB.  The intent is to provide a RESTful interface to the 
#    application data to support browsing (and, possibly,
#    editing as well).
#
#    The content is provided by the appserver_*.tcl modules; this module
#    creates and configures the myserver(n) and provides tools to the
#    other modules.
#
# URLs:
#
#    Resources are identified by URLs, as in a web server, using the
#    "my://" scheme.  This server is registered as "app", so that it
#    can be queried using "my://app/...".  However, it is also the
#    default server, so "//app" can be omitted.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# server singleton

snit::type appserver {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Components

    typecomponent server   ;# The myserver(n) instance.

    #-------------------------------------------------------------------
    # Type Variables

    # minfo array: Module Info
    #
    # names  - List of the names of the defined appserver modules.

    typevariable minfo -array {
        names {}
    }

    # Image Cache
    # 
    # Image files loaded from disk are cached as Tk images in the 
    # imageCache array by [appfile:image].  The keys are image file URLs; 
    # the values are pairs, Tk image name and [file mtime].

    typevariable imageCache -array {}

    #-------------------------------------------------------------------
    # Submodule Interface

    # module name defscript
    # 
    # name      - Fully-qualified command name of an appserver module.
    # defscript - snit::type definition body.
    #
    # Defines the module as a snit::type in the appserver:: namespace,
    # and registers it so that it will get initialized at the right time.

    typemethod module {name defscript} {
        # FIRST, define the type.
        set header {
            # Make it a singleton
            pragma -hasinstances no

            # Allow module to use procs from ::appserver::
            typeconstructor {
                namespace path [list [namespace parent $type]]
            }
        }

        set fullname ${type}::${name}
        snit::type $fullname "$header\n$defscript"

        # NEXT, save the metadata
        ladd minfo(names) $fullname
    
        return
    }

    #-------------------------------------------------------------------
    # Public methods

    delegate typemethod * to server

    # init
    #
    # Creates the myserver, and registers all of the resource types.

    typemethod init {} {
        # FIRST, create the server
        set server [myserver ${type}::server -logcmd ::log]

        # NEXT, create the buffer for generating HTML.
        htools ${type}::ht \
            -rdb       ::rdb              \
            -footercmd [myproc FooterCmd]

        # NEXT, register resource types from submodules.
        foreach name [lsort $minfo(names)] {
            $name init
        }


        # NEXT, add test handler
        $type register /test {test/?} \
            text/html [myproc /test:html] { Test URL }
    
        $type register /test/hello {test/hello/?} \
            tk/widget [myproc /test/hello:widget] { Test widget }
    
    }


    # /test/hello:widget
    proc /test/hello:widget {udict matchArray} {
        list ::label %W -text "Hello!" -background red
    }

    # /test:html
    #
    # Test routine; creates an HTML form, with widgets.

    proc /test:html {udict matchArray} {
        ht page "Test Page" {
            ht title "Test Page"

            ht subtitle "Time Series Plot"
            ht object plot/time?vars=sat.peonu.aut,sat.peonu.cul,sat.peonu.qol,sat.peonu.sft,mood.peonu+start=2+end=7 \
                -width  100% \
                -height 4in
            ht para
            ht putln "Some more text."
            ht subtitle "A Label Widget"
            ht object test/hello \
                -width  100% \
                -height 2in
            ht para
        }

        return [ht get]
    }

    #===================================================================
    # Content Routines
    #
    # The following code relates to particular resources or kinds
    # of content.

    # FooterCmd
    #
    # Standard Page Footer

    proc FooterCmd {} {
        ht putln <p>
        ht putln <hr>
        ht putln "<font size=2><i>"

        if {[sim state] eq "PREP"} {
            ht put "Scenario is unlocked."
        } else {
            ht put [format "Simulation time: Week %04d, %s." \
                      [simclock now] [simclock asString]]
        }

        ht put [format " -- Wall Clock: %s" [clock format [clock seconds]]]

        ht put "</i></font>"
    }


    #-------------------------------------------------------------------
    # Content Handlers
    #
    # The following routines are full-fledged content handlers.  
    # Server modules may register them as content handlers using the
    # [asproc] call.
    
    # enum:enumlist enum udict matchArray
    #
    # enum  - An enum(n), or any command with a "names" subcommand.
    # 
    # Returns the "names" for an enum type (or equivalent).

    proc enum:enumlist {enum udict matchArray} {
        return [{*}$enum names]
    }

    # enum:enumdict enum udict matchArray
    #
    # enum  - An enum(n), or any command with "names" and "longnames"
    #         subcommands.
    # 
    # Returns the names/longnames dictionary for an enum type (or equivalent).

    proc enum:enumdict {enum udict matchArray} {
        foreach short [{*}$enum names] long [{*}$enum longnames] {
            lappend result $short $long
        }

        return $result
    }

    # type:html title command udict matchArray
    # 
    # Returns the HTML documentation for any type command with an
    # "html" subtype, adding a title.

    proc type:html {title command udict matchArray} {
        ht page $title {
            ht title $title
            ht putln [{*}$command html]
        }

        return [ht get]
    }

    #-------------------------------------------------------------------
    # Handler API
    #
    # These commands are defined for use within URL handlers.

    # asproc command....
    # 
    # command   - A command or command prefix, optionally with arguments
    #
    # Returns the command and its arguments with the command name fully
    # qualified as being defined in this type.  This makes it easy for
    # appserver modules to use handlers defined herein.
    
    proc asproc {args} {
        return [myproc {*}$args]
    }

    # appfile:image path...
    #
    # path  - One or more path components, rooted at the appdir.
    #
    # Retrieves and caches the file, returning a tk/image.

    proc appfile:image {args} {
        # FIRST, get the full file path.
        set fullname [GetAppDirFile {*}$args]

        # NEXT, see if we have it cached.
        if {[info exists imageCache($fullname)]} {
            lassign $imageCache($fullname) img mtime

            # FIRST, If the file exists and is unchanged, 
            # return the cached value.
            if {![catch {file mtime $fullname} newMtime] &&
                $newMtime == $mtime
            } {
                return $img
            }
            
            # NEXT, Otherwise, clear the cache.
            unset imageCache($fullname)
        }


        if {[catch {
            set mtime [file mtime $fullname]
            set img   [image create photo -file $fullname]
        } result]} {
            return -code error -errorcode NOTFOUND \
                "Image file could not be found: $(1)"
        }

        set imageCache($fullname) [list $img $mtime]

        return $img
    }

    # appfile:text path...
    #
    # path  - One or more path components, rooted at the appdir.
    #
    # Retrieves the content of the file, or throws NOTFOUND.

    proc appfile:text {args} {
        set fullname [GetAppDirFile {*}$args]

        if {[catch {
            set content [readfile $fullname]
        } result]} {
            return -code error -errorcode NOTFOUND \
                "Page could not be found: $(1)"
        }

        return $content
    }


    # GetAppDirFile path...
    #
    # path  - One or more path components, rooted at the appdir.
    #
    # Gets the full, normalized file name, and verifies that it's
    # within the appdir.  If it is, returns the name; if not, it
    # throws NOTFOUND.

    proc GetAppDirFile {args} {
        set fullname [file normalize [appdir join {*}$args]]

        if {[string first [appdir join] $fullname] != 0} {
            return -code error -errorcode NOTFOUND \
                "Page could not be found: $file"
        }

        return $fullname
    }
    
    # locked ?-disclaimer?
    #
    # -disclaimer  - Put a disclaimer, if option is given
    #
    # Returns whether or not the simulation is locked; optionally,
    # adds a disclaimer to the output.

    proc locked {{option ""}} {
        if {[sim locked]} {
            return 1
        } else {
            if {$option ne ""} {
                ht putln ""
                ht tinyi {
                    More information will be available once the scenario has
                    been locked.
                }
                ht para
            }

            return 0
        }
    }

    # objects:linkdict odict
    # 
    # odict - Object type dictionary
    #
    # Returns a tcl/linkdict for a collection resource, based on an RDB 
    # table and other data from the object type dictionary, which must
    # have the following fields:
    #
    # label    - Human-readable label for this kind of object
    # listIcon - A Tk icon to use in lists and trees next to the label
    # table    - The table or view containing the objects
    #
    # The table or view must define columns "url" and "fancy".

    proc objects:linkdict {odict} {
        set result [dict create]

        dict with odict {
            rdb eval "
                SELECT url, fancy
                FROM $table 
                ORDER BY fancy
            " {
                dict set result $url \
                    [dict create label $fancy listIcon $listIcon]
            }
        }

        return $result
    }

    # querydict udict parms
    #
    # udict  - A URL dictionary, as passed to a handler
    # parms  - A list of parameter names
    #
    # Uses urlquery todict to parse the udict's query, and returns
    # the resulting dictionary.  Only the listed parms will be
    # included; and listed parms which do not appear in the query
    # will have empty values.
    #
    # TBD: Use [urlquery get] instead.

    proc querydict {udict parms} {
        # FIRST, parse the query.
        set in [urlquery todict [dict get $udict query]]

        # NEXT, build the output.
        set out [dict create]

        foreach p $parms {
            if {[dict exists $in $p]} {
                dict set out $p [dict get $in $p]
            } else {
                dict set out $p ""
            }
        }

        return $out
    }
}




