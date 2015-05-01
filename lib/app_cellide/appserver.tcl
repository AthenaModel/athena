#-----------------------------------------------------------------------
# TITLE:
#    appserver.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_cellide(n): mydomain(i) Server
#
#    This is an object that presents a unified view of the data resources
#    in the application, and consequently abstracts away the details of
#    the RDB.  The intent is to provide a RESTful interface to the 
#    application data to support browsing (and, possibly,
#    editing as well).
#
# URLs:
#
#    Resources are identified by URLs, as in a web server, using the
#    "/" scheme.  This server is registered as "app", so that it
#    can be queried using "/app/...".  However, it is also the
#    default server, so "//app" can be omitted.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# server singleton

snit::type appserver {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Look-up Tables

    typevariable linkInfo {
        /app/pages {
            label "Pages"
            listIcon ::marsgui::icon::folder12
        }
    }

    #-------------------------------------------------------------------
    # Type Components

    typecomponent server   ;# The mydomain(n) instance.

    #-------------------------------------------------------------------
    # Public methods

    delegate typemethod * to server

    # init
    #
    # Creates the mydomain, and registers all of the resource types.

    typemethod init {} {
        # FIRST, create the server
        set server [mydomain ${type}::server -domain /app]

        # NEXT, create the buffer for generating HTML.
        htools ${type}::ht \
            -rdb       ::rdb              \
            -headercmd [myproc HeaderCmd] \
            -footercmd [myproc FooterCmd]

        # NEXT, register the resource types
        appserver register / {/?} \
            text/html [myproc /:html] \
            "Model Overview"
        
        appserver register /cell/{c} {cell/([[:alnum:]_.:]+)} \
            text/html [myproc /cell:html]           \
            "Detail page for cell model cell {c}."

        appserver register /enum/snapshots {enum/snapshots}                   \
            tcl/enumdict [myproc /enum/snapshots:enumdict]                    \
            "Enumeration: Snapshots"

        appserver register /enum/sortcellby {enum/sortcellby}                 \
            tcl/enumlist [asproc enum:enumlist esortcellby]                   \
            tcl/enumdict [asproc enum:enumdict esortcellby]                   \
            text/html    [asproc type:html "Enum: Sort Cells By" esortcellby] \
            "Enumeration: Sort Cells By"

        appserver register /links {links/?}               \
            tcl/linkdict [myproc /links:linkdict]       \
            "Top-level application links."

        appserver register /pages {pages/?}     \
            tcl/linkdict [myproc /pages:linkdict]  \
            text/html    [myproc /pages:html]  \
            "Page links"

        appserver register /page/{p} {page/(\w+)/?} \
            tcl/linkdict [myproc /page:linkdict]    \
            text/html    [myproc /page:html]        \
            "Detail page for cell model page {p}."
    }

    #-------------------------------------------------------------------
    # /:    Model overview page
    #
    # No match parameters

    # /:html udict matchArray
    #
    # Formats and displays the overview page.

    proc /:html {udict matchArray} {
        ht page "Model Overview"
        ht title "Model Overview"

        # FIRST, Has the model been checked?
        set code [cmscript checkstate]

        if {$code eq "unchecked"} {
            ht putln {
                The cell model has not yet been checked.
                Select the "Check" or "Solve" buttons on the
                toolbar.
            }
        }

        # NEXT, handle syntax errors
        if {$code eq "syntax"} {
            set errmsg [dict get [cmscript checkinfo] msg]
            set line [dict get [cmscript checkinfo] line]

            ht putln "The cell model has a syntax error at line "
            ht link gui:/editor/$line $line
            ht put ":"
            ht para
            ht putln "<b>$errmsg</b>"
            ht para
            ht putln "The error must be fixed before further analysis"
            ht putln "is possible."
            ht para
            ht /page

            return [ht get]
        }
        
        if {$code eq "checked"} {
            ht putln "The cell model is sane, and contains the following pages:"
            ht para

            PageTable
        } else {
            ht putln "The cell model is insane."
            ht para
        }


        # Referenced but not defined.
        if {[llength [cm cells unknown]] > 0} {
            ht subtitle "Missing Cells"

            ht putln "The following cells are referenced but not defined:"
            ht para

            ht ul {
                foreach cell [cm cells unknown] {
                    set refcount [llength [cm cellinfo usedby $cell]]
                    
                    ht li {
                        ht putln [format "%03d times: <b>%s</b>" $refcount $cell]
                    }
                }
            }
        }

        # Cells with serious errors
        # TBD: add dl/dd/dt to htools

        if {[llength [cm cells invalid]] > 0} {
            ht subtitle "Invalid Cells"

            ht putln "The following cells have serious errors:"
            ht para

            foreach cell [cm cells invalid] {
                set line [cm cellinfo line $cell]

                ht link /app/cell/$cell $cell
                ht put " (Line "
                ht link gui:/editor/$line $line
                ht put ")"
                ht put " = "
                ht put [normalize [FormulaWithLinks $cell]]
                ht para 

                ht ul {
                    foreach message [CellErrors $cell] {
                        ht li {
                            ht put $message
                        }
                    }
                }

                ht para
            }
        }

        # FINALLY, complete the page
        ht /page

        return [ht get]
    }

    # OverviewSane:html
    #
    # Outputs an overview of a sane cell model

    proc OverviewSane:html {} {
        ht putln "The model contains the following pages:"
        ht para

    }

    #-------------------------------------------------------------------
    # /cell/{c}:    Model page details
    #
    # {c} => $(1)  - The cell name

    # /cell:html udict matchArray
    #
    # Formats and displays the details for a particular model cell.

    proc /cell:html {udict matchArray} {
        upvar 1 $matchArray ""

        set cell $(1)

        if {$cell ni [cm cells]} {
            if {[cmscript checkstate] in {unchecked syntax}} {
                ht page "Model Cell: $cell" {}
                return [ht get]
            }

            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        ht page "Model Cell: $cell"
        ht putln "<h1>Model Cell: "

        set page [cm cellinfo page $cell]
        set bare [cm cellinfo bare $cell]

        if {$page ne "null"} {
            ht link /app/page/$page "${page}::" 
        }

        ht put $bare
        ht put "</h1>"

        ht putln "All values shown are from the text of the model."
        ht para

        # NEXT, put in the cell itself.
        ht subtitle "Definition"

        ht table {"Line#" "Value" "Formula"} {
            ht tr valign top {
                ht td right {
                    set line [cm cellinfo line $cell]
                    ht link gui:/editor/$line $line
                }
                ht td left { ht put [cm value $cell] }
                ht td left {
                    ht put <code>
                    ht put [FormulaWithLinks $cell] 
                    ht put </code>
                }
            }
        }
        
        ht para

        # NEXT, put in errors.
        if {$cell in [cm cells invalid]} {
            ht subtitle "Errors in definition:"

            ht ul {
                foreach message [CellErrors $cell] {
                    ht li {
                        ht put $message
                    }
                }
            }
        }

        # NEXT, put in dependencies.
        if {[llength [cm cellinfo uses $cell]] > 0} {
            ht subtitle "$cell uses these cells:"
            CellTable [cm cellinfo uses $cell] model $page
            ht para
        }

        if {[llength [cm cellinfo usedby $cell]] > 0} {
            ht subtitle "$cell is used by these cells:"
            CellTable [cm cellinfo usedby $cell] model $page
            ht para
        }

        # NEXT, do cells with this name appear on other pages.
        set cells [list]
        foreach p [cm pages] {
            if {$p eq $page} {
                continue
            }

            set pcell ${p}::$bare

            set pcells [cm cells $p]

            if {$pcell in [cm cells $p]} {
                lappend cells $pcell
            }
        }

        if {[llength $cells] > 0} {
            ht subtitle "Cells with the same name on other pages:"
            CellTable $cells model 
            ht para
        }

        # FINALLY, complete the page
        ht /page

        return [ht get]
    }


    #-------------------------------------------------------------------
    # /enum/snapshots:    Enumeration
    #
    # No match parameters

    # /enum/snapshots:enumdict udict matchArray
    #
    # Returns the snapshots EnumDict.

    proc /enum/snapshots:enumdict {udict matchArray} {
        return [snapshot namedict]
    }

    #-------------------------------------------------------------------
    # /links                 - All link types
    #
    # Match Parameters: None

    # /links:linkdict udict matchArray
    #
    # Returns a /links resource as a tcl/linkdict.

    proc /links:linkdict {udict matchArray} {
        return $linkInfo
    }

    #-------------------------------------------------------------------
    # /pages                 - All page links
    #
    # Match Parameters: None

    # /pages:linkdict udict matchArray
    #
    # Returns a /pages resource as a tcl/linkdict.

    proc /pages:linkdict {udict matchArray} {
        if {[cmscript checkstate] in {unchecked syntax}} {
            return
        }

        set result [dict create]
        foreach page [cm pages] {
            dict set result /app/page/$page \
                label $page 

            dict set result /app/page/$page \
                listIcon ::marsgui::icon::folder12 
        }

        return $result
    }

    # /pages:html udict matchArray
    #
    # Formats and displays the pages index.

    proc /pages:html {udict matchArray} {
        ht page "Model Pages"
        ht title "Model Pages"

        PageTable

        # FINALLY, complete the page
        ht /page

        return [ht get]
    }
    #-------------------------------------------------------------------
    # /page/{p}:    Model page details
    #
    # {p} => $(1)  - The page name

    # /page:linkdict udict matchArray
    #
    # Links to the cells on the page.

    proc /page:linkdict {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the page
        set page $(1)

        if {$page ni [cm pages]} {
            if {[cmscript checkstate] in {unchecked syntax}} {
                return
            }
            
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }
   
        foreach cell [lsort -dictionary [cm cells $page]] {
            dict set result /app/cell/$cell \
                label $cell 

            dict set result /app/cell/$cell \
                listIcon ::marsgui::icon::page12 
        }

        return $result
    }

    # /page:html udict matchArray
    #
    # Formats and displays the details for a particular model page.
    #
    # The udict query is a "parm=value[+parm=value]" string with the
    # following parameters:
    #
    #    sortby - The column to sort the cells by: one of line, name.
    #
    # Unknown query parameters and invalid query values are ignored.

    proc /page:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the page
        set page $(1)

        if {$page ni [cm pages]} {
            if {[cmscript checkstate] in {unchecked syntax}} {
                # Show the error, which will describe the status.
                ht page "Model Page: $page" {}
                return [ht get]
            }
            
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        # NEXT, get the query parameters
        set qdict [querydict $udict {snapshot sortby}]
        dict with qdict {
            restrict snapshot snapshot current
            restrict sortby esortcellby name
        }

        # NEXT, format the output
        ht page "Model Page: $page"
        ht title "Model Page: $page"

        ht hr
        ht form -autosubmit yes
        ht label snapshot "Values From:"
        ht input snapshot enum $snapshot \
            -content tcl/enumdict        \
            -src     enum/snapshots
        ht label sortby "Sort Cells By:"
        ht input sortby enum $sortby \
            -content tcl/enumdict    \
            -src     enum/sortcellby 
        ht /form
        ht hr
        ht para

        if {[cm sane]} {
            ht putln "<b>$page</b> is a [Cyclic $page] containing"
        } else {
            ht putln "It is unknown whether <b>$page</b> is cyclic or acyclic; "
            ht put "this cannot be checked until the model is sane."

            ht para
            ht putln "<b>$page</b> contains"
        }

        set pline [cm pageinfo pline $page]
        ht put " [llength [cm cells $page]] cells."
        ht putln "It is defined starting at line "
        ht link gui:/editor/$pline $pline
        ht putln "in the cell model file."
        ht para

        set cells [cm cells $page]

        if {$sortby eq "name"} {
            set cells [lsort -dictionary $cells]
        }

        CellTable $cells $snapshot $page

        # FINALLY, complete the page
        ht /page

        return [ht get]
    }

    #===================================================================
    # Other Content Routines
    #
    # The following code relates to particular resources or kinds
    # of content.

    # Cyclic page
    #
    # Returns "Cyclic", "Acyclic", or "Not Sane".

    proc Cyclic {page} {
        if {![cm sane]} {
            return "Not Sane"
        } elseif {[cm pageinfo cyclic $page]} {
            return "Cyclic"
        } else {
            return "Acyclic"
        }
    }

    # PageTable
    #
    # Formats a table of the pages in the model.

    proc PageTable {} {
        if {[cmscript checkstate] in {unchecked syntax}} {
            ht putln "No pages defined."
            return
        } 

        ht table {"Line" "Page" "# of Cells" "Cyclic?"} {
            foreach page [cm pages] {
                set pcount [llength [cm cells $page]]

                ht tr {
                    ht td right {
                        set line [cm pageinfo pline $page]
                        ht link gui:/editor/$line $line
                    }
                    ht td left { 
                        ht put <b>
                        ht link /app/page/$page $page
                        ht put </b>
                    }
                    ht td right { ht put $pcount }
                    ht td left  { ht put [Cyclic $page] }
                }
            }
        }

        return
    }


    # CellTable cells snapshot ?page?
    #
    # cells    - List of cells
    # snapshot - Snapshot from which to get cells.
    # page     - Page whose name should be omitted from cell names
    #
    # Adds an HTML table of cell definitions and links to the output.
    # Cells are written with their fully-qualified names unless they
    # are on the named page.

    proc CellTable {cells snapshot {page ""}} {
        array set values [snapshot get $snapshot]

        ht table {"Line#" "Cell" "Value" "Formula"} {
            foreach c $cells {
                # Cell might be undefined
                if {$c ni [cm cells]} {
                    ht tr valign top {
                        ht td right { ht put "n/a" }
                        ht td left  { ht put $c }
                        ht td left  { ht put "n/a" }
                        ht td left  { ht put "Cell is undefined" }
                    }
                    continue
                }

                set bare [cm cellinfo bare $c]

                ht tr valign top {
                    ht td right {
                        set line [cm cellinfo line $c]
                        ht link gui:/editor/$line $line
                    }
                    ht td left {
                        if {[cm cellinfo page $c] ne $page} {
                            ht link /app/cell/$c $c 
                        } else {
                            ht link /app/cell/$c $bare 
                        }

                    }
                    ht td left { 
                        if {![info exists values($c)]} {
                            ht put [cm value $c]
                        } else {
                            ht put $values($c)
                        }
                    }
                    ht td left {
                        ht put <code>
                        ht put [FormulaWithLinks $c] 
                        ht put </code>
                    }
                }
            }
        }

    }

    # CellErrors cell
    #
    # cell   - A cell with errors
    #
    # Returns a list of the error messages.

    proc CellErrors {cell} {
        set out [list]

        if {[cm cellinfo error $cell] ne ""} {
            lappend out [normalize [cm cellinfo error $cell]]
        }

        foreach rcell [cm cellinfo unknown $cell] {
            lappend out "References undefined cell: $rcell"
        }

        foreach rcell [cm cellinfo badpage $cell] {
            lappend out \
                "References cell on later page: <a href=\"/app/cell/$rcell\">$rcell</a>"
        }

        return $out
    }

    # FormulaWithLinks cell ?root?
    #
    # cell   - A fully-qualified cell name
    # root   - Root URL for cell links
    #
    # Returns the cell's formula with cell links.  The cells display
    # as themselves; the link URL is "${root}$cell", allowing the 
    # routine to be used for more than one kind of link.

    proc FormulaWithLinks {cell {root /app/cell/}} {
        # FIRST, if there's no such cell then there's no formula.
        if {$cell ni [cm cells]} {
            return ""
        }

        # NEXT, get this cell's page and formula
        set thisPage [cm cellinfo page $cell]
        set formula  [cm formula $cell]

        # NEXT, build a [string map] table to interpolate the links
        # into the formula:
        #
        # * Cells on the same page appear both with and without their
        #   namespace.
        # * Cells on other pages appear only with their namespace.

        set table [list]
        
        foreach c [cm cellinfo uses $cell] {
            # The cell might be referenced but not defined.
            if {$c ni [cm cells]} {
                continue
            }

            lappend table "\[$c\]" "\[<a href=\"$root$c\">$c</a>\]"

            if {$thisPage ne "null" &&
                [cm cellinfo page $c] eq $thisPage
            } {
                set bare [cm cellinfo bare $c]

                lappend table "\[$bare\]" "\[<a href=\"$root$c\">$bare</a>\]"
            }
        }

        # NEXT, do the mapping, and return the formula
        return [string map $table $formula]
    }

    # HeaderCmd
    #
    # Standard Page Header

    proc HeaderCmd {title} {
        switch -exact -- [cmscript checkstate] {
            unchecked {
                ht putln {
                    <div class="warning">
                    The model text has changed.  Press the Checkmark icon
                    to parse it and check for errors.
                    </div>
                }
            }
            syntax {
                if {$title eq "Model Overview"} {
                    return
                }
                set errdict [cmscript checkinfo]
                dict with errdict {
                    ht putln {<div class="warning">}
                    ht putln "The model contains a syntax error at line "
                    ht link gui:/editor/$line $line
                    ht put ": $msg." 
                    ht putln </div>
                }
            }
            insane {
                if {$title eq "Model Overview"} {
                    return
                }
                ht putln {
                    <div class="warning">
                    The model is not sane as written.  Click on the 
                    Home button on the toolbar to see a list of the 
                    problems.
                    </div>
                }
            }
            default {
                # No problems
                return
            }
        }
    }

    # FooterCmd
    #
    # Standard Page Footer

    proc FooterCmd {} {
        ht putln <p>
        ht putln <hr>
        ht putln "<font size=2><i>"
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



