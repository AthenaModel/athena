# orders.tcl

# SIMEVENT:ACCIDENT

::wintel::orders define SIMEVENT:ACCIDENT {
    meta title "Event: Accident in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id  -required 
            -with {::wintel::pot valclass ::wintel::simevent::ACCIDENT}
        my prepare coverage  -num      -type rposfrac   
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {coverage} [array get parms]

        return
    }
}

# SIMEVENT:CIVCAS
#
# Updates existing CIVCAS event.

::wintel::orders define SIMEVENT:CIVCAS {
    meta title "Event: Civilian Casualties in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Casualties:" -for casualties
        text casualties 
        label "civilians killed"
    }
    
    method _validate {} {
        my prepare event_id   \
            -required -with {::wintel::pot valclass ::wintel::simevent::CIVCAS}
        my prepare casualties -num      -type ipositive
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {casualties} [array get parms]

        return
    }

}

# SIMEVENT:DEMO
#
# Updates existing DEMO event.

::wintel::orders define SIMEVENT:DEMO {
    meta title "Event: Demonstration in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Demonstrating Groups:" -for glist
        enumlonglist glist \
            -showkeys yes  \
            -width    30   \
            -dictcmd  {civgroup namedict}


        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id   -required \
            -with {::wintel::pot valclass ::wintel::simevent::DEMO}
        my prepare glist     -toupper -listof ::civgroup
        my prepare coverage  -num     -type   rposfrac
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {glist coverage} [array get parms]

        return
    }

}

# SIMEVENT:DROUGHT
#
# Updates existing DROUGHT event.

::wintel::orders define SIMEVENT:DROUGHT {
    meta title "Event: Drought in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Duration:" -for duration
        text duration -defvalue 1
        label "week(s)"

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id  -required -with {::wintel::pot valclass ::wintel::simevent::DROUGHT}
        my prepare duration  -num      -type ipositive
        my prepare coverage  -num      -type rposfrac
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {duration coverage} [array get parms]

        return
    }

}

# SIMEVENT:EXPLOSION
#
# Updates existing EXPLOSION event.

::wintel::orders define SIMEVENT:EXPLOSION {
    meta title "Event: Explosion in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id  -required \
            -with {::wintel::pot valclass ::wintel::simevent::EXPLOSION}
        my prepare coverage  -num      -type rposfrac
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {coverage} [array get parms]

        return
    }
}

# SIMEVENT:FLOOD
#
# Updates existing FLOOD event.

::wintel::orders define SIMEVENT:FLOOD {
    meta title "Event: Flooding in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Duration:" -for duration
        text duration -defvalue 1
        label "week(s)"

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id  -required \
            -with {::wintel::pot valclass ::wintel::simevent::FLOOD}
        my prepare duration  -num      -type ipositive
        my prepare coverage  -num      -type rposfrac
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {duration coverage} [array get parms]

        return
    }
}

# SIMEVENT:RIOT
#
# Updates existing RIOT event.

::wintel::orders define SIMEVENT:RIOT {
    meta title "Event: Riot in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Coverage:" -for coverage
        posfrac coverage
        label "Fraction of neighborhood"
    }
    
    method _validate {} {
        my prepare event_id  -required \
            -with {::wintel::pot valclass ::wintel::simevent::RIOT}
        my prepare coverage  -num      -type rposfrac
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {coverage} [array get parms]

        return
    }
}


# SIMEVENT:TRANSPORT
#
# Updates existing TRANSPORT event.

::wintel::orders define SIMEVENT:TRANSPORT {
    meta title "Event: Change in Transportation Service in Neighborhood"

    meta form {
        rcc "Event ID" -for event_id
        text event_id -context yes \
            -loadcmd {::wintel::wizard beanload}

        rcc "Change Level of Service:" -for deltap
        text deltap
        c 
        label "%"
    }
    
    method _validate {} {
        my prepare event_id  -required \
            -with {::wintel::pot valclass ::wintel::simevent::TRANSPORT}
        my prepare deltap  -num      -type rsvcpct
    }

    method _execute {{flunky ""}} {
        set e [::wintel::pot get $parms(event_id)]
        $e update_ {deltap} [array get parms]

        return
    }
}






