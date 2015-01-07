#-----------------------------------------------------------------------
# TITLE:
#    civgroup.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Civilian Group Manager
#
#    This module is responsible for managing civilian groups and operations
#    upon them.  As such, it is a type ensemble.
#
#-----------------------------------------------------------------------

snit::type civgroup {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of civgroup names

    typemethod names {} {
        return [rdb eval {
            SELECT g FROM civgroups_view
        }]
    }


    # namedict
    #
    # Returns ID/longname dictionary

    typemethod namedict {} {
        return [rdb eval {
            SELECT g, longname FROM civgroups_view ORDER BY g
        }]
    }

    # validate g
    #
    # g         Possibly, a civilian group short name.
    #
    # Validates a civilian group short name

    typemethod validate {g} {
        if {![rdb exists {SELECT g FROM civgroups_view WHERE g=$g}]} {
            set names [join [civgroup names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid civilian group, $msg"
        }

        return $g
    }

    # local names
    #
    # Returns the list of civgroup names for groups living
    # in local neighborhoods.

    typemethod {local names} {} {
        return [rdb eval {
            SELECT g FROM local_civgroups
        }]
    }


    # local namedict
    #
    # Returns ID/longname dictionary for local civgroups.

    typemethod {local namedict} {} {
        return [rdb eval {
            SELECT g, longname FROM local_civgroups ORDER BY g
        }]
    }

    # local validate g
    #
    # g         Possibly, a local civilian group short name.
    #
    # Validates a local civgroup short name

    typemethod {local validate} {g} {
        if {![rdb exists {SELECT g FROM local_civgroups WHERE g=$g}]} {
            set names [join [civgroup local names] ", "]

            if {$names ne ""} {
                set msg "should be one of: $names"
            } else {
                set msg "none are defined"
            }

            return -code error -errorcode INVALID \
                "Invalid local civilian group, $msg"
        }

        return $g
    }

    # gInN g n
    #
    # g       A group ID
    # n       A neighborhood ID
    #
    # Returns 1 if g resides in n, and 0 otherwise.

    typemethod gInN {g n} {
        rdb exists {
            SELECT * FROM civgroups WHERE g=$g AND n=$n
        }
    }

    # gIn n
    #
    # n      A neighborhood ID
    #
    # Returns a list of the civ groups that reside in the neighborhood.

    typemethod gIn {n} {
        rdb eval {
            SELECT g FROM civgroups WHERE n=$n
            ORDER BY g
        }
    }



    # Type Method: getg
    #
    # Retrieves a row dictionary, or a particular column value, from
    # civgroups.
    #
    # Syntax:
    #   getg _g ?parm?_
    #
    #   g    - A group in the neighborhood
    #   parm - A civgroups column name

    typemethod getg {g {parm ""}} {
        # FIRST, get the data
        rdb eval {SELECT * FROM civgroups_view WHERE g=$g} row {
            if {$parm ne ""} {
                return $row($parm)
            } else {
                unset row(*)
                return [array get row]
            }
        }

        return ""
    }

    # check lfp/sa_flag lfp sa_flag
    #
    # lfp       - Labor force percentage
    # sa_flag   - Subsistence agriculture flag
    #
    # Throws INVALID if the civgroup parameters are inconsistent.

    typemethod {check lfp/sa_flag} {lfp sa_flag} {
        if {$sa_flag && $lfp != 0} {
            throw INVALID "Subsistence agriculture requires labor force % = 0"
        }
    }

    # check housing/sa_flag housing sa_flag
    #
    # housing   - ehousing(n) value
    # sa_flag   - Subsistence agriculture flag
    #
    # Throws INVALID if the civgroup parameters are inconsistent.

    typemethod {check housing/sa_flag} {housing sa_flag} {
        if {$sa_flag && $housing ne "AT_HOME"} {
            throw INVALID {Subsistence agriculture can only be done "at home"}
        }
    }

    #-------------------------------------------------------------------
    # Mutators
    #
    # Mutators are used to implement orders that change the scenario in
    # some way.  Mutators assume that their inputs are valid, and returns
    # a script of one or more commands that will undo the change.  When
    # change cannot be undone, the mutator returns the empty string.

    # mutate create parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    g          - The group's ID
    #    n          - The group's nbhood
    #    longname   - The group's long name
    #    color      - The group's color
    #    demeanor   - The group's demeanor (edemeanor(n))
    #    bsid       - The group's belief system ID.
    #    basepop    - The group's base population
    #    pop_cr     - The group's population change rate
    #    sa_flag    - The group's subsistence agriculture flag
    #    lfp        - The group's labor force percentage
    #    housing    - The group's housing (ehousing(n))
    #    hist_flag  - Historical data flag
    #    upc        - The group's initial unemployment per capita %.
    #
    # Creates a civilian group given the parms, which are presumed to be
    # valid.  Creating a civilian group requires adding entries to the
    # groups table.
    #
    # NOTE: If sa_flag is true, then lfp is necessarily 0.

    typemethod {mutate create} {parmdict} {
        # FIRST, bring the dictionary entries into scope.
        dict with parmdict {}

        if {$hist_flag eq ""} {
            set hist_flag 0
        }

        if {$upc eq ""} {
            set upc 0.0
        }

        # NEXT, Put the group in the database
        rdb eval {
            INSERT INTO
            groups(g, longname, color, demeanor, gtype, bsid)
            VALUES($g,
                   $longname,
                   $color,
                   $demeanor,
                   'CIV',
                   $bsid);

            INSERT INTO
            civgroups(g,n,basepop,pop_cr,sa_flag,lfp,housing, hist_flag, upc)
            VALUES($g,
                   $n,
                   $basepop,
                   $pop_cr,
                   $sa_flag,
                   $lfp,
                   $housing,
                   $hist_flag,
                   $upc);

            INSERT INTO sat_gc(g,c)
            SELECT $g, c FROM concerns;

            INSERT INTO coop_fg(f,g)
            SELECT $g, g FROM frcgroups;
        }

        # NEXT, Return undo command.
        return [mytypemethod UndoCreate $g]
}

    # UndoCreate g
    #
    # g - A group short name
    #
    # Undoes creation of the group.

    typemethod UndoCreate {g} {
        rdb delete groups {g=$g} civgroups {g=$g}
    }

    # mutate delete g
    #
    # g     A group short name
    #
    # Deletes the group.

    typemethod {mutate delete} {g} {
        # FIRST, delete the group, grabbing the undo information
        set data [rdb delete -grab groups {g=$g} civgroups {g=$g}]

        # NEXT, Return the undo script
        return [mytypemethod UndoDelete $data]
    }

    # UndoDelete data
    #
    # data - An RDB grab data set
    #
    # Restores the data into the RDB.

    typemethod UndoDelete {data} {
        rdb ungrab $data
    }


    # mutate update parmdict
    #
    # parmdict     A dictionary of group parms
    #
    #    g           - A group short name
    #    n           - A new nbhood, or ""
    #    longname    - A new long name, or ""
    #    color       - A new color, or ""
    #    demeanor    - A new demeanor, or "" (edemeanor(n))
    #    bsid        - A new bsid, or ""
    #    basepop     - A new basepop, or ""
    #    pop_cr      - A new pop change rate, or ""
    #    sa_flag     - A new sa_flag, or ""
    #    lfp         - A new labor force percentage, or ""
    #    housing     - A new housing, or "" (ehousing(n))
    #    hist_flag   - A new hist_flag, or ""
    #    upc         - A new upc, or ""
    #
    # Updates a civgroup given the parms, which are presumed to be
    # valid.

    typemethod {mutate update} {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            set data [rdb grab groups {g=$g} civgroups {g=$g}]

            # NEXT, Update the group
            rdb eval {
                UPDATE groups
                SET longname  = nonempty($longname, longname),
                    color     = nonempty($color,    color),
                    demeanor  = nonempty($demeanor, demeanor),
                    bsid      = nonempty($bsid,     bsid)
                WHERE g=$g;

                UPDATE civgroups
                SET n         = nonempty($n,         n),
                    basepop   = nonempty($basepop,   basepop),
                    pop_cr    = nonempty($pop_cr,    pop_cr),
                    sa_flag   = nonempty($sa_flag,   sa_flag),
                    lfp       = nonempty($lfp,       lfp),
                    housing   = nonempty($housing,   housing),
                    hist_flag = nonempty($hist_flag, hist_flag),
                    upc       = nonempty($upc,       upc)
                WHERE g=$g

            } {}

            # NEXT, Return the undo command
            return [list rdb ungrab $data]
        }
    }
}

#-----------------------------------------------------------------------
# Orders: CIVGROUP:*

# CIVGROUP:CREATE
#
# Creates new civilian groups.

order define CIVGROUP:CREATE {
    title "Create Civilian Group"

    options -sendstates PREP

    form {
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
} {
    # FIRST, prepare and validate the parameters
    prepare g         -toupper   -required -unused -type ident
    prepare longname  -normalize
    prepare n         -toupper   -required         -type nbhood
    prepare bsid      -num                         -type {bsys system}
    prepare color     -tolower   -required         -type hexcolor
    prepare demeanor  -toupper   -required         -type edemeanor
    prepare basepop   -num       -required         -type iquantity
    prepare pop_cr    -num       -required         -type rpercentpm
    prepare sa_flag              -required         -type boolean
    prepare lfp       -num       -required         -type ipercent
    prepare housing   -toupper   -required         -type ehousing
    prepare hist_flag -num                         -type snit::boolean
    prepare upc       -num                         -type rpercent

    returnOnError

    # NEXT, cross-validation
    validate lfp {
        if {$parms(sa_flag) && $parms(lfp) != 0} {
            reject lfp \
                {subsistence agriculture requires labor force % = 0}
        }
    }

    validate housing {
        if {$parms(sa_flag) && $parms(housing) ne "AT_HOME"} {
            reject housing \
                {subsistence agriculture can only be done "at home"}
        }
    }

    returnOnError -final

    # NEXT, If longname is "", defaults to ID.
    if {$parms(longname) eq ""} {
        set parms(longname) $parms(g)
    }

    # NEXT, if bsys is "", defaults to 1 (neutral)
    if {$parms(bsid) eq ""} {
        set parms(bsid) 1
    }

    # NEXT, create the group and dependent entities
    lappend undo [civgroup mutate create [array get parms]]

    setundo [join $undo \n]
}

# CIVGROUP:DELETE

order define CIVGROUP:DELETE {
    title "Delete Civilian Group"
    options -sendstates PREP

    form {
        rcc "Group:" -for g
        civgroup g
    }
} {
    # FIRST, prepare the parameters
    prepare g -toupper -required -type civgroup

    returnOnError -final

    # NEXT, make sure the user knows what he is getting into.

    if {[sender] eq "gui"} {
        set answer [messagebox popup \
                        -title         "Are you sure?"                  \
                        -icon          warning                          \
                        -buttons       {ok "Delete it" cancel "Cancel"} \
                        -default       cancel                           \
                        -onclose       cancel                           \
                        -ignoretag     CIVGROUP:DELETE                  \
                        -ignoredefault ok                               \
                        -parent        [app topwin]                     \
                        -message       [normalize {
                            Are you sure you
                            really want to delete this group and all of the
                            entities that depend upon it?
                        }]]

        if {$answer eq "cancel"} {
            cancel
        }
    }

    # NEXT, Delete the group and dependent entities
    lappend undo [civgroup mutate delete $parms(g)]
    lappend undo [absit mutate reconcile]

    setundo [join $undo \n]
}


# CIVGROUP:UPDATE
#
# Updates existing groups.

order define CIVGROUP:UPDATE {
    title "Update Civilian Group"
    options -sendstates PREP

    form {
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
} {
    # FIRST, prepare the parameters
    prepare g         -toupper   -required -type civgroup
    prepare longname  -normalize
    prepare n         -toupper   -type nbhood
    prepare bsid      -num       -type {bsys system}
    prepare color     -tolower   -type hexcolor
    prepare demeanor  -toupper   -type edemeanor
    prepare basepop   -num       -type iquantity
    prepare pop_cr    -num       -type rpercentpm
    prepare sa_flag              -type boolean
    prepare lfp       -num       -type ipercent
    prepare housing   -toupper   -type ehousing
    prepare hist_flag -num       -type snit::boolean
    prepare upc       -num       -type rpercent

    returnOnError

    # NEXT, do cross validation
    fillparms parms [civgroup getg $parms(g)]

    validate lfp {
        if {$parms(sa_flag) && $parms(lfp) != 0} {
            reject lfp \
                {subsistence agriculture requires labor force % = 0}
        }
    }

    validate housing {
        if {$parms(sa_flag) && $parms(housing) ne "AT_HOME"} {
            reject housing \
                {subsistence agriculture can only be done "at home"}
        }
    }

    returnOnError -final

    # NEXT, modify the group
    setundo [civgroup mutate update [array get parms]]
}


