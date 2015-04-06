#-----------------------------------------------------------------------
# TITLE:
#    htmlbuffer.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectlib(n): HTML generation tools
#
#    Instances of the htmlbuffer type are used to format HTML output.
#    In addition, the type itself provides HTML-related utility commands.
#    This type is a revision and enhancement of the previous htools(n)
#    type, aimed at supporting both internal and external clients
#    (i.e., the mybrowser(n) and actual web browsers).
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export htmlbuffer
}

#-----------------------------------------------------------------------
# htmlbuffer type

snit::type ::projectlib::htmlbuffer {
    #-------------------------------------------------------------------
    # Lookup Tables

    # defaultStyles
    #
    # These styles are put in page headers to support font handling;
    # if -styles or -cssfile are given when the buffer is created,
    # they are not used.

    typemethod defaultStyles {
        
    }
    

    #-------------------------------------------------------------------
    # Type Methods

    # escape text
    #
    # text - Plain text to be included in an HTML page
    #
    # Escapes the &, <, and > characters so that the included text
    # doesn't screw up the formatting.

    typemethod escape {text} {
        return [string map {& &amp; < &lt; > &gt;} $text]
    }

    #-------------------------------------------------------------------
    # Options

    # -cssfile
    #
    # A URL for an external CSS file.  This is useful primarily for
    # external content.

    option -cssfile

    # -domain prefix
    #
    # A domain prefix for iref links produced using this buffer, e.g.,
    # /scenario/base.  All iref links will include this domain as a 
    # prefix.

    option -domain

    # -footercmd
    #
    # A command that returns content for the page footer.

    option -footercmd

    # -headercmd
    #
    # A command that returns content for the page header.

    option -headercmd

    # -styles
    #
    # CSS styles for inclusion in generated pages.

    option -styles

    #-------------------------------------------------------------------
    # Instance Variables

    # Buffer Stack: The htmlbuffer instance maintains a stack of 
    # buffers; it is often convenient to push a buffer onto the stack,
    # generate HTML in that buffer, and then pop it, either retaining
    # or discarding the HTML (e.g., table headers if there is no table
    # content).

    # Stack pointer: index into stack().
    variable sp 0

    # stack: buffer stack
    #
    # $num - Buffer 
    
    variable stack -array {
        0  {}
    }

    

    #-------------------------------------------------------------------
    # Constructor 

    constructor {args} {
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Buffer Management

    # clear
    #
    # Clears the buffer for new stuff.  This is also done by "page".

    method clear {} {
        array unset stack
        set sp 0
        set stack($sp) ""
    }

    # get
    #
    # Get the text in the main buffer.  This is also done by 
    # "/page".

    method get {} {
        return $stack($sp)
    }

    # push
    #
    # Pushes a new buffer on the stack.

    method push {} {
        incr sp
        set stack($sp) ""
    }

    # pop
    #
    # Pops a buffer off of the stack, and returns its contents.

    method pop {} {
        if {$sp <= 0} {
            error "stack underflow"
        }

        set result $stack($sp)
        incr sp -1

        return $result
    }

    # put text...
    #
    # text - One or more text strings
    #
    # Adds the text strings to the buffer, separated by spaces.

    method put {args} {
        append stack($sp) [join $args " "]

        return
    }

    # putln text...
    #
    # text - One or more text strings
    #
    # Adds the text strings to the buffer, separated by spaces,
    # and *preceded* by a newline.

    method putln {args} {
        append stack($sp) \n [join $args " "]

        return
    }

    # tag tag ?options...?
    #
    # options - Tcl-style option list
    #
    # Puts the tag into the buffer, converting the options to attributes.
    # E.g.,
    #
    #    $hb tag td -align left
    #
    # Adds 
    #
    #    <td align="left">

    method tag {tag args} {
        $self put "<$tag"
        $self InsertAttributes $args
        $self put ">"
    }

    # tagln tag ?options...?
    #
    # options - Tcl-style option list
    #
    # Like tag, but begins on a new line.

    method tagln {tag args} {
        $self putln "<$tag"
        $self InsertAttributes $args
        $self put ">"
    }

    # wrap tag text ?options...?
    #
    # options - Tcl-style option list
    #
    # Puts the tag into the buffer, wrapping the given text, and 
    # converting the options to attributes.  E.g., 
    # 
    #    $hb wrap title "My Title"
    #
    # generates
    #
    #    <title>My Title</title>

    method wrap {tag text args} {
        $self tag $tag $args
        $self put $text
        $self put </$tag>
    }

    # wrapln tag text ?options...?
    #
    # options - Tcl-style option list
    #
    # Like wrap, but begins on a new line.

    method wrapln {tag text args} {
        $self tag $tag $args
        $self put $text
        $self put </$tag>
    }

    # putif expr then ?else?
    #
    # expr   - An expression
    # then   - A string
    # else   - A string, defaults to ""
    #
    # If expr, puts then, otherwise puts else.

    method putif {expr then {else ""}} {
        if {[uplevel 1 [list expr $expr]]} {
            $self put $then
        } else {
            $self put $else
        }
    }

    #-------------------------------------------------------------------
    # Page Management

    # page title ?options? ?body?
    #
    # title   - Title of HTML page
    # options - Options for the <body> tag
    # body    - A body script
    #
    # Adds the standard HTML header boilerplate and clears the
    # buffer stack.  The page <title> is set as given, but no
    # title is written to the body of the page.
    # If the body is given, it is executed and the /page
    # footer is added automatically.
    #
    # If the buffer -styles option is set, a <styles> clause is added to 
    # the <head>.
    #
    # If the buffer -cssfile option is set, a <link> to the CSS file is 
    # added to the <head>.
    #
    # If neither -styles nor -cssfile are given, module-specific styles
    # are added.
    #
    # If the buffer -headercmd option is set, it is passed the buffer 
    # and the title.  Any output will appear after the <body> tag.
    #
    # Any options passed to the command are converted into 
    # <body> tag attributes.

    method page {title args} {
        $self clear

        if {[llength $args] % 2 == 1} {
            set body [lpop args]
        } else {
            set body ""
        }

        $self putln <html>
        $self putln <head>
        $self wrapln title $title

        if {$options(-cssfile) ne ""} {
            $self tagln link -rel stylesheet -href $options(-cssfile)
        }

        if {$options(-styles) ne ""} {
            $self wrapln style $options(-styles)
        }

        $self putln </head>
        $self tagln body {*}$args

        callwith $options(-headercmd) $self $title

        if {$body ne ""} {
            uplevel 1 $body
            $self /page
        }
    }

    # /page
    #
    # Adds the standard footer boilerplate, and returns the
    # formatted page.  If -footercmd is given, it is passed
    # the buffer.  Any output will appear just before the </body>
    # tag.

    method /page {} {
        callwith $options(-footercmd) $self

        $self putln </body>
        $self putln </html>

        return [$self get]
    }

    #-------------------------------------------------------------------
    # Headings
    
    # h1 title ?options?
    #
    # title   - A title string
    # options - Attribute options
    #
    # Returns an HTML H1 title.

    method h1 {title args} {
        $self wrapln h1 $title {*}$args
    }

    # h2 title ?options?
    #
    # title   - A title string
    # options - Attribute options
    #
    # Returns an HTML H2 title.

    method h2 {title args} {
        $self wrapln h1 $title {*}$args
    }

    # h3 title ?options?
    #
    # title   - A title string
    # options - Attribute options
    #
    # Returns an HTML H3 title.

    method h3 {title args} {
        $self wrapln h1 $title {*}$args
    }

    # h4 title ?options?
    #
    # title   - A title string
    # options - Attribute options
    #
    # Returns an HTML H4 title.

    method h4 {title args} {
        $self wrapln h4 $title {*}$args
    }

    #-------------------------------------------------------------------
    # Other HTML Tags

    # para
    #
    # Adds a paragraph mark.
    
    method para {} {
        $self put <p> \n
    }

    # br
    #
    # Adds a line break
    
    method br {} {
        $self put <br> \n
    }

    # hr ?options?
    #
    # options   - Attribute options
    #
    # Inserts an <hr> tag.
    
    method hr {args} {
        $self tagln hr {*}$args
    }

    # span ?options? ?text?
    #
    # options   - Attribute options, e.g., -class
    #
    # Creates a <span>.  If text is given, wraps it.

    method span {args} {
        if {[llength $args] %2 == 1} {
            set text [lpop args]
            $self wrap span $text {*}$args
        } else {
            $self tag span {*}$args
        }
    }
   
    # /span
    #
    # Terminates a <span>.

    method /span {} {
        $self put </span>
    }


    #-------------------------------------------------------------------
    # <a href> links

    # href url ?options? label
    #
    # url       - A server-local URL.  Must begin with "/".
    # options   - Attribute options
    # label     - The label to display.
    #
    # Produces an <a href="...">...</a> tag.

    method href {url args} {
        set label [lpop args]

        $self wrap a $label -href $url {*}$args
    }

    # iref suffix ?options? label
    #
    # suffix    - A suffix to add to the -domain to get a server-local
    #             URL.  Must begin with "/".
    # options   - Attribute options
    # label     - The label to display.

    method iref {suffix args} {
        $self href $options(-domain)$suffix {*}$args
    }
    


    #-------------------------------------------------------------------
    # Helper Commands

    # InsertAttributes optlist
    #
    # optlist   - Tcl-style option list
    #
    # Puts the option list into the buffer as HTML attributes.

    method InsertAttributes {optlist} {
        foreach {opt val} $optlist {
            # FIRST, remove the hyphen
            set opt [string trimleft $opt -]

            # NEXT, add the attribute
            $self put " $opt=\"$val\""
        }
    }

    


    #===================================================================
    # NOT PROCESSED YET
    

    #-------------------------------------------------------------------
    # Commands for building up HTML in the buffer






    # query sql ?options...?
    #
    # sql           An SQL query.
    # options       Formatting options
    #
    # -align  codes   - String of column alignments, L,R,C
    # -labels list    - List of column labels
    # -default text   - Text to return if there's no data found.
    #                   Defaults to "No data found.<p>"
    # -escape flag    - If yes, all data returned by the RDB is escaped.
    #                   Defaults to no.
    #
    # Executes the query and accumulates the results as HTML.

    method query {sql args} {
        require {$options(-rdb) ne ""} "No -rdb has been specified."

        # FIRST, get options.
        array set qopts {
            -labels   {}
            -default  "No data found.<p>"
            -align    {}
            -escape   no
        }
        array set qopts $args

        # FIRST, begin the table
        $self push

        # NEXT, if we have labels, use them.
        if {[llength $qopts(-labels)] > 0} {
            $self table $qopts(-labels)
        }

        # NEXT, get the data.  Execute the query as an uplevel,
        # so that we can use variables.
        set qnames {}

        uplevel 1 [list $options(-rdb) eval $sql ::projectlib::htmlbuffer::qrow \
                       [list $self QueryRow]]

        $self /table

        set table [$self pop]

        if {[llength $qnames] == 0} {
            $self putln $qopts(-default)
        } else {
            $self putln $table
        }
    }

    # QueryRow 
    #
    # Builds up the table results

    method QueryRow {} {
        if {[llength $qnames] == 0} {
            set qnames $qrow(*)
            unset qrow(*)

            if {$qopts(-escape)} {
                set qnames [$type escape $qnames]
            }

            if {[$self get] eq ""} {
                $self table $qnames
            }
        }
        
        # If the alignment spec is longer than the number of columns, 
        # trim it down. No need to worry if it's shorter, that's handled
        set alignstr \
            [string range $qopts(-align) 0 [expr {[llength $qnames]-1}]]

        $self tr {
            foreach name $qnames align [split $alignstr ""] {
                if {$qopts(-escape)} {
                    set qrow($name) <code>[$type escape $qrow($name)]</code>
                }

                $self td $alignments($align) {
                    $self put $qrow($name)
                }
            }
        }
    }
    

    #-------------------------------------------------------------------
    # HTML Commands



    # linkbar linkdict
    # 
    # linkdict   - A dictionary of URLs and labels
    #
    # Displays the links in a horizontal bar.

    method linkbar {linkdict} {
        $self hr
        set count 0

        foreach {link label} $linkdict {
            if {$count > 0} {
               $self put " | "
            }

            $self link $link $label

            incr count
        }

        $self hr
        $self para
    }

    # tiny text
    #
    # text - A text string
    #
    # Sets the text in tiny font.

    method tiny {text} {
        $self put "<font size=2>$text</font>"
    }

    # tinyb text
    #
    # text - A text string
    #
    # Sets the text in tiny bold.

    method tinyb {text} {
        $self put "<font size=2><b>$text</b></font>"
    }

    # tinyi text
    #
    # text - A text string
    #
    # Puts the text in tiny italics.

    method tinyi {text} {
        $self put "<font size=2><i>$text</i></font>"
    }

    # ul ?body?
    #
    # body    - A body script
    #
    # Begins an unordered list. If the body is given, it is executed and 
    # the </ul> is added automatically.
   
    method ul {{body ""}} {
        $self putln <ul>

        if {$body ne ""} {
            uplevel 1 $body
            $self /ul
        }
    }

    # li
    #
    # body    - A body script
    #
    # Begins a list item.  If the body is given, it is executed and 
    # the </li> is added automatically.
    
    method li {{body ""}} {
        $self putln <li>

        if {$body ne ""} {
            uplevel 1 $body
            $self put </li>
        }
    }

    # li-text text
    #
    # text    - A text string
    #
    # Puts the text as a list item.    

    method li-text {text} {
        $self putln <li>$text</li>
    }

    # /ul
    #
    # Ends an unordered list
    
    method /ul {} {
        $self putln </ul>
    }

    # pre ?text?
    #
    # text    - A text string
    #
    # Begins a <pre> block.  If the text is given, it is
    # escaped for HTML and the </pre> is added automatically.
   
    method pre {{text ""}} {
        $self putln <pre>
        if {$text ne ""} {
            $self putln [string map {& &amp; < &lt; > &gt;} $text]
            $self /pre
        }
    }

    # /pre
    #
    # Ends a <pre> block
    
    method /pre {} {
        $self putln </pre>
    }


    # para
    #
    # Adds a paragraph mark.
    
    method para {} {
        $self put "<p>\n"
    }

    # br
    #
    # Adds a line break
    
    method br {} {
        $self put <br>
    }

    # link url label
    #
    # url    - A resource URL
    # label  - A text label
    #
    # Formats and returns an HTML link.

    method link {url label} {
        $self put "<a href=\"$url\">$label</a>"
    }

    # linklist ?options...? links
    #
    # links  - A list of links and labels
    #
    # Options:
    #   -delim   - Delimiter; defaults to ", "
    #   -default - String to put if list is empty; defaults to ""
    #
    # Formats and returns a list of HTML links.

    method linklist {args} {
        # FIRST, get the options
        set links [lindex $args end]
        set args  [lrange $args 0 end-1]

        array set opts {
            -delim   ", "
            -default ""
        }

        while {[llength $args] > 0} {
            set opt [lshift args]

            switch -exact -- $opt {
                -delim   -
                -default {
                    set opts($opt) [lshift args]
                }

                default {
                    error "Unknown option: \"$opt\""
                }
            }
        }

        # NEXT, build the list of links.
        set list [list]
        foreach {url label} $links {
            lappend list "<a href=\"$url\">$label</a>"
        }

        set result [join $list $opts(-delim)]

        if {$result ne ""} {
            $self put $result
        } else {
            $self put $opts(-default)
        }
    }


    # table headers ?body?
    #
    # headers - A list of column headers
    # body    - A body script
    #
    # Begins a standard table with the specified column headers.
    # If the body is given, it is executed and the </table> is
    # added automatically.

    method table {headers {body ""}} {
        set itemCounter 0

        $self putln "<table class=pretty cellpadding=5>"

        if {[llength $headers] > 0} {
            $self putln "<tr class=header align=left>"

            foreach header $headers {
                $self put "<th align=left>$header</th>"
            }
            $self put </tr>
        }

        if {$body ne ""} {
            uplevel 1 $body
            $self /table
        }
    }

    # tr ?attr value...? ?body?
    #
    # attr    - A <tr> attribute
    # value   - An attribute value
    # body    - A body script
    #
    # Begins a standard table row.  If the body is included,
    # it is executed, and the </tr> is included automatically.
    
    method tr {args} {
        # FIRST, get the attributes and the body.
        if {[llength $args] % 2 == 1} {
            set body [lindex $args end]
            set args [lrange $args 0 end-1]
        }

        set attrs ""
        foreach {attr value} $args {
            append attrs " $attr=\"$value\""
        }

        if {[incr itemCounter] % 2 == 1} {
            set trClass oddrow
        } else {
            set trClass evenrow
        }

        $self putln "<tr class=$trClass valign=top$attrs>"

        if {$body ne ""} {
            uplevel 1 $body
            $self /tr
        }
    }

    # rowcount 
    #
    # Number of rows in most recently produced table.

    method rowcount {} {
        return $itemCounter
    }

    # td ?align? ?body?
    #
    # align   - left | center | right; defaults to "left".
    # body    - A body script
    #
    # Formats a standard table item; if the body is included,
    # it is executed, and the </td> is included automatically.
    
    method td {{align left} {body ""}} {
        $self putln "<td align=\"$align\">"
        if {$body ne ""} {
            uplevel 1 $body
            $self put </td>
        }
    }

    # /td
    #
    # ends a standard table item
    
    method /td {} {
        $self put </td>
    }

    # /tr
    #
    # ends a standard table row
    
    method /tr {} {
        $self put </tr>
    }

    # /table
    #
    # Ends a standard table with the specified column headers

    method /table {} {
        $self put </table>
    }

    # record ?body?
    #
    # Begins a record list: a borderless table in which the first column
    # contains labels and the second contains values.  If the body is given
    # it is executed and the /namelist is done automatically.

    method record {{body ""}} {
        $self putln "<table border=0 cellpadding=2 cellspacing=0>"

        if {$body ne ""} {
            uplevel 1 $body
            $self /record
        }
    }

    # field label ?body?
    #
    # label   - The field label
    #
    # Begins a new field to a record; if the body is given, it is executed
    # and the /field as added automatically.

    method field {label {body ""}} {
        $self putln "<tr><td align=left><b>$label</b></td> <td>" 
        if {$body ne ""} {
            uplevel 1 $body
            $self /field
        }
    }
    
    # /field
    #
    # Terminates a field in a record

    method /field {} {
        $self put "</td></tr>"
    }

    # /record
    #
    # Ends a named list.

    method /record {} {
        $self putln "</table>"
    }

    # dl ?body?
    #
    # body    - A body script
    #
    # Begins a standard <dl> list.  If the body is included,
    # it is executed, and the </dl> is included automatically.
    
    method dl {{body ""}} {
        $self putln "<dl>"

        if {$body ne ""} {
            if {$body ne ""} {
                uplevel 1 $body
                $self /dl
            }
        }
    }

    # dlitem
    # 
    # dt    - The content of the <dt> tag
    # dd    - The content of the <dd> tag
    #
    # Adds one complete item to the <dl> list, terminated by a <p>.

    method dlitem {dt dd} {
        $self putln "<dt>$dt"
        $self putln "<dd>$dd"
        $self para
    }

    # /dl
    #
    # Ends a <dl> list

    method /dl {} {
        $self putln "</dl>"
    }

    # image name ?align?
    #
    # name  - A Tk image name
    # align - Alignment
    #
    # Adds an in-line <img>.

    method image {name {align ""}} {
        $self put "<img src=\"/image/$name\" align=\"$align\">"
    }

    # object url ?options...?
    #
    # url     - The URL of a tk/widget resource
    # options - Any number of options
    #
    # Adds an <object></object> tag.  The options are converted into
    # attribute names and values.
    
    method object {url args} {
        $self putln "<object data=\"$url\""
        $self InsertAttributes $args
        $self put "></object>"
    }

    # form ?options? 
    #
    # options  - Any number of options
    #
    # Adds a <form> element.  The options are converted into 
    # attribute names and values without error checking.
    # Typical options include:
    #
    #   -action url         - The URL to load (defaults to current page).
    #   -autosubmit value   - If yes, the form autosubmits. 

    method form {args} {
        $self putln "<form "
        $self InsertAttributes $args
        $self put ">"
    }

    # /form
    #
    # Terminates <form>

    method /form {} {
        $self putln </form>
    }

    # label for ?text?
    #
    # for     - an input name
    # text    - Label text
    # 
    # Inserts a <label> tag for the named input.  If text is given,
    # the </label> is inserted automatically.
    
    method label {for {text ""}} {
        $self putln "<label for=\"$for\">"

        if {$text ne ""} {
            $self put "$text</label>"
        }
    }

    # /label
    #
    # Terminates </label>

    method /label {} {
        $self put "</label>"
    }

    # input name itype value ?options? 
    #
    # name     - The input's name
    # itype    - The input's type, e.g., "enum", "text"
    # value    - The input's initial value
    # options  - Any number of options
    #
    # Adds an <input> element with the given name, type, and value
    # attribute values.  The options are converted into 
    # attribute names and values without error checking.

    method input {name itype value args} {
        $self putln "<input name=\"$name\" type=\"$itype\" value=\"$value\""
        $self InsertAttributes $args
        $self put ">"
    }

    # submit ?label?
    #
    # label   - A button label string
    #
    # Inserts a "submit" input into the current form.

    method submit {{label "Submit"}} {
        $self putln "<input type=\"submit\" value=\"$label\">"
    }

    # InsertAttributes optlist
    #
    # optlist   - Tcl-style option list
    #
    # Puts the option list into the buffer as HTML attributes.

    method InsertAttributes {optlist} {
        foreach {opt val} $optlist {
            # FIRST, remove the hyphen
            set opt [string trimleft $opt -]

            # NEXT, add the attribute
            $self put " $opt=\"$val\""
        }
    }

    #-------------------------------------------------------------------
    # Output Paging

    # pager qdict page pages
    #
    # qdict   - The current query dictionary
    # page    - The page currently displayed
    # pages   - The total number of pages
    #
    # This command inserts a "Pages:" controller with a (carefully pruned)
    # list of page numbers, as one sees on search web pages when the 
    # search returns too many results to display at once.  It is intended
    # for use on myserver(n) pages that use a query dictionary, e.g.,
    # the URL ends with "?parm=value+parm=value...".
    #
    # The qdict parameter contains the current query dictionary; it may be
    # empty.  The parameters contained in it will be put in the URL that
    # the page numbers link to.
    #
    # The page number will be included in these URLs as a query
    # parameter, "page=<num>".  
    #
    # If the number of pages is less than 2, no output will appear.

    method pager {qdict page pages} {
        if {$pages <= 1} {
            return
        }

        $self tinyb "Page: "

        if {$page > 1} {
            $self PageLink $qdict [expr {$page - 1}] "Prev"
            $self put " "
        } else {
            $self put "Prev "
        }

        foreach i [$self PageSequence $page $pages] {
            if {$i == $page} {
                $self put "<b>$i</b>"
            } elseif {$i eq "..."} {
                $self put $i
            } else {
                $self PageLink $qdict $i
            }

            $self put " "
        }

        if {$page < $pages} {
            $self PageLink $qdict [expr {$page + 1}] "Next"
        } else {
            $self put "Next"
        }

        $self para
    }

    # PageSequence page pages 
    #
    # page    - A page number, 1 to N
    # pages   - The total number of pages N 
    #
    # Returns a list of ordered page numbers, possibly with "...".

    method PageSequence {page pages} {
        set result [list]
        set last 0

        for {set i 1} {$i <= $pages} {incr i} {
            if {$i <= 3 || 
                $i >= $pages - 2 ||
                ($i >= $page - 2 && $i <= $page + 2)
            } {
                if {$i - 1 != $last} {
                    lappend result "..."
                }
                lappend result $i
                set last $i                
            }
        }

        return $result
    }

    # PageLink qdict page ?label?
    #
    # qdict   - The current query dictionary
    # page    - The page to link to
    # label   - The link label; defaults to the page number.
    #
    # Creates a link to the named page.

    method PageLink {qdict page {label ""}} {
        if {$label eq ""} {
            set label $page
        }

        dict set qdict page $page

        $self link "?[urlquery fromdict $qdict]" $label
    }
}


