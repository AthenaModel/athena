#-----------------------------------------------------------------------
# TITLE:
#    payload_hrel.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): HREL(g,mag) payload
#
#    This module implements the HREL payload, which affects the horizontal
#    relationship of covered civilian groups with a specific group.
#
# PARAMETER MAPPING:
#
#    g    <= g
#    mag  <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# PAYLOAD: HREL

payload type define HREL {g mag} {
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
            return "Change horizontal relationships with $g by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {
            if {$g ni [group names]} {
                lappend errors "Group $g no longer exists."
            }
        }

        return [join $errors "  "]
    }
}

# PAYLOAD:HREL:CREATE
#
# Creates a new HREL payload.

order define PAYLOAD:HREL:CREATE {
    title "Create Payload: Horizontal Relationship"

    options -sendstates PREP

    form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Group:" -for g
        group g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare and validate the parameters
    prepare iom_id   -toupper   -required -type iom
    prepare g        -toupper   -required -type group
    prepare mag -num -toupper   -required -type qmag

    returnOnError -final

    # NEXT, put payload_type in the parmdict
    set parms(payload_type) HREL

    # NEXT, create the payload
    setundo [payload mutate create [array get parms]]
}

# PAYLOAD:HREL:UPDATE
#
# Updates existing HREL payload.

order define PAYLOAD:HREL:UPDATE {
    title "Update Payload: Horizontal Relationship"
    options -sendstates PREP 

    form {
        rcc "Payload:" -for id
        key id -context yes -table gui_payloads_HREL \
            -keys {iom_id payload_num} \
            -loadcmd {orderdialog keyload id {g mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Group:" -for g
        group g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }
} {
    # FIRST, prepare the parameters
    prepare id         -required -type payload
    prepare g          -toupper  -type group
    prepare mag   -num -toupper  -type qmag

    returnOnError -final

    # NEXT, modify the payload
    setundo [payload mutate update [array get parms]]
}


