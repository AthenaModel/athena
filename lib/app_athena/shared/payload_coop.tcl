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

order define PAYLOAD:COOP:CREATE {
    title "Create Payload: Cooperation"

    options -sendstates PREP

    form {
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
} {
    # FIRST, prepare and validate the parameters
    prepare iom_id   -toupper   -required -type iom
    prepare g        -toupper   -required -type frcgroup
    prepare mag -num -toupper   -required -type qmag

    returnOnError -final

    # NEXT, put payload_type in the parmdict
    set parms(payload_type) COOP

    # NEXT, create the payload
    setundo [payload mutate create [array get parms]]
}

# PAYLOAD:COOP:UPDATE
#
# Updates existing COOP payload.

order define PAYLOAD:COOP:UPDATE {
    title "Update Payload: Cooperation"
    options -sendstates PREP 

    form {
        rcc "Payload:" -for id
        key id -context yes -table gui_payloads_COOP \
            -keys {iom_id payload_num} \
            -loadcmd {orderdialog keyload id {g mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Force Group:" -for g
        frcgroup g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare the parameters
    prepare id         -required -type payload
    prepare g          -toupper  -type frcgroup
    prepare mag   -num -toupper  -type qmag

    returnOnError -final

    # NEXT, modify the payload
    setundo [payload mutate update [array get parms]]
}


