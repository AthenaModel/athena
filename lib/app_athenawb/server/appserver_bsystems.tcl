#-----------------------------------------------------------------------
# TITLE:
#    appserver_bsystems.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Belief systems
#
#    /app/bsystems
#    /app/bsystem/{system_id}
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module BSYSTEM {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /bsystems/ {bsystems/?} \
            tcl/linkdict [myproc /bsystems:linkdict] \
            text/html    [myproc /bsystems:html] {
                Links to all of the currently defined belief systems. 
            }

        appserver register /bsystem/{system_id} {bsystem/(\w+)/?} \
            text/html [myproc /bsystem:html]         \
            "Detail page for belief system {system_id}."

    }

    #-------------------------------------------------------------------
    # /bsystems: All defined belief systems
    #
    # No match parameters

    # /bsystems:linkdict udict matchArray
    #
    # tcl/linkdict of all belief systems.
    
    proc /bsystems:linkdict {udict matchArray} {
        set result [dict create]

        foreach sid [adb bsys system ids] {
            set url /app/bsystem/$sid
            set name [adb bsys system cget $sid -name]
            dict set result $url label "$name ($sid)"
            dict set result $url listIcon ::projectgui::icon::bsystem12
        }

        return $result
    }

    # /bsystems:html udict matchArray
    #
    # Tabular display of CAP data.

    proc /bsystems:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Belief Systems"
        ht title "Belief Systems"

        ht putln "The actors and groups in the scenario each have one"
        ht putln "of the following belief systems.  Note that force"
        ht putln "and organization groups inherit the belief systems"
        ht putln "of their owning actors."

        ht para

        ht table {
            "ID" "Name" "Commonality" "# of Actors" "# of Groups"
        } {
            foreach sid [adb bsys system ids] {
                # FIRST, get data.
                array set sdata [adb bsys system view $sid]

                set sdata(ac) [adb onecolumn {
                    SELECT count(bsid) FROM actors
                    WHERE bsid = $sid
                }]

                set sdata(gc) [adb onecolumn {
                    SELECT count(bsid) FROM groups_bsid_view
                    WHERE bsid = $sid
                }]

                # NEXT, format row.
                ht tr {
                    ht td center { ht link /app/bsystem/$sid $sid         }
                    ht td left   { ht link /app/bsystem/$sid $sdata(name) }
                    ht td right  { ht put $sdata(commonality)                 }
                    ht td right  { ht put $sdata(ac)                          }
                    ht td right  { ht put $sdata(gc)                          }
                }
            }
        }

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /bsystem/{system_id}: A single belief system {system_id}
    #
    # Match Parameters:
    #
    # {system_id} => $(1)    - The belief system's ID

    # /bsystem:html udict matchArray
    #
    # Detail page for a single belief system {system_id}

    proc /bsystem:html {udict matchArray} {
        upvar 1 $matchArray ""
       
        # FIRST, get the system ID and data.
        set sid $(1)

        if {![adb bsys system exists $sid]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        array set data [adb bsys system view $sid]

        # NEXT, Begin the page
        ht page "Belief System: $sid"
        ht title "$data(name) ($sid)" "Belief System" 

        ht linkbar {
            "#meta"     "Definition"
            "#beliefs"  "Beliefs"
            "#entities" "Actors and Groups"
        }
 
        # Definition
        ht subtitle "Definition" meta

        ht putln "This system is one of [llength [adb bsys system ids]] "
        ht putln "belief systems in this scenario."
        ht para

        ht putln "It has a commonality fraction of $data(commonality),"
        ht putln "indicating that groups and actors with this belief "
        ht putln "system have "

        if {$data(commonality) == 1.0} {
            ht put " full "
        } elseif {$data(commonality) == 0.0} {
            ht put " no "
        } else {
            ht put " partial "
        }

        ht putln "participation in the dominant culture of the playbox."
        ht para

        # Beliefs
        ht subtitle "Beliefs" beliefs

        ht putln "This system takes the following positions on the "
        ht putln "various topics of belief defined for this scenario:"

        ht para

        ht table {
            "Topic" "ID" "Position" "" "Emphasis" "" "Affinity?"
        } {
            foreach tid [adb bsys topic ids] {
                # FIRST, get data.
                array set tdata [adb bsys topic view $tid]
                array set bdata [adb bsys belief view $sid $tid]

                # NEXT, format row.
                ht tr {
                    ht td left { 
                        ht link /app/topic/$tid $tdata(name) 
                    }

                    ht td right { 
                        ht link /app/topic/$tid $tid 
                    }

                    ht td left {
                        set ptext $bdata(textpos)

                        if {$ptext eq "Ambivalent"} {
                            append ptext " Towards"
                        }
  
                        ht put $ptext
                    }

                    ht td right {
                        ht put [format "%+5.2f" $bdata(numpos)]
                    }

                    ht td left {
                        ht put $bdata(textemph)
                    }

                    ht td right {
                        ht put [format "%4.2f" $bdata(numemph)]
                    }

                    ht td center { 
                        ht put $tdata(aflag)
                    }
                }
            }
        }

        # Actors and Groups
        ht subtitle "Actors and Groups" entities

        ht putln "This system is used in the definition of the following "
        ht link /app/actors "actors"
        ht putln "and "
        ht link /app/groups "groups"
        ht put "."
        ht para

        ht query {
            SELECT longlink,
                   "Actor"
            FROM gui_actors
            WHERE bsid=$sid
            UNION
            SELECT longlink,
                   gtypelink || " Group"
            FROM gui_groups
            WHERE bsid=$sid
            ORDER BY longlink
        } -default "None found." -align LL -labels {"Name" "Type"}

        ht /page

        return [ht get]
    }
}



