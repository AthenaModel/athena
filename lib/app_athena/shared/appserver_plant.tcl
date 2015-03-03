#-----------------------------------------------------------------------
# TITLE:
#    appserver_plant.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: GOODS Production Infrastructure
#
#    my://app/plants
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module PLANT {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /plants/ {plants/?} \
            tcl/linkdict [myproc /plants:linkdict] \
            text/html    [myproc /plants:html] {
                Links to defined GOODS production infrastructure.
            }

        appserver register /plants/detail/  {plants/detail/?} \
            text/html  [myproc /plants/detail:html]            \
            "Links to the bins of plants under construction."

        appserver register /plant/{agent}  {plant/(\w+)/?} \
            text/html  [myproc /plant:html]            \
            "Page for agent {agent}'s infrastructure." 
    }


    #-------------------------------------------------------------------
    # /plants: Agents/Nbhoods with goods production infrastructure
    #
    # No match parameters

    # /plants:linkdict udict matchArray
    #
    # tcl/linkdict of agents the own infrastructure

    proc /plants:linkdict {udcit matchArray} {
        if {![locked]} {
            return [objects:linkdict {
                label   "Infrastructure"
                listIcon ::projectgui::icon::plant12
                table    gui_plants_alloc
            }]
        } 

        return [objects:linkdict {
            label   "Infrastructure"
            listIcon ::projectgui::icon::plant12
            table    gui_plants_na
        }]
    }

    # /plants:html udict matchArray
    #
    # Tabular display of GOODS production infrastructure data.

    proc /plants:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "GOODS Production Plants"
        ht title "GOODS Production Infrastructure"

        if {![locked]} {
            # Population adjusted for production capacity to aid in 
            # determining GOODS production plant distribution by neighborhood
            set adjpop 0.0

            adb eval {
                SELECT nbpop, pcf
                FROM plants_n_view
            } row {
                let adjpop {$adjpop + $row(nbpop)*$row(pcf)}
            }

            if {$adjpop > 0} {
                ht para

                ht put   "The following table is an estimate of GOODS "
                ht put   "production plant distribution in the playbox "
                ht put   "given the neighborhoods, owning agents and "
                ht put   "neighborhood populations currently defined. "
                ht put   "Only local neighborhoods that have consumers "
                ht putln "can contain GOODS production infrastructure."
                ht para 

                ht push

                ht table {
                    "Neighborhood" "Agent" "Shares" "Capacity<br>Factor" 
                    "Consumers" "% of GOODS<br>Production Plants"
                } {
                    adb eval {
                        SELECT n              AS n,
                               nlink          AS nlink,
                               pcf            AS pcf,
                               nbpop          AS nbpop 
                        FROM gui_plants_n
                        ORDER by nlink
                    } {
                        set totshares [adb eval {
                            SELECT total(shares) FROM plants_alloc_view
                            WHERE n=$n
                        }]

                        foreach {shares alink} [adb eval {
                            SELECT shares, alink FROM gui_plants_alloc
                            WHERE n=$n
                        }] {
                            let sharepct {double($shares)/double($totshares)}
                            let plantpct {$sharepct*$nbpop*$pcf/$adjpop*100.0}
                            set fpcf [format "%4.1f" $pcf]
                            set fpct [format "%4.1f" $plantpct]

                            ht tr {
                                ht td left  { ht put $nlink   }
                                ht td left  { ht put $alink  }
                                ht td left  { ht put $shares }
                                ht td right { ht put $fpcf   }
                                ht td right { ht put $nbpop  }
                                ht td right { ht put $fpct   }
                            }
                        }
                    }
                }

                set text [ht pop]

                if {[ht rowcount] > 0} {
                    ht put $text
                    ht para
                } else {
                    ht put "None."
                    ht para
                }

            } else {

                ht put "None."
                ht para
            }

        } else {

            if {[econ state] eq "DISABLED"} {
                ht para
                ht put "The Economic model is disabled, so the infrastructure "
                ht put "model is not in use."
                ht para
                ht /page
                return [ht get]
            }

            ht para
            ht put   "The following table shows the current laydown of "
            ht put   "GOODS production plants, owning agents and repair "
            ht put   "levels.  Plants under construction will appear in "
            ht put   "this table when they are 100% complete.  Only local "
            ht put   "neighborhoods that have consumers appear in this "
            ht putln "table." 
            ht para 

            ht query {
                SELECT nlink          AS "Neighborhood",
                       alink          AS "Agent",
                       num            AS "Plants In<br>Operation",
                       auto_maintain  AS "Automatic<br>Maintenance?",
                       rho            AS "Average<br>Repair Level"
                FROM gui_plants_na
                ORDER BY nlink
            } -default "None." -align LLLLL
        }

        ht para

        if {[locked]} {
            ht put "The following table breaks down GOODS production plants under "
            ht put "construction by neighborhood and actor into ranges of "
            ht put "percentage complete.  Clicking on "
            ht put "[ht link /plants/detail "detail"] will break construction "
            ht put "levels down even further."
            ht para

            ht push 

            ht table {
                "Nbhood" "Owner" "Total" "&lt 20%" "20%-40%" 
                "40%-60%" "60%-80%" "&gt 80%" "" 
            } {
                adb eval {
                    SELECT n, a, nlink, alink, levels
                    FROM gui_plants_build
                } {
                    array set bins {0 0 20 0 40 0 60 0 80 0}
                    set total [llength $levels]
                    foreach lvl $levels {
                        if {$lvl < 0.2} {
                            incr bins(0)
                        } elseif {$lvl >= 0.2 && $lvl < 0.4} {
                            incr bins(20)
                        } elseif {$lvl >= 0.4 && $lvl < 0.6} {
                            incr bins(40)
                        } elseif {$lvl >= 0.6 && $lvl < 0.8} {
                            incr bins(60)
                        } elseif {$lvl >= 0.8} {
                            incr bins(80)
                        }
                    }

                    ht tr {
                        ht td left {
                            ht put $nlink
                        }

                        ht td left {
                            ht put $alink
                        }

                        ht td center {
                            ht put $total
                        }

                        ht td center {
                            ht put $bins(0)
                        }

                        ht td center {
                            ht put $bins(20)
                        }

                        ht td center {
                            ht put $bins(40)
                        }

                        ht td center {
                            ht put $bins(60)
                        }

                        ht td center {
                            ht put $bins(80)
                        }

                        ht td center {
                            ht link /plants/detail/ "Detail"
                        }
                    }
                }
            }

            set text [ht pop]

            if {[ht rowcount] > 0} {
                ht putln $text
            } else {
                ht putln "None."
            }
        }

        ht /page

        return [ht get]
    }

    # /plants/detail:html udict matchArray
    #
    # Details about goods production infrastructure that is under
    # construction

    proc /plants/detail:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "GOODS Production Plants Under Construction"
        ht title "GOODS Production Plants Under Construction"

        if {![locked -disclaimer]} {
            ht /page
            return [ht get]
        }

        set data [dict create]

        adb eval {
            SELECT n, nlink, a, alink, levels
            FROM gui_plants_build
        } {
            if {![dict exists $data [list $nlink $alink]]} {
                dict set data [list $nlink $alink] {}
            }

            set pcts [lmap x $levels {appserver::PLANT::percent $x}]

            set pdict [dict create]

            foreach pct $pcts {
                if {[dict exists $pdict $pct]} {
                    let count {[dict get $pdict $pct] + 1}
                    dict set pdict $pct $count
                } else {
                    dict set pdict $pct 1
                }
            }

            set clist [list]
            foreach key [dict keys $pdict] {
                lappend clist "[dict get $pdict $key]@$key"
            }

            dict set data [list $nlink $alink] $clist
        }


        ht put {
            The following table shows the number of plants completed
            by neighborhood and actor grouped by approximate percentage
            complete.  For instance, if an actor has 10 plants under 
            construction in a neighborhood that are all within a tenth 
            of a percent of 30.0% complete then those plants are shown 
            as "10@30.0%".
        }

        ht para

        ht push

        ht table {"Nbhood" "Owner" "Plants<br>% Complete"} {
            dict with data {}

            set nalist [dict keys $data]

            foreach pair $nalist {
                lassign $pair nlink alink

                set plants [dict get $data $pair]

                if {[llength $plants] == 0} {
                    continue
                }

                ht tr {
                    ht td left {
                        ht put $nlink
                    }

                    ht td left {
                        ht put $alink
                    }

                    ht td left {
                        ht put $plants
                    }
                }
            }
        }

        set text [ht pop]

        if {[ht rowcount] > 0} {
            ht putln $text
        } else {
            ht putln "No plants under construction."
        }

        ht /page

        return [ht get]
    }
     
    #-------------------------------------------------------------------
    # /plant/{agent}:  A single {agent}'s infrastructure
    #
    # Match Parameters:
    # {agent} => $1  - The agent's short name

    # /plant:html udict matchArray
    #
    # Index page for a single agent's infrastructure

    proc /plant:html {udict matchArray} {
        upvar 1 $matchArray ""

        set a [string toupper $(1)]

        if {![adb agent exists $a]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        ht page "Agent: $a GOODS Production Infrastructure"
        ht title "Agent: $a GOODS Production Infrastructure"

        if {![locked]} {
            set adjpop 0
            adb eval {
                SELECT nbpop, pcf
                FROM plants_n_view
            } row {
                let adjpop {$adjpop + $row(nbpop)*$row(pcf)}
            }

            if {$adjpop > 0} {
                ht para

                ht put   "The following table is an estimate of GOODS "
                ht put   "production plant distribution for $a in the playbox "
                ht put   "given the neighborhoods and "
                ht put   "neighborhood populations currently defined. "
                ht put   "Only local neighborhoods that have consumers "
                ht put   "can contain GOODS production infrastructure. "
                ht para 

                ht table {
                    "Neighborhood" "Shares" "Capacity<br>Factor" 
                    "Consumers" "% of GOODS<br>Production Plants"
                } {
                    adb eval {
                        SELECT n              AS n,
                               nlink          AS nlink,
                               pcf            AS pcf,
                               nbpop          AS nbpop 
                        FROM gui_plants_n
                    } {
                        set totshares [adb eval {
                            SELECT total(shares) FROM plants_alloc_view
                            WHERE n=$n
                        }]

                        foreach {shares alink} [adb eval {
                            SELECT shares, alink FROM gui_plants_alloc
                            WHERE n=$n AND a=$a
                        }] {
                            let sharepct {double($shares)/double($totshares)}
                            let plantpct {$sharepct*$nbpop*$pcf/$adjpop*100.0}
                            set fpcf [format "%4.1f" $pcf]
                            set fpct [format "%4.1f" $plantpct]

                            ht tr {
                                ht td left  { ht put $nlink   }
                                ht td left  { ht put $shares }
                                ht td right { ht put $fpcf   }
                                ht td right { ht put $nbpop  }
                                ht td right { ht put $fpct   }
                            }
                        }
                    }
                } 
            } else {

                ht put "None."
                ht para
            }

        } else {

            if {[econ state] eq "DISABLED"} {
                ht para
                ht put "The Economic model is disabled, so the infrastructure "
                ht put "model is not in use."
                ht para
                ht /page
                return [ht get]
            }

            ht para
            ht put   "The following table shows the current laydown of "
            ht put   "GOODS production plants owned by $a and their repair "
            ht put   "levels.  Plants under construction will appear in "
            ht put   "this table when they are 100% complete.  Only local "
            ht put   "neighborhoods that have consumers appear in this "
            ht put   "table."
            ht para 

            ht query {
                SELECT nlink          AS "Neighborhood",
                       num            AS "Plants In<br>Operation",
                       auto_maintain  AS "Automatic<br>Maintenance?",
                       rho            AS "Average<br>Repair Level"
                FROM gui_plants_na WHERE a=$a
                ORDER BY nlink
            } -default "None." -align LLLL
        }

        if {![locked]} {
            ht /page
            return [ht get]
        }

        ht para

        ht put "The following table breaks down GOODS production "
        ht put "plants under construction by neighborhood into "
        ht put "ranges of percentage complete."
        ht para
        
        ht push 
        
        ht table {
            "Nbhood" "Total" "&lt 20%" "20%-40%" 
            "40%-60%" "60%-80%" "&gt 80%" 
        } {
            adb eval {
                SELECT n, nlink, levels, num
                FROM gui_plants_build
                WHERE a=$a
            } {
                array set bins {0 0 20 0 40 0 60 0 80 0}
                foreach lvl $levels {
                    if {$lvl < 0.2} {
                        incr bins(0)
                    } elseif {$lvl >= 0.2 && $lvl < 0.4} {
                        incr bins(20)
                    } elseif {$lvl >= 0.4 && $lvl < 0.6} {
                        incr bins(40)
                    } elseif {$lvl >= 0.6 && $lvl < 0.8} {
                        incr bins(60)
                    } elseif {$lvl >= 0.8} {
                        incr bins(80)
                    }
                }
        
                ht tr {
                    ht td left   { ht put $nlink    }
                    ht td center { ht put $num      }
                    ht td center { ht put $bins(0)  }
                    ht td center { ht put $bins(20) }
                    ht td center { ht put $bins(40) }
                    ht td center { ht put $bins(60) }
                    ht td center { ht put $bins(80) }
                }
            }
        }

        set text [ht pop]

        if {[ht rowcount] > 0} {
            ht putln $text
        } else {
            ht putln "$a has no plants under construction."
        }

        ht /page
        return [ht get]
    }

    # percent
    #
    # Helper proc that makes sure plants that are not yet 100% complete
    # are not reported that way

    proc percent {x} {
        set percent [format %.1f%% [expr {100*$x}]]
        
        if {$x < 1.0 && $percent eq "100.0%"} {
            return "99.9%"
        }

        return $percent
    }
}



