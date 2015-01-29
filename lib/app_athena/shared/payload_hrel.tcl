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

myorders define PAYLOAD:HREL:CREATE {
    meta title "Create Payload: Horizontal Relationship"

    meta sendstates PREP

    meta parmlist {iom_id longname g mag}

    meta form {
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


    method _validate {} {
        my prepare iom_id   -toupper   -required -type iom
        my prepare g        -toupper   -required -type group
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) HREL
    
        my setundo [payload mutate create [array get parms]]
    }
}

# PAYLOAD:HREL:UPDATE
#
# Updates existing HREL payload.

myorders define PAYLOAD:HREL:UPDATE {
    meta title "Update Payload: Horizontal Relationship"
    meta sendstates PREP 

    meta parmlist {id longname g mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table gui_payloads_HREL \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {g mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Group:" -for g
        group g

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type payload
        my prepare g          -toupper  -type group
        my prepare mag   -num -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [payload mutate update [array get parms]]
    }
}


