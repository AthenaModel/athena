#-----------------------------------------------------------------------
# TITLE:
#    appserver_cap.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: CAPs
#
#    /app/caps
#    /app/cap/{k}
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module CAP {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /caps/ {caps/?} \
            tcl/linkdict [myproc /caps:linkdict] \
            text/html    [myproc /caps:html] {
                Links to all of the currently defined CAPs. HTML
                content includes CAP attributes.
            }

        appserver register /cap/{k} {cap/(\w+)/?} \
            text/html [myproc /cap:html]         \
            "Detail page for CAP {k}."
    }

    #-------------------------------------------------------------------
    # /caps: All defined caps
    #
    # No match parameters

    # /caps:linkdict udict matchArray
    #
    # tcl/linkdict of all caps.
    
    proc /caps:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "CAPs"
            listIcon ::projectgui::icon::cap12
            table    gui_caps
        }]
    }

    # /caps:html udict matchArray
    #
    # Tabular display of CAP data.

    proc /caps:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page
        ht page "CAPs"
        ht title "Communication Asset Packages (CAPs)"

        ht put "The scenario currently includes the following "
        ht put "Communication Asset Packages (CAPs):"
        ht para

        if {[locked]} {
            # NEXT, if locked things are a bit more complicated.
            # We want to get the access list as well and in a 
            # particular order
            ht push

            ht table {"Name" "Owner" "Capacity" "Cost, $" "Accessible By"} {
                adb eval {
                    SELECT k             AS k,
                           longlink      AS longlink,
                           owner         AS owner,
                           capacity      AS capacity,
                           cost          AS cost
                    FROM gui_caps
                } {
                    set alist [list]

                    # NEXT, owner first
                    lappend alist [adb onecolumn {
                        SELECT link FROM gui_actors WHERE a=$owner}]

                    # NEXT, everyone else in alphabetical order
                    adb eval {
                        SELECT A.link AS alink
                        FROM gui_actors  AS A
                        JOIN cap_access  AS C ON (C.a == A.a)
                        WHERE C.k  = $k
                        AND   C.a != $owner
                        ORDER BY C.a
                    } {
                        lappend alist $alink
                    }

                    ht tr {
                        ht td left {
                            ht put $longlink
                        }

                        ht td left {
                            ht put $owner
                        }

                        ht td right {
                            ht put $capacity
                        }

                        ht td right {
                            ht put $cost
                        }

                        ht td left {
                            ht put [join $alist ", "]
                        }
                    }
                }
            }

            set text [ht pop]

            if {[ht rowcount] > 0} {
                ht putln $text
            } else {
                ht putln "None defined."
            }


        } else {
            ht query {
                SELECT longlink      AS "Name",
                       owner         AS "Owner",
                       capacity      AS "Capacity",
                       cost          AS "Cost, $"
                FROM gui_caps
            } -default "None." -align LLRR
            
            ht para

            ht tinyi {
                More information will be available once the scenario has
                been locked.
            }

        }

        ht /page

        return [ht get]
    }

    #-------------------------------------------------------------------
    # /cap/{k}: A single cap {k}
    #
    # Match Parameters:
    #
    # {k} => $(1)    - The cap's short name

    # /cap:html udict matchArray
    #
    # Detail page for a single cap {k}

    proc /cap:html {udict matchArray} {
        upvar 1 $matchArray ""
       
        # FIRST, get the CAP name and data.
        set k [string toupper $(1)]

        adb eval {SELECT * FROM gui_caps WHERE k=$k} data {}

        # NEXT, Begin the page
        ht page "CAP: $k"
        ht title $data(fancy) "CAP" 

        ht linkbar {
            "#capaccess" "CAP Access"
            "#capcov"    "CAP Coverage"
            "#sigevents" "Significant Events"
        }
 
        ht subtitle "CAP Access" capaccess

        if {[locked -disclaimer]} {
            ht put "The following actors have access to this cap (the owner "
            ht put "is listed first):"
            
            ht para

            # NEXT, grab the owner first
            lappend alist [adb onecolumn \
                {SELECT link FROM gui_actors WHERE a=$data(owner)}]

            # NEXT, the rest of the access list, excluding the owner
            adb eval {
                SELECT A.link AS alink
                FROM gui_actors  AS A
                JOIN cap_access  AS C ON (C.a == A.a)
                WHERE C.k  = $k
                AND   C.a != $data(owner)
                ORDER BY C.a
            } {
                lappend alist $alink
            }

            ht put [join $alist ", "]
            ht para
        }

        ht subtitle "CAP Coverage" capcov
        adb eval {SELECT longname, capacity, cost FROM caps WHERE k=$k} data {}

        ht put "$data(fancy) has a capacity of $data(capacity) and a "
        ht put "cost of $data(cost) dollars. " 
        ht put "CAP Coverage is the product of capacity, neighborhood "
        ht put "coverage and group penetration."
        ht para

        ht put "Below is this CAP's coverage for each neighborhood "
        ht put "and group. Combinations where group penetration is "
        ht put "zero <b>and</b> neighborhood coverage is zero are "
        ht put "omitted."
        
        ht para

        ht query {
            SELECT nlink                       AS "Neighborhood",
                   glink                       AS "Group",
                   nbcov                       AS "Nbhood Coverage",
                   pen                         AS "Group Penetration",
                   "<b>" || capcov || "</b>"   AS "CAP Coverage"
            FROM gui_capcov WHERE k=$k AND (raw_pen > 0.0 OR raw_nbcov > 0.0)
            ORDER BY n
        } -default "None." -align LLRRR
        
        
        ht subtitle "Significant Events" sigevents

        if {[locked -disclaimer]} {
            appserver::SIGEVENTS recent $k
        }

        ht /page

        return [ht get]
    }
}



