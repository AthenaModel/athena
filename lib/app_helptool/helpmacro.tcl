#-----------------------------------------------------------------------
# TITLE:
#    helpmacro.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_helptool(n): ehtml(5) macro set
#
#    This module contains the ehtml(5) macro definitions needed by the
#    help compiler, and manages the page metadata.
#
#-----------------------------------------------------------------------

snit::type helpmacro {
    #-------------------------------------------------------------------
    # Type Variables

    # pageInfo -- Array of info about the page being expanded.
    typevariable pageInfo -array {}

    # itemCounter: Counts items in tabular lists
    typevariable itemCounter 0 

    #-------------------------------------------------------------------
    # Public Methods

    # install macro
    #
    # macro - The macro(n) instance
    #
    # Installs the macros in the macro(n) instance, and resets transient
    # data.

    typemethod install {macro} {
        # Aliases
        $macro smartalias pageinfo 1 1 {field} \
            [myproc pageinfo]

        $macro smartalias anchor 2 2 {id title} \
            [myproc anchor]

        $macro smartalias cref 1 2 {url ?text?} \
            [myproc cref]

        $macro smartalias childlinks 0 1 {?parent?} \
            [myproc childlinks]

        $macro smartalias children 0 1 {?parent?} \
            [myproc children]

        $macro smartalias enumdoc 1 1 {enum} \
            [myproc enumdoc]

        $macro smartalias footer 0 0 {} \
            [myproc footer]

        $macro smartalias image 1 2 {slug ?align?} \
            [myproc image]

        $macro smartalias itemlist 0 0 {} \
            [myproc itemlist]

        $macro smartalias item 1 1 {label} \
            [myproc item]

        $macro smartalias /item 0 0 {} \
            [myproc /item]

        $macro smartalias /itemlist 0 0 {} \
            [myproc /itemlist]

        $macro smartalias optionlist 0 0 {} \
            [myproc optionlist]

        $macro smartalias option 1 1 {name} \
            [myproc option]

        $macro smartalias /option 0 0 {} \
            [myproc /option]

        $macro smartalias /optionlist 0 0 {} \
            [myproc /optionlist]

        $macro smartalias parmlist 0 2 {?h1? ?h2?} \
            [myproc parmlist]

        $macro smartalias parm 2 2 {parm field} \
            [myproc parm]

        $macro smartalias /parm 0 0 {} \
            [myproc /parm]

        $macro smartalias /parmlist 0 0 {} \
            [myproc /parmlist]

        $macro smartalias version 0 0 {} \
            [list project version]
    }

    # setinfo dict
    #
    # dict   - A dictionary of page info
    #
    # Saves it for use by macros.

    typemethod setinfo {dict} {
        array unset pageInfo
        array set pageInfo $dict
        return
    }

    #-------------------------------------------------------------------
    # Macro Definitions    

    # pageinfo field
    #
    # field   - name|title|parent
    #
    # Returns information about the page currently being expanded.

    proc pageinfo {field} {
        return $pageInfo($field)
    }

    # anchor id title
    #
    # Creates a linkable title in the body of a page.

    proc anchor {id title} {
        return "<a name=\"$id\">$title</a>" 
    }

    # cref pathref ?text?
    #
    # pathref  - A page path, path?#anchor?
    # text     - The link text.  Defaults to the page title.
    #
    # Cross-reference link to the named page.

    proc cref {pathref {text ""}} {
        lassign [split $pathref "#"] path anchor

        require {$path ne ""} "url has no page path: \"$pathref\""

        if {[app page exists $path]} {
            set url [app page url $path]
            if {$text eq ""} {
                set text [app page title $path]
            }
        } else {
            set url $pathref
            if {$text eq ""} {
                set text $path
            }

            set text "{TBD: $text}"

            puts "On \"[pageinfo path]\", broken link to: \"$path\""
        }

        return "<a href=\"$url\">$text</a>"
    }

    # childlinks ?parent?
    #
    # parent - A parent path
    #
    # Returns a <ul>...</ul> list of links to the children of the
    # page with the given path.  Defaults to the current page.

    proc childlinks {{parent ""}} {
        # FIRST, get the parent name.
        if {$parent eq ""} {
            set parent $pageInfo(path)
        }

        # NEXT, get the children
        set out "<ul>\n"

        hdb eval {
            SELECT url, title 
            FROM helpdb_pages 
            WHERE parent=$parent
        } {
            append out "<li> <a href=\"$url\">$title</a>\n"
        }

        append out "</ul>\n"

        return $out
    }

    # children ?parent?
    #
    # parent - A parent path
    #
    # Returns a dictionary of page titles by page paths for the
    # children of parent, which defaults to the current page.

    proc children {{parent ""}} {
        # FIRST, get the parent name.
        if {$parent eq ""} {
            set parent $pageInfo(path)
        }

        # NEXT, get the children
        return [hdb eval {
            SELECT path, title 
            FROM helpdb_pages 
            WHERE parent=$parent
        }]
    }


    # image slug ?align?
    #
    # slug    - An image slug
    # align   - Alignment, left | center | right; default is no alignment
    #
    # Adds <img> tag

    proc image {slug {align ""}} {
        set path /image/$slug
        set url $path.png

        if {![app image exists $path]} {
            puts "On \"[pageinfo path]\", broken link to image: \"$path\""

            return "<a href=\"$url\">{TBD: $url}</a>"
        }

        if {$align eq ""} {
            return "<img src=\"$url\">"
        } else {
            return "<img src=\"$url\" align=\"$align\">"
        }
    }

    # footer
    #
    # The page footer.

    proc footer {} {
        set tstamp [clock format [clock seconds]]

        return [outdent "
            <p>
            <hr>
            <i><font size=2>Help compiled $tstamp</font></i>
        "]
    }

    # enumdoc enum
    #
    # enum   - An enum(n) type.
    #
    # The built-in enum(n) "html" method produces bad results for this use.
    # This is an alternate that looks nicer.

    template proc enumdoc {enum} {
        set names [{*}$enum names]
    } {
        |<--
        <table border="0" cellspacing=0>
        <tr><th align="left">Symbol&nbsp;</th><th align="left">Meaning</th></tr>
        [tforeach name $names {
            |<--
            <tr>
            <td><tt>$name</tt>&nbsp;</td>
            <td>[{*}$enum longname $name]</td>
            </tr>
        }]
        </table><p>
    }


    # parmlist  ?h1 ?h2?
    #
    # h1    - Header for column 1; defaults to Field
    # h2    - Header for column 2; defaults to Description
    #
    # Begins a list of order parameters

    template proc parmlist {{h1 Field} {h2 Description}} {
        set itemCounter 0
    } {
        |<--
        <table class="pretty" width="100%" cellpadding="5"> 
        <tr class="header">
        <th align="left">$h1</th> 
        <th align="left">$h2</th>
        </tr>
    }

    # parm parm field
    #
    # parm     - The order parameter name
    # field    - The field label
    #
    # Begins a parameter description.

    template proc parm {parm field} {
        if {[incr itemCounter] % 2 == 0} {
            set rowclass evenrow
        } else {
            set rowclass oddrow
        }
    } {
        |<--
        <tr class="$rowclass" valign="baseline">
        <td style="white-space: nowrap"><b>$field</b><br>(<tt>$parm</tt>)</td>
        <td>
    }

    # /parm
    #
    # Ends a parameter description
    template proc /parm {} {
        </td>
        </tr>
    }

    # /parmlist
    #
    # Ends a list of order parameters
    template proc /parmlist {} {
        |<--
        </table><p>
    }

    # optionlist
    #
    # Begins a list of command options.

    template proc optionlist {} {
        set itemCounter 0
    } {
        |<--
        <table class="pretty" width="100%" cellpadding="5"> 
        <tr class="header">
        <th align="left">Option</th> 
        <th align="left">Description</th>
        </tr>
    }

    # option name
    #
    # name   - The option name
    #
    # Begins an option description.

    template proc option {name} {
        if {[incr itemCounter] % 2 == 0} {
            set rowclass evenrow
        } else {
            set rowclass oddrow
        }
    } {
        |<--
        <tr class="$rowclass" valign="baseline">
        <td style="white-space: nowrap"><b><code>$name</code></b></td>
        <td>
    }

    # /option
    #
    # Ends an option description
    template proc /option {} {
        </td>
        </tr>
    }

    # /optionlist
    #
    # Ends a list of command options
    template proc /optionlist {} {
        |<--
        </table><p>
    }

    # itemlist
    #
    # Begins a table of labeled items

    template proc itemlist {} {
        |<--
        <table border="0" cellspacing="0" cellpadding="4"> 
    }

    # item label
    #
    # label    - The item label
    #
    # Begins a labeled item, and formats the item label.

    template proc item {label} {
        |<--
        <tr valign="baseline">
        <td><b>$label</b></td>
        <td>
    }

    # /item
    #
    # Ends an item
    template proc /item {} {
        </td>
        </tr>
    }

    # /itemlist
    #
    # Ends a list of items
    template proc /itemlist {} {
        |<--
        </table><p>
    }

}