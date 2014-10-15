#-----------------------------------------------------------------------
# TITLE:
#    inject_coop.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    athena_sim(1): COOP(f, g, mag) inject
#
#    This module implements the COOP inject, which affects the cooperation
#    level of each civilian group in the f fole with each force group in g
#    role.
#
# PARAMETER MAPPING:
#
#    f    <= f
#    g    <= g
#    mag  <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# INJECT: COOP

inject type define COOP {f g mag} {
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
            return "Change cooperation of civilians in $f with forces in $g by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {}

        # FIRST, 'f' must be a CIVGROUPS role
        set rtype [inject roletype $curse_id $f]
        
        if {$rtype ne "CIVGROUPS"} {
            lappend errors \
                "Role $f is $rtype role, must be CIVGROUPS role."
        }

        # NEXT, 'g' must be a FRCGROUPS role
        set rtype [inject roletype $curse_id $g]

        if {$rtype ne "FRCGROUPS"} {
            lappend errors \
                "Role $g is $rtype role, must be FRCGROUPS role."
        }

        return [join $errors "  "]
    }
}

# INJECT:COOP:CREATE
#
# Creates a new COOP inject.

order define INJECT:COOP:CREATE {
    title "Create Inject: Cooperation"

    options -sendstates PREP

    form {
        rcc "CURSE ID:" -for curse_id
        text curse_id -context yes

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist} -defvalue transient

        rcc "Of Civ Group Role:" -for f
        selector ftype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {::inject rolenames COOP f $curse_id}
            }
        }

        rcc "With Force Group Role:" -for g
        selector gtype -defvalue "NEW" {
            case NEW "Define new role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames COOP g $curse_id}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare and validate the parameters
    prepare curse_id -toupper  -required -type curse
    prepare mode     -tolower  -required -type einputmode
    prepare ftype    -toupper  -required -selector
    prepare gtype    -toupper  -required -selector
    prepare f        -toupper  -required -type roleid
    prepare g        -toupper  -required -type roleid
    prepare mag -num -toupper  -required -type qmag

    validate g {
        if {$parms(f) eq $parms(g)} {
            reject g "Inject requires two distinct roles"
        }
    }

    returnOnError -final

    # NEXT, put inject_type in the parmdict
    set parms(inject_type) COOP

    # NEXT, create the inject
    setundo [inject mutate create [array get parms]]
}

# INJECT:COOP:UPDATE
#
# Updates existing COOP inject.

order define INJECT:COOP:UPDATE {
    title "Update Inject: Cooperation"
    options -sendstates PREP

    form {
        rcc "Inject:" -for id
        key id -context yes -table gui_injects_COOP \
            -keys {curse_id inject_num} \
            -loadcmd {orderdialog keyload id {f g mag mode}}

        rcc "Description:" -for longname -span 4
        disp longname -width 60

        rcc "Mode:" -for mode -span 4
        enumlong mode -dictcmd {einputmode deflist}

        rcc "Of Civ Group Role:" -for f
        selector ftype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for f
                label "@"
                text f
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for f
                enum f -listcmd {::inject rolenames COOP f [lindex $id 0]}
            }
        }

        rcc "With Force Group Role:" -for g
        selector gtype -defvalue "EXISTING" {
            case NEW "Rename role" {
                cc "Role:" -for g
                label "@"
                text g
            }

            case EXISTING "Use existing role" {
                cc "Role:" -for g
                enum g -listcmd {::inject rolenames COOP g [lindex $id 0]}
            }
        }

        rcc "Magnitude:" -for mag -span 4
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare the parameters
    prepare id  -required           -type inject
    prepare mode          -tolower  -type einputmode
    prepare ftype         -toupper  -selector
    prepare gtype         -toupper  -selector
    prepare f             -toupper  -type roleid
    prepare g             -toupper  -type roleid
    prepare mag -num      -toupper  -type qmag

    validate g {
        if {$parms(f) eq $parms(g)} {
            reject g "Inject requires two distinct roles"
        }
    }

    returnOnError -final

    # NEXT, modify the inject
    setundo [inject mutate update [array get parms]]
}


