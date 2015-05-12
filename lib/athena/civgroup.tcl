#-----------------------------------------------------------------------
# TITLE:
#    civgroup.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena(n): Civilian Group Manager
#
#    This module is responsible for managing civilian groups and operations
#    upon them.
#
# TBD: Global refs: app/messagebox
#
#-----------------------------------------------------------------------

snit::type ::athena::civgroup {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Queries
    #
    # These routines query information about the entities; they are
    # not allowed to modify them.


    # names
    #
    # Returns the list of civgroup names

    method names {} {
        return [$adb eval {
            SELECT g FROM civgroups_view
        }]
    }


    # namedict
    #
    # Returns ID/longname dictionary

    method namedict {} {
        return [$adb eval {
            SELECT g, longname FROM civgroups_view ORDER BY g
        }]
    }

    # validate g
    #
    # g         Possibly, a civilian group short name.
    #
    # Validates a civilian group short name

    method validate {g} {
        if {![$self exists $g]} {
            set names [join [$self names] ", "]

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

    # exists g
    #
    # g - Possibly, a civ group name
    #
    # Returns 1 if the group exists and 0 otherwise.

    method exists {g} {
        return [dbexists $adb civgroups g $g]
    }

    # local names
    #
    # Returns the list of civgroup names for groups living
    # in local neighborhoods.

    method {local names} {} {
        return [$adb eval {
            SELECT g FROM local_civgroups
        }]
    }


    # local namedict
    #
    # Returns ID/longname dictionary for local civgroups.

    method {local namedict} {} {
        return [$adb eval {
            SELECT g, longname FROM local_civgroups ORDER BY g
        }]
    }

    # local validate g
    #
    # g         Possibly, a local civilian group short name.
    #
    # Validates a local civgroup short name

    method {local validate} {g} {
        if {![$adb exists {SELECT g FROM local_civgroups WHERE g=$g}]} {
            set names [join [$self local names] ", "]

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

    method gInN {g n} {
        $adb exists {
            SELECT * FROM civgroups WHERE g=$g AND n=$n
        }
    }

    # gIn n
    #
    # n      A neighborhood ID
    #
    # Returns a list of the civ groups that reside in the neighborhood.

    method gIn {n} {
        $adb eval {
            SELECT g FROM civgroups WHERE n=$n
            ORDER BY g
        }
    }

    # get g ?parm?
    #
    # g    - A group in the neighborhood
    # parm - A civgroups column name
    #
    # Retrieves a row dictionary, or a particular column value, from
    # civgroups.
    #

    method get {g {parm ""}} {
        return [dbget $adb civgroups_view g $g $parm]
    }

    # view g ?tag?
    #
    # g    - A group in the neighborhood
    # tag  - A view tag (unused)
    #
    # Retrieves a view dictionary for the group.

    method view {g {tag ""}} {
        return [dbget $adb fmt_civgroups g $g]
    }

    # check lfp/sa_flag lfp sa_flag
    #
    # lfp       - Labor force percentage
    # sa_flag   - Subsistence agriculture flag
    #
    # Throws INVALID if the civgroup parameters are inconsistent.

    method {check lfp/sa_flag} {lfp sa_flag} {
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

    method {check housing/sa_flag} {housing sa_flag} {
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

    # create parmdict
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

    method create {parmdict} {
        # FIRST, bring the dictionary entries into scope.
        dict with parmdict {}

        if {$hist_flag eq ""} {
            set hist_flag 0
        }

        if {$upc eq ""} {
            set upc 0.0
        }

        # NEXT, Put the group in the database
        $adb eval {
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
        return [mymethod UndoCreate $g]
}

    # UndoCreate g
    #
    # g - A group short name
    #
    # Undoes creation of the group.

    method UndoCreate {g} {
        $adb delete groups {g=$g} civgroups {g=$g}
    }

    # delete g
    #
    # g     A group short name
    #
    # Deletes the group.

    method delete {g} {
        # FIRST, delete the group, grabbing the undo information
        set data [$adb delete -grab groups {g=$g} civgroups {g=$g}]

        # NEXT, Return the undo script
        return [mymethod UndoDelete $data]
    }

    # UndoDelete data
    #
    # data - An $adb grab data set
    #
    # Restores the data into the $adb.

    method UndoDelete {data} {
        $adb ungrab $data
    }


    # update parmdict
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

    method update {parmdict} {
        dict with parmdict {
            # FIRST, get the undo information
            set data [$adb grab groups {g=$g} civgroups {g=$g}]

            # NEXT, Update the group
            $adb eval {
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
            return [list $adb ungrab $data]
        }
    }
}

#-----------------------------------------------------------------------
# Orders: CIVGROUP:*

# CIVGROUP:CREATE
::athena::orders define CIVGROUP:CREATE {
    meta title      "Create Civilian Group"
    meta sendstates {PREP}
    meta parmlist   {
        g
        longname
        n
        {bsid      1}
        {color     "#45DD11"}
        {demeanor  AVERAGE}
        {basepop   10000}
        {pop_cr    0.0}
        {sa_flag   0}
        {lfp       60}
        {housing   AT_HOME}
        {hist_flag 0}
        {upc       0.0}
    }

    meta form {
        rcc "Group:" -for g
        text g

        rcc "Long Name:" -for longname
        longname longname

        rcc "Nbhood:" -for n
        nbhood n

        rcc "Belief System:" -for bsid
        enumlong bsid -dictcmd {$adb_ bsys system namedict} -showkeys yes \
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
        my prepare n         -toupper   -required -type [list $adb nbhood]
        my prepare bsid      -num                 -type [list $adb bsys system]
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
            $adb civgroup check lfp/sa_flag $parms(lfp) $parms(sa_flag)
        }

        my checkon housing {
            $adb civgroup check housing/sa_flag $parms(housing) $parms(sa_flag)
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
        my setundo [$adb civgroup create [array get parms]]
    }
}

# CIVGROUP:DELETE
::athena::orders define CIVGROUP:DELETE {
    meta title      "Delete Civilian Group"
    meta sendstates PREP

    meta parmlist   { g }

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
        my prepare g -toupper -required -type [list $adb civgroup]
    }

    method _execute {{flunky ""}} {
        lappend undo [$adb civgroup delete $parms(g)]
        lappend undo [$adb absit reconcile]

        my setundo [join $undo \n]

    }
}

# CIVGROUP:UPDATE
::athena::orders define CIVGROUP:UPDATE {
    meta title      "Update Civilian Group"
    meta sendstates PREP
    meta parmlist   {
        g        
        longname 
        n        
        bsid     
        color    
        demeanor 
        basepop  
        pop_cr   
        sa_flag  
        lfp      
        housing  
        hist_flag
        upc      
    }

    meta form {
        rcc "Select Group:" -for g
        dbkey g -table civgroups_view -keys g \
            -loadcmd {$order_ keyload g *}

        rcc "Long Name:" -for longname
        longname longname

        rcc "Nbhood:" -for n
        nbhood n

        rcc "Belief System:" -for bsid
        enumlong bsid -dictcmd {$adb_ bsys system namedict} -showkeys yes

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
        my prepare g         -toupper   -required -type [list $adb civgroup]
        my prepare longname  -normalize
        my prepare n         -toupper   -type [list $adb nbhood]
        my prepare bsid      -num       -type [list $adb bsys system]
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
        ::athena::fillparms parms [$adb civgroup get $parms(g)]

        my checkon lfp {
            $adb civgroup check lfp/sa_flag $parms(lfp) $parms(sa_flag)
        }

        my checkon housing {
            $adb civgroup check housing/sa_flag $parms(housing) $parms(sa_flag)
        }
    }


    method _execute {{flunky ""}} {
        my setundo [$adb civgroup update [array get parms]]
    }
}


