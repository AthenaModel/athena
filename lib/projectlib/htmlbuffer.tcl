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

#-----------------------------------------------------------------------
# htmlbuffer type

oo::class create ::projectlib::htmlbuffer {
    #-------------------------------------------------------------------
    # Lookup Tables

    # defaultStyles
    #
    # These styles are put in page headers to support font handling;
    # if -styles or -cssfile are given when the buffer is created,
    # they are not used.

    meta defaultStyles {
        /* TBD */
    }

    # Alignments for ht query.
    meta alignments {
        "" left
        L  left
        C  center
        R  right
    }

    
    #-------------------------------------------------------------------
    # Instance Variables

    # Options Array
    variable options

    # Buffer Stack: The htmlbuffer instance maintains a stack of 
    # buffers; it is often convenient to push a buffer onto the stack,
    # generate HTML in that buffer, and then pop it, either retaining
    # or discarding the HTML (e.g., table headers if there is no table
    # content).
    
    variable sp     ;# Stack pointer: index into stack()
    variable stack  ;# Stack: array from index to buffer content

    # trans array: transient data used while formatting tables and 
    # similar multi-tag content.

    variable trans

    #-------------------------------------------------------------------
    # Constructor 

    # constructor ?options?
    #
    # Creates and initializes the buffer.
    #
    # Options:
    #    -cssfile name   - The name of an external CSS file to be
    #                      <link>ed in page headers.
    #    -domain prefix  - A URL domain prefix, e.g., "/this/that",
    #                      used as a prefix for iref links.
    #    -footercmd cmd  - A callback that adds content to the page
    #                      footer.  Called with one additional argument,
    #                      the buffer itself, by "/page".
    #    -headercmd cmd  - A callback that adds content to the page
    #                      header.  Called with two additional arguments,
    #                      the buffer and the page title, by "page".
    #    -mode mode      - web|tk; the HTML generation mode.  Defaults to
    #                      web.
    #    -styles css     - CSS styles to be used in place of the default
    #                      CSS styles.
    constructor {args} {
        # FIRST, initialize the options.
        array set options {
            -cssfile   ""
            -domain    ""
            -footercmd {}
            -headercmd {}
            -mode      web
            -styles    {}
        }

        # NEXT, get the creation options.
        my configure {*}$args

        # NEXT, initialize the buffer.
        my clear
    }

    #-------------------------------------------------------------------
    # Option Management

    # configure ?option value...?
    #
    # Sets the options and the values.  No error checking is done,
    # except for option names.  None of the fancy Tk-style processing is 
    # done.

    method configure {args} {
        foreach {opt val} $args {
            if {![info exists options($opt)]} {
                error "Invalid option:\"$opt\""
            }

            set options($opt) $val
        }
    }
    
    # cget option 
    #
    # Retrieves an option value.

    method cget {option} {
        return $options($option)
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
    # tag     - An HTML tag name
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
        my put "<$tag"
        my InsertAttributes $args
        my put ">"
    }

    # tagln tag ?options...?
    #
    # tag     - An HTML tag name
    # options - Tcl-style option list
    #
    # Like tag, but begins on a new line.

    method tagln {tag args} {
        my putln "<$tag"
        my InsertAttributes $args
        my put ">"
    }

    # wrap tag ?options...? text 
    #
    # tag     - An HTML tag name
    # options - Tcl-style option list
    # text    - The text to wrap in the tag
    #
    # Puts the tag into the buffer, wrapping the given text, and 
    # converting the options to attributes.  E.g., 
    # 
    #    $hb wrap title "My Title"
    #
    # generates
    #
    #    <title>My Title</title>

    method wrap {tag args} {
        set text [my PopOdd args]
        my tag $tag {*}$args
        my put $text
        my put </$tag>
    }

    # wrapln tag ?options...? text 
    #
    # tag     - An HTML tag name
    # options - Tcl-style option list
    # text    - The text to wrap in the tag
    #
    # Like wrap, but begins on a new line.

    method wrapln {tag args} {
        set text [my PopOdd args]
        my tagln $tag {*}$args
        my put $text
        my put </$tag>
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
            my put $then
        } else {
            my put $else
        }
    }

    #-------------------------------------------------------------------
    # Page Management

    # page title ?options?
    #
    # title   - Title of HTML page
    # options - Options, mostly for the <body> tag
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
    # The following options are handled specially.  Any additional
    # options are converted into <body> tag attributes.
    #
    # -refreshafter seconds    - The page will automatically reload after
    #                            the specified number of seconds.

    method page {title args} {
        set refreshAfter [optval args -refreshafter ""]

        my clear

        my putln <html>
        my putln <head>
        my wrapln title $title

        if {$options(-cssfile) ne ""} {
            my tagln link -rel stylesheet -href $options(-cssfile)
        }

        if {$options(-styles) ne ""} {
            # TBD: Handling of defaultStyles!
            my wrapln style $options(-styles)
        }

        if {$refreshAfter ne ""} {
            my tagln meta -http-equiv refresh -content $refreshAfter
        }

        my putln </head>
        my tagln body {*}$args

        callwith $options(-headercmd) [self] $title
    }

    # /page
    #
    # Adds the standard footer boilerplate, and returns the
    # formatted page.  If -footercmd is given, it is passed
    # the buffer.  Any output will appear just before the </body>
    # tag.

    method /page {} {
        callwith $options(-footercmd) [self]

        my putln </body>
        my putln </html>

        return [my get]
    }
    export /page

    #-------------------------------------------------------------------
    # Headings
    
    # h1 ?options? title
    #
    # options - Attribute options
    # title   - A title string
    #
    # Returns an HTML H1 title.

    method h1 {args} {
        my wrapln h1 {*}$args
    }

    # h2 ?options? title
    #
    # options - Attribute options
    # title   - A title string
    #
    # Returns an HTML H2 title.

    method h2 {args} {
        my wrapln h2 {*}$args
    }

    # h3 ?options? title
    #
    # options - Attribute options
    # title   - A title string
    #
    # Returns an HTML H3 title.

    method h3 {args} {
        my wrapln h3 {*}$args
    }

    # h4 ?options? title
    #
    # options - Attribute options
    # title   - A title string
    #
    # Returns an HTML H4 title.

    method h4 {args} {
        my wrapln h4 {*}$args
    }

    # h5 ?options? title
    #
    # options - Attribute options
    # title   - A title string
    #
    # Returns an HTML H5 title.

    method h5 {args} {
        my wrapln h5 {*}$args
    }

    # h6 ?options? title
    #
    # options - Attribute options
    # title   - A title string
    #
    # Returns an HTML H6 title.

    method h6 {args} {
        my wrapln h6 {*}$args
    }


    #-------------------------------------------------------------------
    # Other HTML Tags

    # br
    #
    # Adds a line break
    
    method br {} {
        my put <br> \n
    }

    # hr ?options?
    #
    # options   - Attribute options
    #
    # Inserts an <hr> tag.
    
    method hr {args} {
        my tagln hr {*}$args
        my put \n
    }

    # para
    #
    # Adds a paragraph mark.
    
    method para {} {
        my put <p> \n
    }

    # pre ?options...? ?text?
    #
    # text    - A text string
    # options - Attribute options
    #
    # Begins a <pre> block.  If the text is given, it is
    # escaped for HTML and the </pre> tag is added automatically.
   
    method pre {args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            my wrap pre {*}$args $text
        } else {
            my tag pre {*}$args
        }
    }

    # pre-with ?options? body
    #
    # body    - A script to execute
    #
    # Defines a <pre> block.  The body is executed, and the </pre> tag
    # is added automatically.
   
    method pre-with {args} {
        set body [my PopOdd args body]
        my tag pre {*}$args
        uplevel 1 $body
        my /pre
    }

    # /pre
    #
    # Ends a <pre> block
    
    method /pre {} {
        my putln </pre>
    }
    export /pre

    # span ?options...? ?text?
    #
    # text    - A text string
    # options - Attribute options
    #
    # Begins a <span> block.  If the text is given, the </span> tag is 
    # added automatically.
   
    method span {args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            my wrap span {*}$args $text 
        } else {
            my tag span {*}$args
        }
    }

    # span-with ?options? body
    #
    # body    - A script to execute
    #
    # Defines a <span> block.  The body is executed, and the </span> tag
    # is added automatically.
   
    method span-with {args} {
        set body [my PopOdd args body]
        my tag span {*}$args
        uplevel 1 $body
        my /span
    }

    # /span
    #
    # Ends a <span> block
    
    method /span {} {
        my putln </span>
    }
    export /span

    #-------------------------------------------------------------------
    # <a href> links

    # xref url ?options? label
    #
    # url       - An external or server-local URL.
    # options   - Attribute options
    # label     - The label to display.
    #
    # Produces an <a href="...">...</a> tag.  In addition to normal
    # attribute options, the following is also available:
    #
    # -qparms   - A dictionary of query parameters.

    method xref {url args} {
        set label [my PopOdd args label]
        set qparms [optval args -qparms ""]

        if {[dict size $qparms] != 0} {
            set query [my asquery $qparms]
        } else {
            set query ""
        }

        my wrap a -href $url$query {*}$args $label 
    }

    # iref suffix ?options? label
    #
    # suffix    - A suffix to add to the -domain to get a server-local
    #             URL.  Must begin with "/".
    # options   - Attribute options
    # label     - The label to display.
    #
    # Produces an <a href="...">...</a> tag linking to a page in the
    # same domain.  In addition to normal
    # attribute options, the following is also available:
    #
    # -qparms   - A dictionary of query parameters.

    method iref {suffix args} {
        my xref $options(-domain)$suffix {*}$args
    }

    # qref qparms ?options? label
    #
    # qparms    - A dictionary of query parameters.
    # options   - Attribute options
    # label     - The label to display.
    #
    # Produces an <a href="...">...</a> tag linking to the same page
    # with the given query parameters.

    method qref {qparms args} {
        my xref [my asquery $qparms] {*}$args
    }

    # ximg url ?options?
    #
    # url       - An external or server-local URL.
    # options   - Attribute options
    #
    # Produces an <img src="..."> tag.

    method ximg {url args} {
        my tag img -src $url {*}$args
    }

    # iimg suffix ?options?
    #
    # suffix    - A suffix to add to the -domain to get a server-local
    #             URL.  Must begin with "/".
    # options   - Attribute options
    #
    # Produces an <img src="..."> tag.

    method iimg {suffix args} {
        my ximg $options(-domain)$suffix {*}$args
    }

    #-------------------------------------------------------------------
    # Lists

    # ul ?options? ?body?
    #
    # options - Attribute options
    # body    - A body script
    #
    # Begins an unordered list. If the body is given, it is executed and 
    # the </ul> is added automatically.
   
    method ul {args} {
        set body [my PopOdd args]

        my tagln ul {*}$args

        if {$body ne ""} {
            uplevel 1 $body
            my /ul
        }
    }

    # /ul
    #
    # Ends an unordered list
    
    method /ul {} {
        my putln </ul>
    }
    export /ul

    # ol ?options? ?body?
    #
    # options - Attribute options
    # body    - A body script
    #
    # Begins an ordered list. If the body is given, it is executed and 
    # the </ol> is added automatically.
   
    method ol {args} {
        set body [my PopOdd args]

        my tagln ol {*}$args

        if {$body ne ""} {
            uplevel 1 $body
            my /ol
        }
    }

    # /ol
    #
    # Ends an ordered list
    
    method /ol {} {
        my putln </ol>
    }
    export /ol

    # li ?options...? ?text?
    #
    # text    - A text string
    # options - Attribute options
    #
    # Begins a <li> block.  If the text is given, the </li> tag is 
    # added automatically.
   
    method li {args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            my wrapln li {*}$args $text 
        } else {
            my tagln li {*}$args
        }
    }

    # li-with ?options? body
    #
    # body    - A script to execute
    #
    # Defines a <li> block.  The body is executed, and the </li> tag
    # is added automatically.
   
    method li-with {args} {
        set body [my PopOdd args body]
        my tagln li {*}$args
        uplevel 1 $body
        my /li
    }

    # /li
    #
    # Ends a <li> block
    
    method /li {} {
        my putln </li>
    }
    export /li


    # dl ?options? ?body?
    #
    # options - Attribute options
    # body    - A body script
    #
    # Begins a definition list. If the body is given, it is executed and 
    # the </dl> is added automatically.
   
    method dl {args} {
        set body [my PopOdd args]

        my tagln dl {*}$args

        if {$body ne ""} {
            uplevel 1 $body
            my /dl
        }
    }

    # /dl
    #
    # Ends a <dl> list

    method /dl {} {
        my putln </dl>
    }
    export /dl

    # dt ?options...? ?text?
    #
    # text    - A text string
    # options - Attribute options
    #
    # Begins a <dt> span.  If the text is given, the </dt> tag is 
    # added automatically.
   
    method dt {args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            my wrapln dt {*}$args $text
        } else {
            my tagln dt {*}$args
        }
    }

    # /dt
    #
    # Ends a <dt> block
    
    method /dt {} {
        my putln </dt>
    }
    export /dt

    # dd ?options...? ?text?
    #
    # text    - A text string
    # options - Attribute options
    #
    # Begins a <dd> block.  If the text is given, the </dd> tag is 
    # added automatically.
   
    method dd {args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            my wrapln dd {*}$args $text 
        } else {
            my tagln dd {*}$args
        }
    }

    # dd-with ?options? body
    #
    # body    - A script to execute
    #
    # Defines a <dd> block.  The body is executed, and the </dd> tag
    # is added automatically.
   
    method dd-with {args} {
        set body [my PopOdd args body]
        my tagln dd {*}$args
        uplevel 1 $body
        my /dd
    }

    # /dd
    #
    # Ends a <dd> block
    
    method /dd {} {
        my putln </dd>
    }
    export /dd

    
    #-------------------------------------------------------------------
    # Tables
    
    # table ?options? ?body?
    #
    # options - Attribute options
    # body    - A body script
    #
    # In addition to the attribute options, the following may also
    # be used:
    #
    # -class   cls    - The CSS class; defaults to "pretty".
    # -headers list   - A list of header strings, to be loaded
    #                   with class=header align=left.
    #
    # If the body is given, it is executed and the </table> is
    # added automatically.

    method table {args} {
        # FIRST, get the body, if any
        set body [my PopOdd args]

        # NEXT, get the options (setting defaults)
        set headers [optval args -headers ""]

        array set opts {
            -class       pretty
            -cellpadding 5
        }

        array set opts $args


        # NEXT, initialize transient data
        set trans(rowCounter) 0

        my tagln table {*}[array get opts]

        if {[llength $headers] > 0} {
            my tagln tr -class header -align left
            foreach header $headers {
                my wrapln th -align left $header 
            }
            my /tr
        }

        if {$body ne ""} {
            uplevel 1 $body
            my /table
        }
    }

    # /table
    #
    # Ends a standard table

    method /table {} {
        my putln </table>
    }
    export /table


    # tr ?options...? ?body?
    #
    # options - Attribute options
    # body    - A body script
    #
    # Begins a standard table row.  If the body is included,
    # it is executed, and the </tr> is included automatically.
    
    method tr {args} {
        # FIRST, get the attributes and the body.
        set body [my PopOdd args]

        if {[incr trans(rowCounter)] %2 == 1} {
            set cls oddrow
        } else {
            set cls evenrow
        }

        my tagln tr -class $cls -valign top {*}$args

        if {$body ne ""} {
            uplevel 1 $body
            my /tr
        }
    }

    # /tr
    #
    # ends a standard table row
    
    method /tr {} {
        my put </tr>
    }
    export /tr


    # rowcount 
    #
    # Number of rows in most recently produced table.

    method rowcount {} {
        return $trans(rowCounter)
    }

    # td ?options...? ?text?
    #
    # text    - A text string
    # options - Attribute options
    #
    # Begins a <td> block.  If the text is given, the </td> tag
    # is added automatically.  By default, the text aligns left.
   
    method td {args} {
        set text [my PopOdd args]

        set align [optval args -align left]

        if {$text ne ""} {
            my wrapln td -align $align {*}$args $text 
        } else {
            my tagln td {*}$args
        }
    }

    # td-with ?options? body
    #
    # body    - A script to execute
    #
    # Begins a <td> block.  The body is executed, and the </td> tag
    # is added automatically.
   
    method td-with {args} {
        set body [my PopOdd args body]
        set align [optval args -align left]
        my tag td -align $align {*}$args
        uplevel 1 $body
        my /td
    }

    # /td
    #
    # Ends a <td> block

    method /td {} {
        my put </td>
    }
    export /td    

    #-------------------------------------------------------------------
    # Records and Fields
    #
    # A record is two parallel columns of labels and values.

    # record ?options? ?body?
    #
    # options   - Table attribute options
    # body      - A body script.
    #
    # Begins a record list: a borderless table in which the first column
    # contains labels and the second contains values.  If the body is given
    # it is executed and the /record is done automatically.
    #
    # The default table options are border=0 cellpadding=2 cellspacing=0

    method record {args} {
        set body [my PopOdd args]

        array set opts {
            -border      0
            -cellpadding 2
            -cellspacing 0
        }
        array set opts $args

        my tagln table {*}[array get opts]

        if {$body ne ""} {
            uplevel 1 $body
            my /record
        }
    }

    # field label ?text?
    #
    # label   - The field label
    #
    # Begins a new field in a record; if the text is given it is
    # added and the /field is added automatically.

    method field {label {text ""}} {
        my tr
        my td "<b>$label</b>"

        if {$text ne ""} {
            my td $text
            my /tr
        }
    }
    
    # field-with label body
    #
    # label   - The field label
    # body    - The body script.
    #
    # Adds a new field to a record; executes the body and adds
    # the /field automatically.

    method field-with {label body} {
        my tr
        my field $label
        my td
        uplevel 1 $body
        my /td
        my /tr
    }

    # /field
    #
    # Terminates a field in a record

    method /field {} {
        my put "</td></tr>"
    }
    export /field

    # /record
    #
    # Ends a named list.

    method /record {} {
        my putln "</table>"
    }
    export /record

    #-------------------------------------------------------------------
    # HTML Forms
    #
    # TBD: We'll add specific commands for the input tags we need.

    # form ?options? ?body?
    #
    # options  - Attribute Options
    # body     - A script
    #
    # Adds a <form> element.  The options are converted into 
    # attribute names and values without error checking.
    # If the script is given, it is executed and the "</form>"
    # tag is inserted automatically.

    method form {args} {
        set body [my PopOdd args]
        my tagln form {*}$args

        if {$body ne ""} {
            uplevel 1 $body
            my /form
        }
    }

    # /form
    #
    # Terminates <form>

    method /form {} {
        my putln </form>
    }
    export /form

    # label name ?options...? ?text?
    #
    # name    - an input name
    # options - Attribute options
    # text    - Label text
    # 
    # Inserts a <label> tag for the named input.  If text is given,
    # the </label> is inserted automatically.
    
    method label {name args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            my wrapln label -for $name {*}$args $text
        } else {
            my tagln label -for $name {*}$args
        }
    }

    # /label
    #
    # Terminates </label>

    method /label {} {
        my put "</label>"
    }
    export /label

    # textarea name ?options...? ?text?
    #
    # text    - A text string to initialize the textarea.
    # options - Attribute options
    #
    # Defines a <textarea> block.  </textarea> tag is 
    # added automatically.
   
    method textarea {name args} {
        set text [my PopOdd args]

        my wrapln textarea -name $name {*}$args $text 
    }

    # submit ?options? ?label?
    #
    # options - Attribute options
    # label   - A button label string
    #
    # Inserts a "submit" input into the current form.

    method submit {args} {
        set text [my PopOdd args]

        if {$text ne ""} {
            lappend args -value $text
        }
        my tagln input -type submit {*}$args
    }

    # entry ?options?
    #
    # options  - Attribute options
    #
    # Inserts a text entry input into the current form.

    method entry {name args} {
        my tagln input -type text -name $name {*}$args
    }

    # hidden name value ?options?
    #
    # options  - Attribute options
    #
    # Inserts a text entry input into the current form.

    method hidden {name value args} {
        my tagln input -type hidden -name $name -value $value {*}$args
    }

    # enum name ?options? list
    #
    # options  - Attribute options, plus below
    # list     - List of choices
    #
    # Special Options:
    #
    # -autosubmit flag  - If given and true, autosubmit on input.
    # -selected value   - Indicates that the <option> with the
    #                     given value is to be selected initially.
    #
    # Inserts a <select> element into the current form.

    method enum {name args} {
        set list       [my PopOdd args list]
        set autosubmit [optval args -autosubmit ""]
        set selected   [optval args -selected]

        if {$autosubmit ne ""} {
            lappend args \
                -oninput document.getElementById('$autosubmit').submit();
        }

        my tagln select -name $name {*}$args
        foreach item $list {
            if {$item eq $selected} {
                my wrapln option -value $item -selected "" $item
            } else {
                my wrapln option -value $item $item 
            }
        }
        my tagln /select
    }

    # enumlong name ?options? namedict
    #
    # options  - Attribute options
    # namedict - List of choices and labels
    #
    # Special Options:
    #
    # -autosubmit form  - If given, autosubmit the named
    #                     form on input.
    # -selected value   - Indicates that the <option> with the
    #                     given value is to be selected initially.
    #
    # Inserts a <select> element into the current form.

    method enumlong {name args} {
        set namedict   [my PopOdd args namedict]
        set autosubmit [optval args -autosubmit ""]
        set selected   [optval args -selected]

        if {$autosubmit ne ""} {
            lappend args \
                -oninput document.getElementById('$autosubmit').submit();
        }

        my tagln select -name $name {*}$args
        foreach {item longname} $namedict {
            if {$item eq $selected} {
                my wrapln option -value $item -selected "" $longname
            } else {
                my wrapln option -value $item $longname
            }
        }
        my tagln /select
    }

    # radio name ?options? value
    #
    # name    - Name of the collection of radio inputs
    # options - Attribute options
    # value   - Value for this input

    method radio {name args} {
        set value [my PopOdd args]
        my tagln input -type radio -name $name -value $value {*}$args
    }


    #-------------------------------------------------------------------
    # SQL Queries


    # query db sql ?options...?
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

    method query {db sql args} {
        # FIRST, get options.
        array set opts {
            -labels   {}
            -default  "No data found.<p>"
            -align    {}
            -escape   no
        }
        array set opts $args

        # FIRST, begin the table.  If we have labels, we'll use those
        # as headers; otherwise, QueryRows will use the column names
        # as headers.
        my push
        if {$opts(-labels) ne ""} {
            my table -headers $opts(-labels)
        }


        # NEXT, get the data.  Execute the query as an uplevel,
        # so that we can use variables.
        set trans(qnames) {}
        set trans(qopts)  [array get opts]

        uplevel 1 [list $db eval $sql ::projectlib::htmlbuffer::qrow \
                       [list my QueryRow]]

        my /table

        set table [my pop]
        
        if {[llength $trans(qnames)] == 0} {
            my putln $opts(-default)
        } else {
            my putln $table
        }
    }

    # QueryRow 
    #
    # Builds up the table results

    method QueryRow {} {
        upvar #0 ::projectlib::htmlbuffer::qrow qrow

        if {[llength $trans(qnames)] == 0} {
            set trans(qnames) $qrow(*)
            unset qrow(*)

            if {[dict get $trans(qopts) -escape} {
                set trans(qnames) [my escape $trans(qnames)]
            }

            if {[my get] eq ""} {
                my table -headers $trans(qnames)
            }
        }
        
        # If the alignment spec is longer than the number of columns, 
        # trim it down. No need to worry if it's shorter, that's handled
        set alignstr [string range \
                        [dict get $trans(qopts) -align] 
                        0 [expr {[llength $trans(qnames)]-1}]]

        my tr {
            foreach name $trans(qnames) align [split $alignstr ""] {
                if {[dict get $trans(qopts) -escape} {
                    set qrow($name) <tt>[my escape $qrow($name)]</tt>
                }

                my td-with -align [my alignments $align] {
                    my put $qrow($name)
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # pager
    #
    # Paging of tables and other large data sets.

    # pagestats numitems pagesize ?page?
    #
    # numitems - The number of items total
    # pagesize - The number of items to display on one page
    # page     - The number of the requested page, 1 to n.
    #            Defaults to 1.
    #
    # Computes the SQL "OFFSET" for paging through a query.  
    # Returns a list {page pages offset limitClause},
    # where page is the actual page number, pages is the total number
    # of pages, offset is the offset of the first item on the selected
    # page, and limitClause is an SQL "LIMIT/OFFSET" clause.

    method pagestats {numitems pagesize {page 1}} {
        # FIRST, compute the number of pages.
        let pages {entier(ceil(double($numitems)/$pagesize))}

        # NEXT, constrain the requested page.
        if {$page < 1} {
            set page 1
        } elseif {$page > $pages} {
            set page $pages
        }

        # NEXT, compute the offset
        let offset {($page - 1)*$pagesize}

        set limit "LIMIT $pagesize OFFSET $offset"

        return [list $page $pages $offset $limit]
    }

    # pager qparms page pages
    #
    # qparms  - The current query parameter dictionary
    # page    - The page currently displayed
    # pages   - The total number of pages
    #
    # This command inserts a "Pages:" controller with a (carefully pruned)
    # list of page numbers, as one sees on search web pages when the 
    # search returns too many results to display at once.  The links
    # include all of the query parameters.
    #
    # The page number will be included in these URLs as a query
    # parameter, "page=<num>".  
    #
    # If the number of pages is less than 2, no output will appear.

    method pager {page pages qparms} {
        # FIRST, no pager unless it's needed.
        if {$pages <= 1} {
            return
        }

        # NEXT, begin formatting
        my span -class tinyb "Page: "

        if {$page > 1} {
            my PageLink $qparms [expr {$page - 1}] "Prev"
        } else {
            my span -class tiny "Prev"
        }
        my put " "

        foreach i [my PageSequence $page $pages] {
            if {$i == $page} {
                my span -class tinyb $i
            } elseif {$i eq "..."} {
                my span -class tiny $i
            } else {
                my PageLink $qparms $i
            }

            my put " "
        }

        if {$page < $pages} {
            my PageLink $qparms [expr {$page + 1}] "Next"
        } else {
            my span -class tiny "Next"
        }

        my para
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

    # PageLink qparms page ?label?
    #
    # qparms   - The current query dictionary
    # page    - The page to link to
    # label   - The link label; defaults to the page number.
    #
    # Creates a link to the named page.

    method PageLink {qparms page {label ""}} {
        if {$label eq ""} {
            set label $page
        }

        dict set qparms page $page

        my span -class tiny
        my qref $qparms $label
        my /span
    }

    

    #-------------------------------------------------------------------
    # Helper Commands

    # asquery dict
    #
    # dict  - A dictionary of query parameters.
    #
    # Encodes the dictionary as a URL query, including the initial "?".
    
    method asquery {dict} {
        set result ""
        dict for {k v} $dict {
            lappend result "$k=[ncgi::encode $v]"
        }

        return "?[join $result &]"
    }

    # escape text
    #
    # text - Plain text to be included in an HTML page
    #
    # Escapes the &, <, and > characters so that the included text
    # doesn't screw up the formatting.

    method escape {text} {
        return [string map {& &amp; < &lt; > &gt;} $text]
    }

    # InsertAttributes optlist
    #
    # optlist   - Tcl-style option list
    #
    # Puts the option list into the buffer as HTML attributes.

    method InsertAttributes {optlist} {
        while {[llength $optlist] > 0} {
            set opt [lshift optlist]

            set attr [string trimleft $opt -]
            set value [lshift optlist]

            if {$value ne ""} {
                my put " $attr=\"$value\""
            } else {
                my put " $attr"
            }
        }
    }

    # PopOdd listvar ?argname?
    #
    # Pops the last value from the listvar, only if there are an
    # odd number of entries, and returns it.  If there is no odd
    # entry, either returns "" or throws an error of the argument
    # name is given.

    method PopOdd {listvar {argname ""}} {
        upvar 1 $listvar list

        if {[llength $list] % 2 == 1} {
            return [lpop list]
        } elseif {$argname ne ""} {
            error "Missing argument: $argname"
        } else {
            return ""
        }
    }


    #===================================================================
    # NOT PROCESSED YET
    # 
    # Old code from htools(n) that we'll probably want eventually.

    if 0 {
        # linkbar linkdict
        # 
        # linkdict   - A dictionary of URLs and labels
        #
        # Displays the links in a horizontal bar.

        method linkbar {linkdict} {
            my hr
            set count 0

            foreach {link label} $linkdict {
                if {$count > 0} {
                   my put " | "
                }

                my link $link $label

                incr count
            }

            my hr
            my para
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
                my put $result
            } else {
                my put $opts(-default)
            }
        }

    }

}


