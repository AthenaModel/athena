#-----------------------------------------------------------------------
# TITLE:
#    url.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): URL Dispatcher
#
#    This is the URL dispatcher.  The URL hierarchy is divided into 
#    "domains" that are subtrees of the URL space with a particular type.  
#    A domain is identified by the name of its root, which is a prefix of 
#    the URLs in that domain.  The dispatcher selects a domain by the 
#    longest matching prefix, and then calls a domain handler to process 
#    the URL.  Different domain handlers correspond to files (Doc), 
#    and things built right into the application (Direct, etc).
#
#    URL processing is divided into two parts: access control and
#    url implementation.  You register access hooks with
#    [url access install], and you register URL implementations with
#    [url prefix install].
#
#    Brent Welch (c) 1997 Sun Microsystems, 1998-2000 Scriptics Corporation.
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::url {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array
    #
    # prefixset          - A regular expression used to pick off the
    #                      prefix from URLs.
    # accessHooks        - List of access hook command prefixes.
    # callback,$prefix   - ???
    # readpost,$prefix   - Readpost flag for prefix
    # command,$prefix    - URL domain handler

    typevariable info -array {
        accessHooks {}
        prefixset   {}
    }

    # encodeMap - array of encoded characters by character
    #
    # do x-www-urlencoded character mapping
    # The spec says: "non-alphanumeric characters are replaced by '%HH'"

    typevariable encodeMap -array {}
    
    typeconstructor {
        for {set i 1} {$i <= 256} {incr i} {
            set c [format %c $i]
            if {![string match \[a-zA-Z0-9\] $c]} {
                set encodeMap($c) %[format %.2x $i]
            }
        }
     
        # These are handled specially
        array set encodeMap {
            " " +   \n %0d%0a
        }
    }

    #-------------------------------------------------------------------
    # Public Typemethods

    # fssep
    #
    # Returns a pattern than cannot occur inside a URL path component.
    # On Windows we disallow ":" to avoid drive-letter attacks.
    #
    # NOTE: "macintosh" refers to pre-OSX versions of Mac Tcl.
    #
    # TBD: Possibly, this can be private.

    proc fssep {} {
        switch $::tcl_platform(platform) {
            windows   { return {[/\\:]} }
            macintosh { return :        }
            unix      -
            default   { return /        }
        }
    }

    # dispatch sock
    #
    # sock  - The client socket connection
    #
    # Dispatches the request to a type-specific handler for a URL.

    typemethod dispatch {sock} {
        upvar #0 Httpd$sock data

        catch {after cancel $data(cancel)}
        set url $data(url)

        stats countname $url hit

        try {
            # INLINE VERSION OF prefixmatch

            # Collapse multiple // to avoid tricks like //cgi-bin that fail
            # to match the /cgi-bin prefix
            regsub -all /+ $url / url

            if {$info(prefixset) eq "" ||
                ![regexp ^($info(prefixset))(.*) $url x prefix suffix] ||
                ([string length $suffix] && ![string match /* $suffix])} {

                # Fall back and assume it is under the root
                # The /+ gobbles extra /'s that might be used to sneak
                # out to the root of the file hierarchy.

                regexp ^(/+)(.*) $url x prefix suffix
                set prefix /
            }

            # END INLINE

            # Do access control before dispatch,
            # but after prefix/suffix determination

            set data(prefix) $prefix
            set data(suffix) $suffix
            stats countname $prefix domainHit

            foreach hook $info(accessHooks) {
                switch -- [{*}$hook $sock $url] {
                    ok  { 
                        break 
                    }
                    return  -
                    denied  {
                        # A URL implementation should have generated the
                        # appropriate response, such as a 403, to request
                        # a retry. But, if it hasn't, we generate a default.

                        if {![Httpd_RequestComplete $sock]} {
                            Httpd_Error $sock 403
                        }
                        return
                    }
                    skip { 
                        continue 
                    }
                }
            }

            # Register a callback with the Httpd layer
            if {[info exist info(callback,$prefix)]} {
                Httpd_CompletionCallback $sock $info(callback,$prefix)
            }

            # Pre-read the post data, if the domain wants that
            if {$info(readpost,$prefix) && $data(count) > 0} {                
                Httpd_ReadPostDataAsync $sock \
                    [myproc DeferredDispatch $prefix $suffix]
                return
            }

            # Invoke the URL domain handler.
            stats count UrlEval
            {*}$info(command,$prefix) $sock $suffix
        } on error {error} {
            # Only do this on uncaught errors.
            # Note that the return statement for the "denied" case of the
            # access hook will result in catch returning code == 2, 
            # not 1 (or zero)

            Unwind $sock $::errorInfo $::errorCode
        }
    }

    # DeferredDispatch sock
    #
    # sock  - The client socket connection
    #
    # Dispatch to a type-specific handler for a URL after the
    # post data has been read.

    proc DeferredDispatch {prefix suffix sock varname errmsg} {
        if {[string length $errmsg]} {
            Httpd_SockClose $sock 1 $errmsg
            return
        }

        url posthook $sock 0    ;# Turn off [url readpost]

        try {
            # Invoke the URL domain handler either in this main thread
            ::ahttpd::stats count UrlEval
            {*}$info(command,$prefix) $sock $suffix
        } on error {error} {
            Unwind $sock $::errorInfo $::errorCode
        }
    }

    # Unwind sock ei ec
    #
    # sock   - The client connection
    # ei     - The errorInfo from the command
    # ec     - The errorCode from the command
    #
    # Do common error handling after a URL request, cleaning up the
    # connection and ensuring a reply.

    proc Unwind {sock ei ec} {
        # URL implementations can raise special errors to unwind their 
        # processing.

        set key [lindex $ec 0]
        set error [lindex [split $ei \n] 0]
        switch -- $key {
            HTTPD_REDIRECT {
                # URL implementations can raise an error and put redirect 
                # info into the errorCode variable, which should be of the 
                # form HTTPD_REDIRECT $newurl

                Httpd_Redirect [lindex $ec 1] $sock
                return
            }
            HTTPD_SUSPEND {
                # The domain handler has until Httpd(timeout2) to complete 
                # this request
        
                Httpd_Suspend $sock
                return
            }
        }

        switch -glob -- $ei {
            "*can not find channel*"  {
                Httpd_SockClose $sock 1 $error
            }
            "*too many open files*" {
                # this is lame and probably not necessary.
                # Early bugs lead to file descriptor leaks, but
                # these are all plugged up.
                stats count numfiles
                Httpd_SockClose $sock 1 $error
                File_Reset
            } 
            default {
                doc error $sock $ei
            }
        }
    }


    # prefix match url prefixVar suffixVar
    # 
    # url        - The input URL
    # prefixVar  - Output variable, the prefix
    # suffixVar  - Output variable, the suffix
    #
    # Match the domain prefix of a URL, filling in the 
    # prefix and suffix result variables.

    typemethod {prefix match} {url prefixVar suffixVar} {
        upvar 1 $prefixVar prefix
        upvar 1 $suffixVar suffix

        # Prefix match the URL to get a domain handler
        # Fast check on domain prefixes with regexp
        # Check that the suffix starts with /, otherwise the prefix
        # is not a complete component.  E.g., "/tcl" vs "/tclhttpd"
        # where /tcl is a domain prefix but /tclhttpd is a directory
        # in the / domain.

        # IF YOU CHANGE THIS  - FIX in-line CODE IN URL_DISPATCH

        # Collapse multiple // to avoid tricks like //cgi-bin that fail
        # to match the /cgi-bin prefix
        regsub -all /+ $url / url

        if {$info(prefixset) eq "" ||
            ![regexp ^($info(prefixset))(.*) $url x prefix suffix] ||
            ([string length $suffix] && ![string match /* $suffix])
        } {
            # Fall back and assume it is under the root
            regexp ^(/+)(.*) $url x prefix suffix
            set prefix /
        }
    }

    # prefix exists prefix
    #
    # prefix  - The input URL
    # 
    # Return 1 if the prefix has been registered, and 0 otherwise.

    typemethod {prefix exists} {prefix} {
        return [info exist info(command,$prefix)]
    }

    # access install proc
    #
    # proc - A command prefix that is invoked with two additional
    #        arguments to check permissions:
    #
    #           sock  - The handle on the connection
    #           url   - The url being accessed
    #        
    #        The hook should return one of the following:
    #           "ok"      - Meaning access is allowed
    #           "denied"  - Access is denied and the hook is responsible
    #                       for generating the Authenticate challenge
    #           "skip"    - Meaning the hook doesn't care about the URL,
    #                       but perhaps another access control hook does.
    #
    # Installs an access control hook

    typemethod {access install} {proc} {
        if {[lsearch $info(accessHooks) $proc] < 0} {
            lappend info(accessHooks) $proc
        }
        return
    }

    # access prepend proc
    #
    # Exactly like [access install], but puts the hook first in the list

    typemethod {access prepend} {proc} {
        if {[lsearch $info(accessHooks) $proc] < 0} {
            set info(accessHooks) [linsert $info(accessHooks) 0 $proc]
        }
        return
    }

    # access uninstall proc
    #
    # proc - An access control hook command.
    #
    # Removes an access control hook

    typemethod {access uninstall} {proc} {
        set ix [lsearch $info(accessHooks) $proc]
        if {$ix >= 0} {
            set info(accessHooks) [lreplace $info(accessHooks) $ix $ix]
        }
        return
    }

    # prefix install prefix command ?options?
    #
    # prefix  - The leading part of the URL, (e.., /foo/bar)
    # command - The domain handler command.  This is invoked with one
    #           additional argument, $sock, that is the handle identifier.
    #           A well-known state array is available at
    #           upvar #0 Httpd$sock 
    #
    # Declare that a handler exists for a point in the URL tree
    # identified by the prefix of all URLs below that point.
    #
    # Options:
    #       -callback cmd
    #           A callback to make when the request completes
    #           with or without error, timeout, etc.
    #       -readpost boolean
    #           To indicate we should pre-read POST data.

    typemethod {prefix install} {prefix command args} {
        # Add the url to the prefixset, which is a regular expression used
        # to pick off the prefix from the URL
        regsub -all {([][\\().*+?$|])} $prefix {\\\1} prefixquoted

        if {[string compare $prefix "/"] == 0} {
            # / is not in the prefixset because of some special cases.
            # See [url dispatch]
        } elseif {$info(prefixset) eq ""} {
            set info(prefixset) $prefixquoted
        } else {
            set list [split $info(prefixset) |]
            if {[lsearch $list $prefixquoted] < 0} {
                lappend list $prefixquoted
            }
            set list [lsort -command [myproc UrlSort] $list]
            set info(prefixset) [join $list |]
        }

        # Install the unquoted prefix so the Url dispatch works right

        set info(command,$prefix) $command

        # Most domains have small amounts of POST data so we read it
        # by default for them.  If you post massive amounts, create
        # a special domain that handles the post data specially.

        set readpost 1

        # Check for options on the domain
        foreach {n v} $args {
            switch -- $n {
                -callback {
                    set info(callback,$prefix) $v
                }
                -readpost {
                    set readpost $v
                }
                default {
                    return -code error "Unknown option $n.\
                                Must be -callback or -readpost"
                }
            }
        }

        set info(readpost,$prefix) $readpost
    }

    # prefix uninstall prefix
    #
    # prefix  - The leading part of the URL, (e.., /foo/bar)
    #
    # Undo a prefix registration

    typemethod {prefix uninstall} {prefix} {
        # Delete the prefix from the regular expression used to match URLs

        regsub -all {([][\\().*+?$|])} $prefix {\\\1} prefixquoted
        
        set list [split $info(prefixset) |]
        ldelete list $prefixquoted
        set info(prefixset) [join [lsort -command [myproc UrlSort] $list] |]
        
        if {[info exist info(command,$prefix)]} {
            unset info(command,$prefix)
        }

        if {[info exist info(callback,$prefix)]} {
            unset info(callback,$prefix)
        }
    }


    # UrlSort a b
    #
    # a, b   - Two URL prefixes
    #
    # Sort the URL prefixes so the longest ones are first.
    # The makes the regular expression match the longest
    # matching prefix.
    #
    # Returns 1 if b should sort before a, -1 if a should sort before b, 
    # else 0.

    proc UrlSort {a b} {
        set la [string length $a]
        set lb [string length $b]
        if {$la == $lb} {
            return [string compare $a $b]
        } elseif {$la < $lb} {
            return 1
        } else {
            return -1
        }
    }

    # pathcheck urlsuffix
    #
    # urlsuffix  - The URL after the domain prefix
    #
    # Validate a pathname.  Make sure it doesn't sneak out of its domain.
    #
    # Raises an error, or returns a list of components in the pathname

    typemethod pathcheck {urlsuffix} {
        set pathlist ""
        foreach part [split $urlsuffix /] {
            if {[string length $part] == 0} {
                # It is important *not* to "continue" here and skip
                # an empty component because it could be the last thing,
                # /a/b/c/
                # which indicates a directory.  In this case you want
                # [auth check] to recurse into the directory in the last step.
            }
            set part [$type decode $part]

            # Disallow Mac and UNIX path separators in components
            # Windows drive-letters are bad, too

            if {[regexp [fssep] $part]} {
                error "URL components cannot include [fssep]"
            }

            switch -- $part {
                .  { }
                .. {
                    set len [llength $pathlist]
                    if {[incr len -1] < 0} {
                        error "URL out of range"
                    }
                    set pathlist [lrange $pathlist 0 [incr len -1]]
                }
                default {
                    lappend pathlist $part
                }
            }
        }
        return $pathlist
    }

    # decode data
    #
    # data - A partial URL to decode. 
    #
    # Returns the decoded URL.

    typemethod decode {data} {
        regsub -all {\+} $data " " data
        regsub -all {([][$\\])} $data {\\\1} data
        regsub -all {%([0-9a-fA-F][0-9a-fA-F])} $data  {[format %c 0x\1]} data
        return [subst $data]
    }



    # posthook sock length
    #
    # Backdoor hack for [url decodequery] compatibility
    # We remember the current connection so that [url decodequery]
    # can read the post data if it has not already been read by
    # the time it is called.
    typemethod posthook {sock length} {
        set info(sock) $sock
        set info(postlength) $length
    }


    # decodequery query args
    #
    # query - A query string
    # args  - ???
    #
    # convert a x-www-urlencoded string into a list of name/value pairs

    typemethod decodequery {query args} {
        if {[info exist info(sock)]} {
            $type readpost $info(sock) query
        }
        DecodeQueryOnly $query {*}$args
    }

    # querysetup sock
    #
    # sock  - The socket back to the client.
    #
    # Grab any query data and pass it to the ncgi:: module.
    #
    # Side effects:
    #   ncgi::reset, ncgi::parse, ncgi::urlstup

    typemethod querysetup {sock} {
        upvar #0 Httpd$sock data

        set valuelist {}

        # search for comma separated pair of numbers
        # as generated from server side map
        #      e.g 190,202
        # Bjorn Ruff.

        if { [regexp {^([0-9]+),([0-9]+)$} $data(query) match x y]} {
            set data(query) x=$x&y=$y
        }

        # Honor content type of the query data
        # Some browsers leave junk Content-Type lines in
        # non-post requests as a side effect of keep alive.

        if {[info exist data(mime,content-type)] &&
            ("$data(proto)" != "GET")} {
            set ctype $data(mime,content-type)
        } else {
            set ctype application/x-www-urlencoded
        }

        # Grab POST data, if any, and initialize the ncgi:: interface
        $type readpost $sock data(query)
        ncgi::reset $data(query) $ctype
        ncgi::parse
        ncgi::urlStub $data(url)
        return
    }



    typemethod readpost {sock varname} {
        upvar 1 $varname query

        append query ""
        if {[info exist info(postlength)] && ($info(postlength) > 0)} {
            # For compatibility with older versions of the Httpd module
            # that used to read all the post data for us, we read it now
            # if it hasn't already been read

            set result $info(postlength)
            if {[string length $query]} {
                # This merges query data from the GET/POST URL
                append query &
            }
            while {$info(postlength) > 0} {
                set info(postlength) [Httpd_GetPostData $sock query]
            }
            unset info(postlength)
            return $result
        } else {
            return 0
        }
    }



    # Decode a MIME type
    # This could possibly move into the MIME module

    proc DecodeMimeField {ctype} {
        set qualList {}
        if {[regexp {([^;]+)[   ]*;[    ]*(.+)} $ctype discard ctype qualifiers]} {
            foreach qualifier [split $qualifiers \;] {
                if {[regexp {[  ]*([^=]+)="([^"]*)"} $qualifier discard name value]} {
                    #
                } elseif {[regexp {[    ]*([^=]+)='([^']*)'} $qualifier discard name value]} {
                    #
                } elseif {[regexp {[    ]*([^=]+)=([^   ]*)} $qualifier discard name value]} {
                    #
                } else {
                    continue
                }
                lappend qualList $name $value
            }
        }
        foreach {major minor} [split $type /] break
        return [list [string trim $major] [string trim $minor] $qualList]
    }

     
    # 1 leave alphanumerics characters alone
    # 2 Convert every other character to an array lookup
    # 3 Escape constructs that are "special" to the tcl parser
    # 4 "subst" the result, doing all the array substitutions
     
    typemethod encode {string} {
        regsub -all \[^a-zA-Z0-9\] $string {$encodeMap(&)} string
        regsub -all \n $string {\\n} string
        regsub -all \t $string {\\t} string
        regsub -all {[][{})\\]\)} $string {\\&} string
        return [subst $string]
    }
     
    # Url_IsLinkToSelf
    #   Compare the link to the URL of the current page.
    #   If they seem to be the same thing, return 1
    #
    # Arguments:
    #   url The URL to compare with.
    #
    # Results:
    #   1 if the input URL seems to be equivalent to the page's URL.
    #
    # Side Effects:
    #   None

    typemethod islinktoself {url} {
        global page
        return [expr {[string compare $url $page(url)] == 0}]
    }


    #-------------------------------------------------------------------
    # DecodeQueryOnly
    

    proc DecodeQueryOnly {query args} {
        array set options {-type application/x-www-urlencoded -qualifiers {}}
        catch {array set options $args}
        if {[string length [info command DecodeQuery_$options(-type)]] == 0} {
            set options(-type) application/x-www-urlencoded
        }
        return [DecodeQuery_$options(-type) $query $options(-qualifiers)]
    }

    proc DecodeQuery_application/x-www-urlencoded {query qualifiers} {
        # These foreach loops are structured this way to ensure there are matched
        # name/value pairs.  Sometimes query data gets garbled.

        set result {}
        foreach pair [split $query "&"] {
            foreach {name value} [split $pair "="] {
                lappend result [url decode $name] [url decode $value]
            }
        }
        return $result
    }

    # Sharing procedure bodies doesn't work with compiled procs,
    # so these call each other instead of doing
    # proc xprime [info args x] [info body x]

    proc DecodeQuery_application/x-www-form-urlencoded {query qualifiers} {
        DecodeQuery_application/x-www-urlencoded $query $qualifiers
    }

    # steve: 5/8/98: This is a very crude start at parsing MIME documents
    # Return filename/content pairs
    proc DecodeQuery_multipart/form-data {query qualifiers} {

        array set options {}
        catch {array set options $qualifiers}
        if {![info exists options(boundary)]} {
            return -code error "no boundary given for multipart document"
        }

        # Filter query into a list
        # Protect Tcl special characters
        # regsub -all {([\\{}])} $query {\\\\\\1} query
        regsub -all {(\\)}  $query {\\\\\\001} query
        regsub -all {(\{)}  $query {\\\\\\002} query
        regsub -all {(\})}  $query {\\\\\\003} query
        regsub -all -- "(\r?\n?--)?$options(boundary)\r?\n?" $query "\} \{" data
        set data [subst -nocommands -novariables "\{$data\}"]

        # Remove first and last list elements, which will be empty
        set data [lrange [lreplace $data end end] 1 end]

        set result {}
        foreach element $data {
            # Get the headers from the element.  Look for the first empty line.
            set headers {}
            set elementData {}
            # Protect Tcl special characters
            # regsub -all {([\\{}])} $element {\\\\\\1} element
            regsub -all {(\\)}  $element {\\\\\\001} element
            regsub -all {(\{)}  $element {\\\\\\002} element
            regsub -all {(\})}  $element {\\\\\\003} element
            regsub \r?\n\r?\n $element "\} \{" element

            foreach {headers elementData} [subst -nocommands -novariables "\{$element\}"] break

            set headerList {}
            set parameterName {}
            regsub -all \r $headers {} headers
            foreach hdr [split $headers \n] {
                if {[string length $hdr]} {

                    set headerName {}
                    set headerData {}
                    if {![regexp {[     ]*([^:  ]+)[    ]*:[    ]*(.*)} $hdr discard headerName headerData]} {
                        return -code error "malformed MIME header \"$hdr\""
                    }

                    set headerName [string tolower $headerName]
                    foreach {major minor quals} [DecodeMimeField $headerData] break
                    # restore Tcl special characters
                    regsub -all {(\\\001\001)} $quals {\\} quals
                    regsub -all {(\\\001\002)} $quals {\{} quals
                    regsub -all {(\\\001\003)} $quals {\}} quals

                    switch -glob -- [string compare content-disposition $headerName],[string compare form-data $major] {

                        0,0 {

                        # This is the name for this query parameter

                        catch {unset param}
                        array set param $quals
                        set parameterName $param(name)

                        # Include the remaining parameters, if any
                        unset param(name)
                        if {[llength [array names param]]} {
                            lappend headerList [list $headerName $major [array get param]]
                        }

                        }

                        default {

                        lappend headerList [list $headerName $major/$minor $quals]

                        }
                    }
                } else {
                    break
                }
            }

            # restore Tcl special characters
            regsub -all {(\\\001\001)} $elementData {\\} elementData
            regsub -all {(\\\001\002)} $elementData "{" elementData
            regsub -all {(\\\001\003)} $elementData "}" elementData
            lappend result $parameterName [list $headerList $elementData]
        }

        return $result
    }

}




