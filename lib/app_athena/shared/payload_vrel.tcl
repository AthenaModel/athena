#-----------------------------------------------------------------------
# TITLE:
#    payload_vrel.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): VREL(g,mag) payload
#
#    This module implements the VREL payload, which affects the vertical
#    relationship of covered civilian groups with a specific actor.
#
# PARAMETER MAPPING:
#
#    a    <= a
#    mag  <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# PAYLOAD: VREL

payload type define VREL {a mag} {
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
            return "Change vertical relationships with $a by $points points ($symbol)."
        }
    }

    typemethod check {pdict} {
        set errors [list]

        dict with pdict {
            if {$a ni [actor names]} {
                lappend errors "Actor $a no longer exists."
            }
        }

        return [join $errors "  "]
    }
}

# PAYLOAD:VREL:CREATE
#
# Creates a new VREL payload.

myorders define PAYLOAD:VREL:CREATE {
    meta title "Create Payload: Vertical Relationship"

    meta sendstates PREP

    meta parmlist {iom_id longname a mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Actor:" -for a
        actor a

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type iom
        my prepare a        -toupper   -required -type actor
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) VREL
    
        my setundo [payload mutate create [array get parms]]
    }
}

# PAYLOAD:VREL:UPDATE
#
# Updates existing VREL payload.

myorders define PAYLOAD:VREL:UPDATE {
    meta title "Update Payload: Vertical Relationship"
    meta sendstates PREP 

    meta parmlist {id longname a mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table gui_payloads_VREL \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {a mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Actor:" -for a
        actor a

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type payload
        my prepare a          -toupper  -type actor
        my prepare mag  -num  -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [payload mutate update [array get parms]]
    }
}


