#-----------------------------------------------------------------------
# TITLE:
#    inject_hrel.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): HREL(f, g, mag) inject
#
#    This module implements the HREL inject, which affects the horizontal
#    relationship of each group in the f fole with each group in the g
#    role.
#
# PARAMETER MAPPING:
#
#    f   <= f
#    g   <= g
#    mag <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# INJECT: HREL

inject type define HREL {f g mag} {
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
            return "Change horizontal relationships of groups in $f with groups in $g by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {}

        set rtype [inject roletype $curse_id $g]

        # FIRST, 'g' must be a GROUPS role
        if {$rtype eq "ACTORS"} {
            lappend errors \
                "Role $g is ACTORS role, must be GROUPS role."
        }

        set rtype [inject roletype $curse_id $f]

        # NEXT, 'f' must alos be a GROUPS role
        if {$rtype eq "ACTORS"} {
            lappend errors \
                "Role $f is ACTORS role, must be GROUPS role."
        }

        return [join $errors "  "]
    }
}

# INJECT:HREL:CREATE
#
# Creates a new HREL inject.

order define INJECT:HREL:CREATE {
    title "Create Inject: Horizontal Relationship"

    options -sendstates PREP

    form {
        rcc "CURSE ID:" -for curse_id 
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Group Role:" -for ftype
        selector ftype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {::inject rolenames HREL f $curse_id}
            }
        }

        rcc "With Group Role:" -for gtype 
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames HREL g $curse_id}
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
    prepare ftype    -toupper   -required -selector
    prepare gtype    -toupper   -required -selector
    prepare f        -toupper   -required -type roleid
    prepare g        -toupper   -required -type roleid
    prepare mag -num -toupper   -required -type qmag

    validate g {
        if {$parms(f) eq $parms(g)} {
            reject g "Inject requires two distinct roles"
        }
    }

    returnOnError -final

    # NEXT, put inject_type in the parmdict
    set parms(inject_type) HREL

    # NEXT, create the inject
    setundo [inject mutate create [array get parms]]
}

# INJECT:HREL:UPDATE
#
# Updates existing HREL inject.

order define INJECT:HREL:UPDATE {
    title "Update Inject: Horizontal Relationship"
    options -sendstates PREP 

    form {
        rcc "Inject:" -for id
        key id -context yes -table gui_injects_HREL \
            -keys {curse_id inject_num} \
            -loadcmd {orderdialog keyload id {f g mag mode}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist}

        rcc "Of Group Role:" -for f
        selector ftype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {::inject rolenames HREL f [lindex $id 0]}
            }
        }

        rcc "With Group Role:" -for g 
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames HREL g [lindex $id 0]}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare the parameters
    prepare id         -required -type inject
    prepare mode       -tolower  -type einputmode
    prepare ftype      -toupper  -selector
    prepare gtype      -toupper  -selector
    prepare f          -toupper  -type roleid
    prepare g          -toupper  -type roleid
    prepare mag   -num -toupper  -type qmag

    validate g {
        if {$parms(f) eq $parms(g)} {
            reject g "Inject requires two distinct roles"
        }
    }

    returnOnError -final

    # NEXT, modify the inject
    setundo [inject mutate update [array get parms]]
}


