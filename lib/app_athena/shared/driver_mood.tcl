#-----------------------------------------------------------------------
# TITLE:
#    driver_mood.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n): Driver Assessment Model, MOOD driver
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# MOOD

driver type define MOOD {} {    
    #-------------------------------------------------------------------
    # Public Typemethods

    # assess 
    #
    # Monitors the mood of each civilian group relative to the last
    # control shift in the group's neighborhood; triggers the MOOD
    # rule set, if the mode has changed sufficiently.
    
    typemethod assess {} {
        # FIRST, if the rule set is inactive, skip it.
        if {![parmdb get dam.MOOD.active]} {
            log warning MOOD \
                "driver type has been deactivated"
            return
        }

        # NEXT, look for groups for which the rule set should fire.
        set threshold [parm get dam.MOOD.threshold]

        rdb eval {
            SELECT 'MOOD'             AS dtype,
                   G.g                AS g,
                   G.n                AS n,
                   UM.mood            AS moodNow,
                   HM.mood            AS moodThen,
                   UM.mood - HM.mood  AS delta,
                   C.controller       AS controller,
                   C.since            AS tc
            FROM civgroups AS G
            JOIN demog_g   AS D USING (g)
            JOIN control_n AS C  ON (C.n = G.n)
            JOIN uram_mood AS UM ON (G.g = UM.g)
            JOIN hist_mood AS HM ON (HM.g = G.g AND HM.t = C.since)
            WHERE D.population > 0
            AND abs(UM.mood - HM.mood) >= CAST ($threshold AS REAL)
        } row {
            unset -nocomplain row(*)

            bgcatch {
                $type ruleset [array get row]
            }
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
        # In this case, all MOOD firings share a single driver.
        return "Effects of changes to CIV Group MOOD"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        return "{group:$g}'s mood changed by [format %.1f $delta]"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        $ht putln "Civilian group "
        $ht link my://app/group/$g $g's
        $ht putln "mood has changed by more than "
        $ht put "[parm get dam.MOOD.threshold] points"
        $ht putln "since the last shift in the control of"
        $ht putln "neighborhood "
        $ht link my://app/nbhood/$n $n
        $ht put "."
        $ht putln "$g's mood was [format %.1f $moodThen],"
        $ht putln "and is now [format %.1f $moodNow]."
        $ht putln "Neighborhood $n has been "
        if {$controller ne ""} {
            $ht putln "controlled by actor "
            $ht link my://app/actor/$controller $controller
        } else {
            $ht putln "without a controller"
        }

        $ht putln "since [week toString $tc]."
        $ht para
    }

    #-------------------------------------------------------------------
    # Rule Set: MOOD -- significant changes in mood

    # ruleset fdict
    #
    # fdict - Dictionary containing group mood data:
    #
    #    dtype      - MOOD
    #    g          - The civilian group
    #    n          - The group's neighborhood
    #    controller - Actor in control of n
    #    moodNow    - The group's mood right now
    #    moodThen   - The group's mood at time tc
    #    delta      - The difference between the two
    #    tc         - When control of n last shifted
    #
    # Assesses changes in vertical relationships due to group mood.

    typemethod ruleset {fdict} {
        dict with fdict {}
        log detail MOOD $fdict

        # We already know that delta exceeds the threshold; all
        # we care about now is the sign.

        dam rule MOOD-1-1 $fdict {
            $delta < 0.0
        } {
            foreach a [actor names] {
                if {$a eq $controller} {
                    dam vrel T $g $a [mag/ $delta S-] "has control"
                } else {
                    dam vrel T $g $a [mag/ $delta L+] "no control"
                }
            }
        }

        dam rule MOOD-1-2 $fdict {
            $delta > 0.0
        } {
            foreach a [actor names] {
                if {$a eq $controller} {
                    dam vrel T $g $a [mag/ $delta S+] "has control"
                } else {
                    dam vrel T $g $a [mag/ $delta L-] "no control"
                }
            }
        }
    }

    #-------------------------------------------------------------------
    # Utility methods

    # mag/ factor mag
    #
    # factor   - A numeric value
    # mag      - A magnitude symbol
    #
    # NOTE: This is here, rather than in helpers.tcl, because it's
    # peculiar to this module.
    #
    # Divides |factor| by the value of the magnitude symbol.
    # We use the absolute value so that the magnitude symbol controls
    # the sign.

    proc mag/ {factor mag} {
        expr {abs($factor) / [qmag value $mag]}
    }
}










