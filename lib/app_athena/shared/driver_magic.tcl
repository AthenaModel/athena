#-----------------------------------------------------------------------
# TITLE:
#   driver_magic.tcl
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#    Athena Driver Assessment Model (DAM): MAGIC
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# MAGIC

driver type define MAGIC {mad_id} {
    #-------------------------------------------------------------------
    # Public Type Methods

    # assess fdict
    #
    # fdict - A MAGIC rule firing dictionary; see "ruleset", below.
    #
    # Assesses a particular magic input.

    typemethod assess {fdict} {
        # FIRST, if the rule set is inactive, skip it.
        if {![parmdb get dam.MAGIC.active]} {
            log warning MAGIC \
                "driver type has been deactivated"
            return
        }

        $type ruleset $fdict
    }

    #-------------------------------------------------------------------
    # Narrative Type Methods

    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {signature} {
        # The signature is the mad_id
        return [rdb onecolumn {
            SELECT narrative FROM mads WHERE mad_id=$signature
        }]
    }

    # narrative fdict
    #
    # fdict - Firing dictionary
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        switch -exact -- $atype {
            coop { set crv "$f,$g" }
            hrel { set crv "$f,$g" }
            sat  { set crv "$g,$c" }
            vrel { set crv "$g,$a" }
            default {error "unexpected atype: \"$atype\""}
        }

        return "MAD {mad:$mad_id} $atype $mode $crv [format %.1f $mag]"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        # FIRST, load the mad data.
        rdb eval {
            SELECT * FROM mads WHERE mad_id=$mad_id
        } mad {}

        $ht link my://app/mad/$mad_id "MAD $mad_id"
        $ht put ": $mad(narrative)"
        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: MAGIC -- Magic Attitude Drivers

    # ruleset fdict
    #
    # fdict - Dictionary containing MAD data
    #
    #   dtype   - MAGIC
    #   mad_id  - MAD ID
    #   atype   - coop | hrel | sat | vrel
    #   mode    - P | T
    #   cause   - The cause, or UNIQUE for a unique cause
    #   mag     - Magnitude (numeric)
    #   f       - group (if coop or hrel)
    #   g       - group (if coop, hrel, sat, or vrel)
    #   c       - concern (if sat)
    #   a       - actor (if vrel)
    #
    # Executes the rule set for the magic input

    typemethod ruleset {fdict} {
        dict with fdict {}
        log detail MAGIC $fdict

        # FIRST, get group populations, so that we can skip empty
        # civilian groups.
        set fpop 1
        set gpop 1

        if {[dict exists $fdict f] && $f in [civgroup names]} {
            set fpop [demog getg $f population]
        }

        if {$g in [civgroup names]} {
            set gpop [demog getg $g population]
        }

        # NEXT, load the mad data.
        rdb eval {
            SELECT * FROM mads WHERE mad_id=$mad_id
        } mad {}

        # NEXT, get the cause.  Passing "" will make URAM use the
        # numeric driver ID as the numeric cause ID.
        if {$mad(cause) eq "UNIQUE"} {
            set mad(cause) ""
        }

        lappend opts \
            -cause $mad(cause) \
            -s     $mad(s)     \
            -p     $mad(p)     \
            -q     $mad(q)

        # NEXT, here are the rules.

        dam rule MAGIC-1-1 $fdict -cause $mad(cause) {
            $atype eq "hrel" && $fpop > 0 && $gpop > 0
        } {
            dam hrel $mode $f $g $mag
        }

        dam rule MAGIC-2-1 $fdict -cause $mad(cause) {
            $atype eq "vrel" && $gpop > 0
        } {
            dam vrel $mode $g $a $mag
        }

        dam rule MAGIC-3-1 $fdict {*}$opts {
            $atype eq "sat" && $gpop > 0
        } {
            dam sat $mode $g $c $mag
        }

        dam rule MAGIC-4-1 $fdict {*}$opts {
            $atype eq "coop" && $fpop > 0
        } {
            dam coop $mode $f $g $mag
        }
    }
}


