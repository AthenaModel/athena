#-----------------------------------------------------------------------
# TITLE:
#    subst.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): Subst support
#
#    Stephen Uhler / Brent Welch (c) 1997-1998 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and 
#    redistribution of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#----------------------------------------------------------------------

snit::type ::ahttpd::docsubst {
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Type Variables

    # info array - 
    # 
    # templateScope - 0 for global, 1 for local

    typevariable info -array {
        templateScope 0
    }
    
    #-------------------------------------------------------------------
    # Public Type Methods

    # init 
    #
    # Enables .subst and .auth templates.

    typemethod init {} {
        # Define content-type handlers
        ::ahttpd::doc handler application/x-tcl-auth  \
            [list ::ahttpd::docsubst application/x-tcl-auth]
        ::ahttpd::doc handler application/x-tcl-subst \
            [list ::ahttpd::docsubst application/x-tcl-subst]
    }

    
    # returnfile sock path interp
    #
    # sock    - The socket connection.
    # path    - The template file pathname.
    # interp  - The Tcl intepreter in which to subst.
    # 
    # Subst a file and return the result to the HTTP client.
    # Note that ReturnData has no Modification-Date so the result is not 
    # cached.
    #
    # Returns content to the client.
    #
    # TBD: Should this be in this module?

    typemethod returnfile {sock path {interp {}}} {
        httpd returnData $sock text/html [$type file $path $interp]
    }

    # scope scope
    #
    # scope - 0 means global and non-zero means local.
    #
    # When processing templates in the current interpreter, decide whether 
    # to use the global or local scope to process templates.
    #
    # Sets the scope for all Doc domain substs.

    typemethod scope {scope} {
        set info(templateScope) $scope
    }

    # file path ?interp?
    #
    # Subst a file or directory in an interpreter context.
    # As SubstFile except that a path which is a directory is evaluated
    # by evaluating a file $path/index.tml, and returning that as the substituted
    # value of the $path directory.
    
    typemethod file {path {interp {}}} {
        switch [file type $path] {
            file -
            link {
                return [uplevel 1 [myproc SubstFile $path $interp]]
            }
            directory {
                return [uplevel 1 [myproc SubstFile [file join $path index.tml] $interp]]
            }
            default {
                error "Can't process [file type $path] files."
            }
        }
    }

    #-------------------------------------------------------------------
    # Helper Procs

    # CleanScope _html_data
    #
    # _html_data  - The data to substitute.
    #
    # Substitute the data in this clean (no vars set) scope, returning
    # the new data.
    
    proc CleanScope {_html_data} {
        return [subst $_html_data]
    }


    # SubstFile path ?interp?
    #
    # path    - The file pathname of the template.
    # interp  - The interpreter in which to subst.
    #
    # Subst a file in an interpreter context.  If no interp is given, use 
    # the current interp.  If using the current interp, use the scope
    # variable to decide whether to use the global or current scope.
    #
    # Returns the subst'd page.

    proc SubstFile {path {interp {}}} {
        set in [open $path]
        set script [read $in]
        close $in

        if {[string length $interp] == 0} {
            # Substitution occurs in the current interp.
            if {$info(templateScope) == 0} {
                # Substitution occurs at the global level.
                set result [uplevel #0 [list subst $script]]
            } else {
                # Substitution occurs at a clean level, one-off from global.
                set result [uplevel [list CleanScope $script]]
            }
        } else {
            # Substitution occurs in the given interp.
            set result [interp eval $interp [list subst $script]]
        }

        return $result
    }

    #-------------------------------------------------------------------
    # Content Type Handlers
    

    # application/x-tcl-auth --
    #
    # Like tcl-subst, but a basic authentication cookie is used for session state
    #
    # Arguments:
    #   path    The file pathname.
    #   suffix  The URL suffix.
    #   sock    The socket connection.
    #
    # Results:
    #   None
    #
    # Side Effects:
    #   Returns a page to the client.

    typemethod application/x-tcl-auth {path suffix sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {![info exists data(session)]} {
            httpd requestAuth $sock Basic "Random Password"
            return
        }
        set interp [Session_Authorized $data(session)]

        # Need to make everything look like a GET so the Cgi parser
        # doesn't read post data from stdin.  We've already read it.
        set data(proto) GET

        $type application/x-tcl-subst $path $suffix $sock
    }

    # application/x-tcl-subst --
    #
    # Tcl-subst a template that mixes HTML and Tcl.
    # This subst is just done in the context of the specified
    # interpreter with not much other support.
    # See x-tcl-template for something more sophisticated
    #
    # Arguments:
    #   path    The file pathname.
    #   suffix  The URL suffix.
    #   sock    The socket connection.
    #   interp  The interp to use for subst'ing.
    #
    # Results:
    #   None
    #
    # Side Effects:
    #   Sets the env array in interp and calls returnfile.

    typemethod application/x-tcl-subst {path suffix sock {interp {}}} {
        upvar #0 ::ahttpd::Httpd$sock data

        cgi setenv $sock $path pass
        interp eval $interp [list uplevel #0 [list array set ::ahttpd::cgienv [array get pass]]]
        ::ahttpd::docsubst returnfile $sock $path $interp
    }

}





