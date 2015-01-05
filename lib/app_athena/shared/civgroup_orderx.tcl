#-----------------------------------------------------------------------
# TITLE:
#    civgroup_orderx.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_athena(n): Civgroup Orders
#
#    This is an experimental mock-up of what the civilian group orders
#    might look like using the orderx order processing scheme.
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# civgroup Order Classes

myorders define CIVGROUP:CREATE {
    superclass ::athena_order

    meta title      "Create Civilian Group"
    meta sendstates {PREP}
    meta defaults   {
        g         ""
        longname  ""
        n         ""
        bsid      1
        color     "#45DD11"
        demeanor  AVERAGE
        basepop   10000
        pop_cr    0.0
        sa_flag   0
        lfp       60
        housing   AT_HOME
        hist_flag 0
        upc       0.0
    }

    meta form {
        rcc "Group:" -for g
        text g

        rcc "Long Name:" -for longname
        longname longname

        rcc "Nbhood:" -for n
        nbhood n

        rcc "Belief System:" -for bsid
        enumlong bsid -dictcmd {::bsys system namedict} -showkeys yes \
            -defvalue 1

        rcc "Color:" -for color
        color color -defvalue #45DD11

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist} -defvalue AVERAGE

        rcc "Base Pop.:" -for basepop
        text basepop -defvalue 10000
        label "people"

        rcc "Pop. Change Rate:" -for pop_cr
        text pop_cr -defvalue 0.0
        label "% per year"

        rcc "Subs. Agri. Flag" -for sa_flag
        yesno sa_flag -defvalue 0

        rcc "Labor Force %" -for lfp
        text lfp -defvalue 60

        rcc "Housing" -for housing
        enumlong housing -dictcmd {ehousing deflist} -defvalue AT_HOME

        rcc "Start Mode:" -for hist_flag
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "UPC:" -for upc
                text upc -defvalue 0.0
            }
        } 
    }

    method narrative {} {
        if {$parms(g) ne ""} {
            return "[my title]: $parms(g)"
        } else {
            return "[my title]"
        }
    }

    method _validate {} {
        my prepare g -toupper -required -type ident
        my unused g
        my prepare longname  -normalize
        my prepare n         -toupper   -required -type nbhood
        my prepare bsid      -num                 -type {bsys system}
        my prepare color     -tolower   -required -type hexcolor
        my prepare demeanor  -toupper   -required -type edemeanor
        my prepare basepop   -num       -required -type iquantity
        my prepare pop_cr    -num       -required -type rpercentpm
        my prepare sa_flag              -required -type boolean
        my prepare lfp       -num       -required -type ipercent
        my prepare housing   -toupper   -required -type ehousing
        my prepare hist_flag -num                 -type snit::boolean
        my prepare upc       -num                 -type rpercent

        my returnOnError

        # NEXT, cross-validation
        my checkon lfp {
            if {$parms(sa_flag) && $parms(lfp) != 0} {
                my reject lfp \
                    {subsistence agriculture requires labor force % = 0}
            }
        }

        my checkon housing {
            if {$parms(sa_flag) && $parms(housing) ne "AT_HOME"} {
                my reject housing \
                    {subsistence agriculture can only be done "at home"}
            }
        }
    }

    method _execute {{flunky ""}} {
        # FIRST, If longname is "", defaults to ID.
        if {$parms(longname) eq ""} {
            set parms(longname) $parms(g)
        }

        # NEXT, if bsys is "", defaults to 1 (neutral)
        if {$parms(bsid) eq ""} {
            set parms(bsid) 1
        }

        # NEXT, create the group and dependent entities
        my setundo [civgroup mutate create [array get parms]]
    }
}


myorders define CIVGROUP:DELETE {
    superclass ::athena_order

    meta title      "Delete Civilian Group"
    meta sendstates PREP

    meta defaults {
        g ""
    }

    meta form {
        rcc "Group:" -for g
        civgroup g
    }

    method narrative {} {
        if {$parms(g) ne ""} {
            return "[my title]: $parms(g)"
        } else {
            return "[my title]"
        }
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare g -toupper -required -type civgroup
    }

    method _execute {{flunky ""}} {
        if {[my mode ] eq "gui"} {
            set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     [my name]                        \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you
                            really want to delete this group and all of the
                            entities that depend upon it?
                        }]]

            if {$answer eq "cancel"} {
                my cancel
            }
        }

        # NEXT, Delete the group and dependent entities
        lappend undo [civgroup mutate delete $parms(g)]
        lappend undo [absit mutate reconcile]

        my setundo [join $undo \n]

    }
}


myorders define CIVGROUP:UPDATE {
    superclass ::athena_order

    meta title      "Update Civilian Group"
    meta sendstates PREP

    meta defaults   {
        g            ""
        longname     ""
        n            ""
        bsid         ""
        color        ""
        demeanor     ""
        basepop      ""
        pop_cr       ""
        sa_flag      ""
        lfp          ""
        housing      ""
        hist_flag    ""
        upc          ""
    }

    meta form {
        rcc "Select Group:" -for g
        key g -table civgroups_view -keys g \
            -loadcmd {orderdialog keyload g *}

        rcc "Long Name:" -for longname
        longname longname

        rcc "Nbhood:" -for n
        nbhood n

        rcc "Belief System:" -for bsid
        enumlong bsid -dictcmd {::bsys system namedict} -showkeys yes

        rcc "Color:" -for color
        color color

        rcc "Demeanor:" -for demeanor
        enumlong demeanor -dictcmd {edemeanor deflist}

        rcc "Base Pop.:" -for basepop
        text basepop
        label "people"

        rcc "Pop. Change Rate:" -for pop_cr
        text pop_cr -defvalue 0.0
        label "% per year"

        rcc "Subs. Agri. Flag" -for sa_flag
        yesno sa_flag

        rcc "Labor Force %" -for lfp
        text lfp

        rcc "Housing" -for housing
        enumlong housing -dictcmd {ehousing deflist}

        rcc "Start Mode:" -for hist_flag
        selector hist_flag -defvalue 0 {
            case 0 "New Scenario" {}
            case 1 "From Previous Scenario" {
                rcc "UPC:" -for upc
                text upc -defvalue 0.0
            }
        }
    }

    method _validate {} {
        # FIRST, prepare the parameters
        my prepare g         -toupper   -required -type civgroup
        my prepare longname  -normalize
        my prepare n         -toupper   -type nbhood
        my prepare bsid      -num       -type {bsys system}
        my prepare color     -tolower   -type hexcolor
        my prepare demeanor  -toupper   -type edemeanor
        my prepare basepop   -num       -type iquantity
        my prepare pop_cr    -num       -type rpercentpm
        my prepare sa_flag              -type boolean
        my prepare lfp       -num       -type ipercent
        my prepare housing   -toupper   -type ehousing
        my prepare hist_flag -num       -type snit::boolean
        my prepare upc       -num       -type rpercent

        my returnOnError

        # NEXT, do cross validation
    
        # TBD: this works, but probably ought to be done by the class.
        # fillparms should be an orderx class helper, and the class should
        # provide a method that calls [civgroup getg]

        fillparms parms [civgroup getg $parms(g)]

        # TBD: These are the same checks that are done for civgroup
        # update.  Can we define a civgroup validator that is explicitly
        # used by these orders?
        my checkon lfp {
            if {$parms(sa_flag) && $parms(lfp) != 0} {
                my reject lfp \
                    {subsistence agriculture requires labor force % = 0}
            }
        }

        my checkon housing {
            if {$parms(sa_flag) && $parms(housing) ne "AT_HOME"} {
                my reject housing \
                    {subsistence agriculture can only be done "at home"}
            }
        }
    }


    method _execute {{flunky ""}} {
        my setundo [civgroup mutate update [array get parms]]
    }
}


