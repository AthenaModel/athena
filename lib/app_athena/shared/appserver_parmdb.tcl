#-----------------------------------------------------------------------
# TITLE:
#    appserver_parmdb.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: parmdb(5)
#
#    my://app/parmdb/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module PARMDB {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /parmdb {parmdb/?} \
            tcl/linkdict [myproc /parmdb:linkdict] \
            text/html [myproc /parmdb:html] {
                An editable table displaying the contents of the
                model parameter database.  This resource can take 
                a query with two parameters; "pattern" is a wildcard
                pattern, and "subset" can be "all" or "changed".
            }
    }

    #-------------------------------------------------------------------
    # /parmdb
    #
    # No match parameters.
    
    # /parmdb:linkdict udict matcharray
    #
    # Returns a parmdb resource as a tcl/linkdict.  Does not handle
    # subsets or queries.

    proc /parmdb:linkdict {udict matchArray} {
        # FIRST, if there's a query we do nothing.
        if {[dict get $udict query] ne ""} {
            throw NOTFOUND "Resource not found"           
        }

        # NEXT, set up the linkdict.
        dict set result /parmdb?subset=changed label "Changed"
        dict set result /parmdb?subset=changed listIcon ::marsgui::icon::pencil12

        # TBD: parmset(n) doesn't have queries for the tree structure of 
        # parm names (alas); we really should be grabbing this automatically. 
        foreach subset {
            sim
            absit
            activity
            app
            attitude
            control
            dam
            demog
            econ
            force
            hist
            plant
            rmf
            service
            strategy
            uram
        } {
            set url /parmdb?pattern=$subset.*

            dict set result $url label "$subset.*"
            dict set result $url listIcon ::marsgui::icon::pencil12
        }

        return $result
    }

    # /parmdb:html udict matchArray
    #
    # Returns a page that documents the current parmdb(5) values.
    # There can be a query, in "parm=value+..." format; the following
    # parameters are allowed:
    #
    #   pattern  - A glob pattern to match
    #   subset   - "changed" or "all".  Defaults to all.

    proc /parmdb:html {udict matchArray} {
        # FIRST, get the query parms and bring them into scope.
        set qdict [querydict $udict {pattern subset}]
        dict with qdict {}

        # NEXT, are we looking at all parms or only changed parms?
        if {$subset eq "changed"} {
            set initialSet nondefaults
        } else {
            set initialSet names
        }

        # NEXT, get the base set of parms.
        if {$pattern eq ""} {
            set parms [parm $initialSet]
        } else {
            set parms [parm $initialSet $pattern]
        }

        # NEXT, get the title

        set parts [list] 

        if {$pattern ne ""} {
            lappend parts [htools escape $pattern]
        }

        if {$subset eq "changed"} {
            lappend parts "Changed"
        }

        set title "Model Parameters: "

        if {[llength $parts] == 0} {
            append title "All"
        } else {
            append title [join $parts ", "]
        }

        ht page $title
        ht title $title

        # NEXT, insert the control form.
        ht hr
        ht form 
        ht label pattern "Wildcard Pattern:"
        ht input pattern text $pattern -size 20
        ht label subset "Subset:"
        ht input subset enum $subset -src enum/parmstate -content tcl/enumdict
        ht submit
        ht /form
        ht hr
        ht para

        # NEXT, if no parameters are found, note it and return.
        if {[llength $parms] == 0} {
            ht putln "No parameters match the query."
            ht para
            
            ht /page
            return [ht get]
        }

        ht table {"Parameter" "Default Value" "Current Value" ""} {
            foreach parm $parms {
                ht tr {
                    ht td left {
                        set path [string tolower [join [split $parm .] /]]
                        ht link my://help/parmdb/$path $parm 
                    }
                    
                    ht td left {
                        set defval [htools escape [parm getdefault $parm]]
                        ht putln <tt>$defval</tt>
                    }

                    ht td left {
                        set value [htools escape [parm get $parm]]

                        if {$value eq $defval} {
                            set color black
                        } else {
                            set color "#990000"
                        }

                        ht putln "<font color=$color><tt>$value</tt></font>"
                    }

                    ht td left {
                        if {[parm islocked $parm]} {
                            ht image ::marsgui::icon::locked
                        } elseif {![adb order available PARM:SET]} {
                            ht image ::marsgui::icon::pencil22d
                        } else {
                            ht putln "<a href=\"gui:/order/PARM:SET?parm=$parm\">"
                            ht image ::marsgui::icon::pencil22
                            ht putln "</a>"
                        }
                    }
                }
            }
        }

        return [ht get]
    }
}




