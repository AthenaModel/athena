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

::athena::orders define INJECT:COOP:CREATE {
    meta title "Create Inject: Cooperation"

    meta sendstates PREP

    meta parmlist {
        curse_id
        longname
        {mode transient}
        {ftype NEW}
        f
        {gtype NEW}
        g
        mag
    }

    meta form {
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


    method _validate {} {
        my prepare curse_id -toupper  -required -type curse
        my prepare mode     -tolower  -required -type einputmode
        my prepare ftype    -toupper  -required -selector
        my prepare gtype    -toupper  -required -selector
        my prepare f        -toupper  -required -type roleid
        my prepare g        -toupper  -required -type roleid
        my prepare mag -num -toupper  -required -type qmag
    
        my checkon g {
            if {$parms(f) eq $parms(g)} {
                my reject g "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        set parms(inject_type) COOP
    
        my setundo [inject mutate create [array get parms]]
    }
}

# INJECT:COOP:UPDATE
#
# Updates existing COOP inject.

::athena::orders define INJECT:COOP:UPDATE {
    meta title "Update Inject: Cooperation"
    meta sendstates PREP

    meta parmlist {
        id
        longname
        mode
        {ftype EXISTING}
        f
        {gtype EXISTING}
        g
        mag
    }

    meta form {
        rcc "Inject:" -for id
        dbkey id -context yes -table gui_injects_COOP \
            -keys {curse_id inject_num} \
            -loadcmd {$order_ keyload id {f g mag mode}}

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


    method _validate {} {
        my prepare id  -required           -type inject
        my prepare mode          -tolower  -type einputmode
        my prepare ftype         -toupper  -selector
        my prepare gtype         -toupper  -selector
        my prepare f             -toupper  -type roleid
        my prepare g             -toupper  -type roleid
        my prepare mag -num      -toupper  -type qmag
    
        my checkon g {
            if {$parms(f) eq $parms(g)} {
                my reject g "Inject requires two distinct roles"
            }
        }
    }

    method _execute {{flunky ""}} {
        my setundo [inject mutate update [array get parms]]
    }
}


