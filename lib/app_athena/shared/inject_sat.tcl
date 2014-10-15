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

order define INJECT:SAT:CREATE {
    title "Create Inject: Satisfaction"

    options -sendstates PREP

    form {
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
} {
    # FIRST, prepare and validate the parameters
    prepare curse_id   -toupper   -required -type curse
    prepare mode       -tolower   -required -type einputmode
    prepare gtype      -toupper   -required -selector
    prepare g          -toupper   -required -type roleid
    prepare c          -toupper   -required -type econcern
    prepare mag -num   -toupper   -required -type qmag

    returnOnError -final

    # NEXT, put inject_type in the parmdict
    set parms(inject_type) SAT

    # NEXT, create the inject
    setundo [inject mutate create [array get parms]]
}

# INJECT:SAT:UPDATE
#
# Updates existing SAT inject.

order define INJECT:SAT:UPDATE {
    title "Update Inject: Satisfaction"
    options -sendstates PREP 

    form {
        rcc "Inject:" -for id
        key id -context yes -table gui_injects_SAT \
            -keys {curse_id inject_num} \
            -loadcmd {orderdialog keyload id {g c mode mag}}

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
} {
    # FIRST, prepare the parameters
    prepare id    -required           -type  inject
    prepare mode            -tolower  -type  einputmode
    prepare gtype           -toupper  -selector
    prepare g               -toupper  -type  roleid
    prepare c               -toupper  -type  econcern
    prepare mag   -num      -toupper  -type  qmag


    returnOnError -final

    # NEXT, modify the inject
    setundo [inject mutate update [array get parms]]
}


