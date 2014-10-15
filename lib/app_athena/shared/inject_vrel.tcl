#-----------------------------------------------------------------------
# TITLE:
#    inject_vrel.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): VREL(g, a, mag) inject
#
#    This module implements the VREL inject, which affects the vertical
#    relationship of each group in the g role with each actor in the a
#    role.
#
# PARAMETER MAPPING:
#
#    g   <= g
#    a   <= a
#    mag <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# INJECT: VREL

inject type define VREL {g a mag} {
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
            return "Change vertical relationships of groups in role $g with actors in role $a by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {}

        set rtype [inject roletype $curse_id $a]

        # FIRST, 'a' must me an ACTORS role
        if {$rtype ne "ACTORS"} {
            lappend errors \
                "Role $a is $rtype role, must be an ACTORS role."
        }

        set rtype [inject roletype $curse_id $g]

        # NEXT, 'g' must be a GROUPS role
        if {$rtype eq "ACTORS"} {
            lappend errors \
                "Role $g is ACTORS role, must be GROUPS role."
        }

        return [join $errors "  "]
    }
}

# INJECT:VREL:CREATE
#
# Creates a new VREL inject.

order define INJECT:VREL:CREATE {
    title "Create Inject: Vertical Relationship"

    options -sendstates PREP

    form {
        rcc "CURSE ID:" -for curse_id
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group Role:" -for g 
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames VREL g $curse_id}
            }
        }

        rcc "With Actor Role:" -for a
        selector atype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for a
                label "@"
                text a
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for a
                enum a -listcmd {::inject rolenames VREL a $curse_id}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare and validate the parameters
    prepare curse_id -toupper   -required -type curse
    prepare mode     -tolower   -required -type einputmode
    prepare gtype    -toupper   -required -selector
    prepare atype    -toupper   -required -selector
    prepare g        -toupper   -required -type roleid
    prepare a        -toupper   -required -type roleid
    prepare mag -num -toupper   -required -type qmag
 
    validate a {
        if {$parms(g) eq $parms(a)} {
            reject a "Inject requires two distinct roles"
        }
    }

    returnOnError -final

    # NEXT, put inject_type in the parmdict
    set parms(inject_type) VREL

    # NEXT, create the inject
    setundo [inject mutate create [array get parms]]
}

# INJECT:VREL:UPDATE
#
# Updates existing VREL inject.

order define INJECT:VREL:UPDATE {
    title "Update Inject: Vertical Relationship"
    options -sendstates PREP 

    form {
        rcc "Inject:" -for id
        key id -context yes -table gui_injects_VREL \
            -keys {curse_id inject_num} \
            -loadcmd {orderdialog keyload id {g a mode mag}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist}

        rcc "Of Group Role:" -for g 
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames VREL g [lindex $id 0]}
            }
        }

        rcc "With Actor Role:" -for a
        selector atype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for a
                label "@"
                text a
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for a
                enum a -listcmd {::inject rolenames VREL a [lindex $id 0]}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare the parameters
    prepare id    -required           -type inject
    prepare mode            -tolower  -type  einputmode
    prepare gtype           -toupper  -selector
    prepare atype           -toupper  -selector
    prepare g               -toupper  -type roleid
    prepare a               -toupper  -type roleid
    prepare mag   -num      -toupper  -type qmag

    returnOnError -final

    # NEXT, modify the inject
    setundo [inject mutate update [array get parms]]
}


