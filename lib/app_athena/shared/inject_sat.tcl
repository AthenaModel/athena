#-----------------------------------------------------------------------
# TITLE:
#    inject_sat.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): SAT(g, c, mag) inject
#
#    This module implements the SAT inject, which affects the satisfaction
#    level of each group in the g role with concern c.
#
# PARAMETER MAPPING:
#
#    g      <= g
#    c      <= c
#    mag    <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# INJECT: SAT

inject type define SAT {g c mag} {
    #-------------------------------------------------------------------
    # Public Methods

    #-------------------------------------------------------------------
    # inject(i) subcommands
    #
    # See the inject(i) man page for the signature and general
    # description of each subcommand.

    typemethod narrative {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change satisfaction of civilians in $g with $c by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {}

        # FIRST, only CIVGROUPS role can appear in this inject
        set rtype [inject roletype $curse_id $g]

        if {$rtype ne "CIVGROUPS"} {
            lappend errors \
                "Role $g is $rtype role, must be a CIVGROUPS role."
        }

        return [join $errors "  "]
    }
}

# INJECT:SAT:CREATE
#
# Creates a new SAT inject.

::athena::orders define INJECT:SAT:CREATE {
    meta title "Create Inject: Satisfaction"

    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {mode transient}
        {gtype NEW}
        g
        c
        mag
    }

    meta form {
        rcc "CURSE ID:" -for curse_id
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Civ Group Role:" -for gtype
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames SAT g $curse_id}
            }
        }

        rcc "With:" -for c -span 4
        concern c 

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare curse_id   -toupper   -required -type curse
        my prepare mode       -tolower   -required -type einputmode
        my prepare gtype      -toupper   -required -selector
        my prepare g          -toupper   -required -type roleid
        my prepare c          -toupper   -required -type econcern
        my prepare mag -num   -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(inject_type) SAT
        my setundo [inject mutate create [array get parms]]
    }
}

# INJECT:SAT:UPDATE
#
# Updates existing SAT inject.

::athena::orders define INJECT:SAT:UPDATE {
    meta title "Update Inject: Satisfaction"
    meta sendstates PREP 

    meta parmlist {
        id
        longname
        mode
        {gtype EXISTING}
        g
        c
        mag
    }

    meta form {
        rcc "Inject:" -for id
        dbkey id -context yes -table gui_injects_SAT \
            -keys {curse_id inject_num} \
            -loadcmd {$order_ keyload id {g c mode mag}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} 

        rcc "Civ Group Role:" -for rtype
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames SAT g [lindex $id 0]}
            }
        }

        rcc "With:" -for c -span 4
        concern c

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id    -required           -type  inject
        my prepare mode            -tolower  -type  einputmode
        my prepare gtype           -toupper  -selector
        my prepare g               -toupper  -type  roleid
        my prepare c               -toupper  -type  econcern
        my prepare mag   -num      -toupper  -type  qmag
    }

    method _execute {{flunky ""}} {
        my setundo [inject mutate update [array get parms]]
    }
}


