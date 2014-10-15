#------------------------------------------------------------------------
# TITLE:
#    iom_rules.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Athena Driver Assessment Model (DAM): IOM
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# IOM

driver type define IOM {tsource iom} {
    #-------------------------------------------------------------------
    # Public Type Variables

    # resonanceCache: iom,f,asource -> resonance 
    typevariable resonanceCache -array {}

    # pdictCache: iom -> payload_id -> payload dict
    typevariable pdictCache -array {}

    #-------------------------------------------------------------------
    # Public Typemethods

    # init
    #
    # Initializes this driver type.  There are caches that must be
    # cleared on scenario unlock.

    typemethod init {} {
        notifier bind ::sim <State> $type [mytypemethod ClearCaches]
    }

    # ClearCaches
    #
    # Clear the driver caches when we return to PREP.

    typemethod ClearCaches {} {
        if {[sim state] eq "PREP"} {
            array unset resonanceCache
            array unset pdictCache
        }
    }

    # assess fdict
    #
    # fdict  - Dictionary of relevant BROADCAST tactic parameters:
    #
    #   tsource    - The actor who executed the BROADCAST tactic
    #   cap        - The CAP by which the IOM was broadcast.
    #   asource    - The attributed source (actor) of the message, or ""
    #                if none.
    #   iom        - The IOM being broadcast
    #
    # To these will be added the following:
    #
    #   f          - The influenced group
    #   capcov     - The CAP coverage
    #   adjcov     - The scaled CAP coverage
    #   resonance  - The resonance of the IOM with f
    #   regard     - The regard of f for the attributed source.
    #   accept     - The acceptability of the message from the given source.
    #
    # Calls the IOM rule set to assess the attitude effects of the 
    # broadcasted IOM's payloads.

    typemethod assess {fdict} {
        set dtype IOM

        if {![dam isactive $dtype]} {
            log warning $dtype "driver type has been deactivated"
            return
        }

        # FIRST, unpack the data
        array set data $fdict
        set data(dtype) $dtype

        # NEXT, get the model parameters we need.
        set nomCapCov [parm get dam.IOM.nominalCAPcov]

        # NEXT, determine the covered groups, and the CAPcov for each.
        # Skip empty civilian groups.
        rdb eval {
            SELECT C.g      AS f,
                   C.capcov AS capcov
            FROM capcov AS C
            JOIN demog_g AS D ON (D.g = C.g)
            WHERE D.population > 0 
            AND C.k=$data(cap) AND C.capcov > 0.0
        } {
            # FIRST, scale the capcov given the nominal CAPcov.
            set data(f)      $f
            set data(capcov) $capcov
            let data(adjcov) {$capcov / $nomCapCov}

            # NEXT, compute the resonance of the IOM with group f.
            set data(resonance) \
                [ComputeResonance $data(iom) $data(f) $data(asource)]

            # NEXT, compute the regard of group f for the attributed 
            # source.
            set data(regard) [ComputeRegard $data(f) $data(asource)] 

            # NEXT, compute the acceptability, which is the product
            # of the resonance and the regard.
            let data(accept) {$data(resonance) * $data(regard)}

            # NEXT, call the rule set for this iom and civilian group.
            set fdict [array get data]

            bgcatch {
                log detail $dtype $fdict
                $type ruleset $fdict
            }
        }
    }

    # payloads iom_id
    #
    # iom_id   - An IOM ID
    #
    # Retrieves a dictionary of payload data by payload_id for the given
    # IOM.  Note that this data is fixed after scenario lock.

    typemethod payloads {iom_id} {
        if {[info exists pdictCache($iom_id)]} {
            return $pdictCache($iom_id)
        }

        set pdict [dict create]

        rdb eval {
            SELECT * FROM payloads
            WHERE iom_id = $iom_id AND state='normal'
            ORDER BY payload_num
        } row {
            unset -nocomplain row(*)
            dict set pdict $row(payload_num) [array get row]
        }

        set pdictCache($iom_id) $pdict

        return $pdict
    }

    # ComputeResonance iom f asource
    #
    # iom     - An Info Ops Message ID
    # f       - A civilian group
    # asource - Attributed source: actor ID, or ""
    #
    # Compute the resonance of the IOM for the group.  The resonance
    # is the mam(n) congruence of the IOM's hook with the group, given
    # the entity commonality of the attributed source, as passed through
    # the Zresonance curve.
    
    proc ComputeResonance {iom f asource} {
        # FIRST, return it if we already have it.
        if {[info exists resonanceCache($iom,$f,$asource)]} {
            return $resonanceCache($iom,$f,$asource)
        }

        # FIRST, get the semantic hook
        set hook [hook getdict [iom get $iom hook_id]]

        # NEXT, get the entity commonality
        if {$asource eq ""} {
            set theta 1.0
        } else {
            set absid [actor get $asource bsid]
            set theta [bsys system cget $absid -commonality]
        }

        # NEXT, compute the congruence of the hook with the group's
        # belief system.
        set fbsid [group bsid $f]
        set congruence [bsys congruence $fbsid $theta $hook]

        # NEXT, compute the resonance
        set Zresonance [parm get dam.IOM.Zresonance]

        set result [zcurve eval $Zresonance $congruence]
        set resonanceCache($iom,$f,$asource) $result

        return $result
    }

    # ComputeRegard f asource
    #
    # f       - A civilian group
    # asource - Attributed source: actor ID, or ""
    #
    # Computes the regard of the group for the source, based on the 
    # vertical relationship between the two.  If the source is anonymous, 
    # assume a regard of 1.0.
    
    proc ComputeRegard {f asource} {
        if {$asource eq ""} {
            return 1.0
        } else {
            return [rmf frmore [vrel.ga $f $asource]]
        }
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
        lassign $signature tsource iom

        return "Broadcast of $iom by $tsource"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        return "{actor:$tsource} broadcasts {iom:$iom} to {group:$f} via {cap:$cap}"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        $ht putln "Actor "
        $ht link my://app/actor/$tsource $tsource
        $ht putln "broadcast "
        $ht link my://app/iom/$iom $iom
        $ht putln "via " 
        $ht link my://app/cap/$cap $cap

        switch -exact -- $asource {
            NONE { 
                $ht putln "anonymously"
            }
            SELF { 
                $ht putln "as himself"
            }
            default { 
                $ht putln "as "
                $ht link my://app/actor/$asource $asource
            }
        }

        $ht put ","
        $ht putln "ultimately reaching group "
        $ht link my://app/group/$f $f
        $ht putln "with a coverage of "
        $ht putln [string trim [percent $capcov]].

        $ht para

        $ht putln "The message had a resonance of [format %.2f $resonance],"
        $ht putln "and $f's regard for the attributed sender"
        $ht putln "was [format %.2f $regard].  The acceptability of the"
        $ht putln "message was therefore [format %.2f $accept]."

        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: IOM: Effects of IOM payloads
    #
    # Event.  This rule set determines the effect of an IOM on
    # a particular civilian group.

    # ruleset fdict
    #
    # fdict - Dictionary of input parameters; see [assess]
    #
    # Assesses the effect of the IOM on a particular civilian group f.

    typemethod ruleset {fdict} {
        dict with fdict {}

        # FIRST, retrieve the payload data
        set pdict [$type payloads $iom]
       
        # NEXT, get the final factor.
        set factor [expr {$adjcov*$accept}]

        # IOM-1-1
        #
        # Actor tsource has sent an IOM with a factor that affects
        # CIV group g.
        dam rule IOM-1-1 $fdict -s 0.0 {
            $factor > 0.01
        } {
            dict for {num prec} $pdict {
                dict with prec {
                    set fmag [expr {$factor * $mag }]
                    switch -exact -- $payload_type {
                        COOP { dam coop T $f $g $fmag }
                        HREL { dam hrel T $f $g $fmag }
                        SAT  { dam sat  T $f $c $fmag }
                        VREL { dam vrel T $f $a $fmag }
                        default {
                            error "Unexpected payload type: \"$payload_type\""
                        }
                    }
                }
            }
        }
    }
}





