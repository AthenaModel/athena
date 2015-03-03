#-----------------------------------------------------------------------
# TITLE:
#    appserver_topics.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Belief system topics
#
#    my://app/topics
#    my://app/topic/{topic_id}
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module topic {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /topics/ {topics/?} \
            tcl/linkdict [myproc /topics:linkdict] \
            text/html    [myproc /topics:html] {
                Links to all of the currently defined topics of belief. 
            }

        appserver register /topic/{topic_id} {topic/(\w+)/?} \
            text/html [myproc /topic:html]         \
            "Detail page for topic of belief {topic_id}."

    }

    #-------------------------------------------------------------------
    # /topics: All defined semantic topics
    #
    # No match parameters

    # /topics:linkdict udict matchArray
    #
    # tcl/linkdict of all semantic topics.
    
    proc /topics:linkdict {udict matchArray} {
        set result [dict create]

        foreach tid [adb bsys topic ids] {
            set url my://app/topic/$tid
            set name [adb bsys topic cget $tid -name]
            dict set result $url label "$name ($tid)"
            dict set result $url listIcon ::projectgui::icon::topic12
        }

        return $result
    }

    # /topics:html udict matchArray
    #
    # Tabular display of CAP data.

    proc /topics:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "Topics of Belief"
        ht title "Topics of Belief"

        ht putln "The "
        ht link my://app/bsystems "belief systems"
        ht putln { 
            of the actors and groups in the
            scenario refer to the following topics of belief:
        }
        ht para

        ht table {
            "ID" "Name" "Affects Affinity?" "# of Hooks"
        } {
            foreach tid [adb bsys topic ids] {
                # FIRST, get data.
                array set tdata [adb bsys topic view $tid]

                set tdata(hc) [adb eval {
                    SELECT count(topic_id) FROM hook_topics
                    WHERE topic_id = $tid
                }]

                # NEXT, format row.
                ht tr {
                    ht td center { ht link my://app/topic/$tid $tid         }
                    ht td left   { ht link my://app/topic/$tid $tdata(name) }
                    ht td center { ht put $tdata(aflag)                     }
                    ht td right  { ht put $tdata(hc)                        }
                }
            }
        }

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /topic/{topic_id}: A single semantic topic {topic_id}
    #
    # Match Parameters:
    #
    # {topic_id} => $(1)    - The Semantic topic's ID

    # /topic:html udict matchArray
    #
    # Detail page for a single semantic topic {topic_id}

    proc /topic:html {udict matchArray} {
        upvar 1 $matchArray ""
       
        # FIRST, get the topic ID and data.
        set tid $(1)

        if {![adb bsys topic exists $tid]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        array set data [adb bsys topic view $tid]

        # NEXT, Begin the page
        ht page "Topic of Belief: $tid"
        ht title "$data(name) ($tid)" "Topic of Belief" 

        ht linkbar {
            "#meta"      "Definition"
            "#systems"   "Belief Systems"
            "#hooks"     "Semantic Hooks"
        }
 
        # Definition
        ht subtitle "Definition" meta

        ht putln "This topic is one of [llength [adb bsys topic ids]] topics"
        ht putln "in this scenario."
        ht para

        if {$data(affinity)} {
            ht putln "It is used for computing affinities; it may also be"
        } else {
            ht putln "It is <b>not</b> used for computing affinities,"
            ht putln "but may be"
        }

        ht putln "used in the definition of "
        ht link my://app/hooks "semantic hooks"
        ht putln "for use in "
        ht link my://app/ioms "information operation messages (IOMS)"
        ht put "."

        ht para

        # Belief Systems
        ht subtitle "Belief Systems" systems

        ht putln "This topic appears in every belief system; the "
        ht putln "positions taken are as follows:"

        ht para

        ht table {
            "System" "ID" "Position" "" "Emphasis" ""
        } {
            foreach sid [adb bsys system ids] {
                # FIRST, get data.
                array set sdata [adb bsys system view $sid]
                array set bdata [adb bsys belief view $sid $tid]

                # NEXT, format row.
                ht tr {
                    ht td left { 
                        ht link my://app/system/$sid $sdata(name) 
                    }

                    ht td right { 
                        ht link my://app/system/$sid $sid 
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
                }
            }
        }


        # Semantic hooks
        ht subtitle "Semantic Hooks" hooks

        ht putln "This topic is used in the definition of the following "
        ht link my://app/hooks "semantic hooks"
        ht put "."
        ht para

        ht query {
            SELECT H.longlink             AS "Name",
                   qposition(HT.position) AS "Position"
            FROM gui_hooks AS H
            JOIN gui_hook_topics AS HT USING (hook_id)
            WHERE HT.topic_id = $tid
        } -default "None found." -align LL

        ht /page

        return [ht get]
    }
}



