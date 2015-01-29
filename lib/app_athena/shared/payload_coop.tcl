#-----------------------------------------------------------------------
# TITLE:
#    payload_coop.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): COOP(g,mag) payload
#
#    This module implements the COOP payload, which affects the cooperation
#    of covered civilian groups with a specific force group.
#
# PARAMETER MAPPING:
#
#    g    <= g
#    mag  <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# PAYLOAD: COOP

payload type define COOP {g mag} {
    #-------------------------------------------------------------------
    # Public Methods

    #-------------------------------------------------------------------
    # payload(i) subcommands
    #
    # See the payload(i) man page for the signature and general
    # description of each subcommand.

    typemethod narrative {pdict} {
        dict with pdict {
            set points [format "%.1f" $mag]
            set symbol [qmag name $mag]
            return "Change cooperation with $g by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {
            if {$g ni [frcgroup names]} {
                lappend errors "Force group $g no longer exists."
            }
        }

        return [join $errors "  "]
    }
}

# PAYLOAD:COOP:CREATE
#
# Creates a new COOP payload.

::athena::orders define PAYLOAD:COOP:CREATE {
    meta title "Create Payload: Cooperation"

    meta sendstates PREP

    meta parmlist {iom_id longname g mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Force Group:" -for g
        frcgroup g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type iom
        my prepare g        -toupper   -required -type frcgroup
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) COOP
        my setundo [payload mutate create [array get parms]]
    }
}

# PAYLOAD:COOP:UPDATE
#
# Updates existing COOP payload.

::athena::orders define PAYLOAD:COOP:UPDATE {
    meta title "Update Payload: Cooperation"
    meta sendstates PREP 

    meta parmlist {id longname g mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table gui_payloads_COOP \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {g mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Force Group:" -for g
        frcgroup g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type payload
        my prepare g          -toupper  -type frcgroup
        my prepare mag   -num -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [payload mutate update [array get parms]]
    }
}


