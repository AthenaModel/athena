#-----------------------------------------------------------------------
# TITLE:
#    payload_sat.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): SAT(c,mag) payload
#
#    This module implements the SAT payload, which affects the satisfaction
#    of covered civilian groups with a specific force group.
#
# PARAMETER MAPPING:
#
#    c    <= c
#    mag  <= mag
#
#-----------------------------------------------------------------------

#-------------------------------------------------------------------
# PAYLOAD: SAT

payload type define SAT {c mag} {
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
            return "Change satisfaction with $c by $points points ($symbol)."
        }
    }
}

# PAYLOAD:SAT:CREATE
#
# Creates a new SAT payload.

::athena::orders define PAYLOAD:SAT:CREATE {
    meta title "Create Payload: Satisfaction"

    meta sendstates PREP

    meta parmlist {iom_id longname c mag}

    meta form {
        rcc "Message ID:" -for iom_id
        text iom_id -context yes

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Concern:" -for c
        concern c

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare iom_id   -toupper   -required -type iom
        my prepare c        -toupper   -required -type econcern
        my prepare mag -num -toupper   -required -type qmag
    }

    method _execute {{flunky ""}} {
        set parms(payload_type) SAT
    
        my setundo [payload mutate create [array get parms]]
    }
}

# PAYLOAD:SAT:UPDATE
#
# Updates existing SAT payload.

::athena::orders define PAYLOAD:SAT:UPDATE {
    meta title "Update Payload: Satisfaction"
    meta sendstates PREP 

    meta parmlist {id longname c mag}

    meta form {
        rcc "Payload:" -for id
        dbkey id -context yes -table gui_payloads_SAT \
            -keys {iom_id payload_num} \
            -loadcmd {$order_ keyload id {c mag}}

        rcc "Description:" -for longname
        disp longname -width 60

        rcc "With Concern:" -for c
        concern c

        rcc "Magnitude:" -for mag
        mag mag
        label "points of change"
    }


    method _validate {} {
        my prepare id         -required -type payload
        my prepare c          -toupper  -type econcern
        my prepare mag   -num -toupper  -type qmag
    }

    method _execute {{flunky ""}} {
        my setundo [payload mutate update [array get parms]]
    }
}


