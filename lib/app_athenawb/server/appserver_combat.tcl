#-----------------------------------------------------------------------
# TITLE:
#    appserver_combat.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: 
#        Combat
#
#    /app/combat/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module COMBAT {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /combats {combats/?}     \
            tcl/linkdict [myproc /combats:linkdict] \
            text/html    [myproc /combats:html]     {
                A table displaying current combat.
            }

        appserver register /combat/{n} {combat/(\w+)/?} \
            text/html [myproc /combat:html]            \
            "Detail page for combat by Nbhood {n}."
    }

    #-------------------------------------------------------------------
    # /combats:         Current combat
    #
    # Match Parameters:  None


    # /combat:linkdict udict matchArray
    #
    # tcl/linkdict of all combat in nbhoods.
    
    proc /combats:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "Combat"
            listIcon ::projectgui::icon::cannon12
            table    gui_combat
        }]
    }

    proc /combats:html {udict matchArray} {
        upvar 1 $matchArray ""

        ht page "Combat"
        ht title "Combat"

        if {[locked -disclaimer]} {
            ht para
            set totcas \
                [adb eval {
                    SELECT coalesce(sum(cas_f+cas_g),0) FROM hist_aam_battle
                }]

            ht putln "There has been a total of $totcas casualties to "
            ht put   "all force groups since time zero."
            ht para
            ht putln "The following table shows total casualties taken by "
            ht putln "force groups and total civilian casualties caused "
            ht put   "since time zero."
            ht para

            set lcas [list]

            foreach f [adb frcgroup names] {
                set casf [adb eval {
                    SELECT coalesce(sum(cas_f),0) FROM hist_aam_battle_fview
                    WHERE f=$f
                }]

                set casg [adb eval {
                    SELECT coalesce(sum(cas_g),0) FROM hist_aam_battle_fview
                    WHERE f=$f
                }]

                set civcas [adb eval {
                    SELECT coalesce(sum(civcas_f),0) FROM hist_aam_battle_fview
                    WHERE f=$f
                }]

                if {$casf == 0 && $casg == 0 && $civcas == 0} {
                    continue
                }

                lappend lcas $f $casf $casg $civcas
            }
            
            if {[llength $lcas] > 0} {
                ht table {
                    "<br>Group" "Casualties<br>Taken" "Casualties<br>Given"
                    "Civ. Casualties<br>Caused"
                } {
                    foreach {f casf casg civcas} $lcas {
                        set longname [adb frcgroup get $f longname]

                        ht tr {
                            ht td left { ht link /app/group/$f $f }
                            ht td right { ht put $casf }
                            ht td right { ht put $casg }
                            ht td right { ht put $civcas }
                        }
                    }
                }
            } else {
                ht putln "None."
            }

            ht para

            ht putln "The following battles between force groups occurred "
            ht put   "over the course of the last time tick:"
            ht para

            ht query {
                SELECT nlink    AS "Nbhood",
                       link_f   AS "Force F",
                       link_g   AS "Force G",
                       cas_f    AS "Cas. F",
                       cas_g    AS "Cas. G"
                FROM gui_battle 
                WHERE t = now() AND (cas_f > 0 OR cas_g > 0)
            } -default "None." -align LLLRR
        }

        ht para

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /combat/{n}: Combat in a single neighborhood
    #
    # Match Parameters:
    #
    # {n} => $(1)    - A neighborhood ID

    # /combat:html udict matchArray
    #
    # Detail page for a combat in a neighborhood {n}

    proc /combat:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Accumulate data
        set n $(1)

        ht page "Combat in $n"
        ht title "Combat in $n"

        ht para

        if {[locked -disclaimer]} {
            set totcas [adb eval {
                SELECT coalesce(sum(cas_f+cas_g),0) FROM hist_aam_battle 
                WHERE n=$n
            }]

            set totcivcas [adb eval {
                SELECT coalesce(sum(civcas_f+civcas_g),0) FROM hist_aam_battle 
                WHERE n=$n
            }]
            
            ht putln "There have been a total of $totcas force group casualties"
            ht putln "and $totcivcas civilian casualties in $n since time zero."

            ht para

            ht putln "The following table shows the number of casualties"
            ht putln "suffered and the number of civilian"
            ht putln "casualties caused by each force group in $n from"
            ht putln "time zero:"

            ht para

            ht query {
                SELECT longlink_f                AS "<br>Group",
                       coalesce(sum(cas_f),0)    AS "<br>Casualties",
                       coalesce(sum(civcas_f),0) AS "Civ. Cas.<br>Caused"
                FROM gui_battle_f
                WHERE n=$n
                GROUP BY f
            } -default "None." -align LRR

            ht para

            ht putln "The following table shows the combat that has taken place"
            ht putln "in $n during the last time tick:"
            ht para
            
            # NOTE: using spaces at the end of the g's data in the AS to 
            # differentiate it from f's data
            ht query {
                SELECT longlink_f,
                       sroe_f,
                       dpers_f,
                       cas_f,
                       civcas_f,
                       longlink_g,
                       sroe_g,
                       dpers_g,
                       cas_g,
                       civcas_g
                FROM gui_battle 
                WHERE t=now() AND n=$n AND (cas_f > 0 OR cas_g > 0) 
            } -default "None." -labels {
                "<br>Group" "<br>ROE" "<br>Personnel" "<br>Casualties"
                "Civ. Cas.<br>Caused" "<br>Fighting" "<br>ROE" "<br>Personnel"
                "<br>Casualties" "Civ. Cas.<br>Caused"
            } -align LRRRLRRR

        }

        ht para

        ht /page

        return [ht get]
    }
}




