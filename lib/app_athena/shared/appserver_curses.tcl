#-----------------------------------------------------------------------
# TITLE:
#    appserver_curses.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: 
#        Complex User-defined Role-based Situations and Events (CURSEs)
#
#    my://app/curses/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module CURSES {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /curses {curses/?}     \
            tcl/linkdict [myproc /curses:linkdict] \
            text/html    [myproc /curses:html]     {
                A table displaying all of the CURSEs.
            }

        appserver register /curse/{id} {curse/(\w+)/?} \
            text/html [myproc /curse:html]            \
            "Detail page for CURSEs {id}."
    }

    #-------------------------------------------------------------------
    # /curses:          All defined CURSEs
    #
    # Match Parameters:  None


    # /curses:linkdict udict matchArray
    #
    # tcl/linkdict of all CURSEs.
    
    proc /curses:linkdict {udict matchArray} {
        return [objects:linkdict {
            label    "CURSESs"
            listIcon ::projectgui::icon::blueheart12
            table    gui_curses
        }]
    }

    # /curses:html udict matchArray
    #
    # Tabular display of CURSE data; content depends on simulation state.

    proc /curses:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Begin the page.
        ht page "CURSE Attitude Drivers"
        ht title "CURSE Attitude Drivers"

        ht putln "The scenario includes the following CURSEs:"
        ht para

        ht query {
            SELECT link             AS "ID",
                   longlink         AS "Narrative",
                   cause            AS "Cause",
                   state            AS "State"
            FROM gui_curses
        } -default "None." -align LLLRRR

        ht /page

        return [ht get]
    }


    #-------------------------------------------------------------------
    # /curse/{id}: A single CURSE {id}
    #
    # Match Parameters:
    #
    # {id} => $(1)    - The curse's ID

    # /curse:html udict matchArray
    #
    # Detail page for a single curse {id}

    proc /curse:html {udict matchArray} {
        upvar 1 $matchArray ""

        # Accumulate data
        set id $(1)

        if {![adb exists {SELECT * FROM curses WHERE curse_id=$id}]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        # Begin the page
        adb eval {SELECT * FROM gui_curses WHERE curse_id=$id} data {}

        ht page "CURSE Attitude Driver: $id"
        ht title $data(fancy) "CURSE" 

        ht putln "This CURSE includes the following injects:"
        ht para
        
        ht query {
            SELECT inject_num       AS "Num",
                   inject_type      AS "Type",
                   mode             AS "Mode",
                   desc             AS "Description",
                   state            AS "State"
            FROM gui_injects
            WHERE curse_id=$id
        } -default "None." -align RLLLL
        

        # NEXT, if we're not locked we're done.
        if {![locked -disclaimer]} {
            return [ht /page]
        }

        # NEXT, get the driver ID
        set driver_id [driver get CURSE $id]

        ht para

        if {$driver_id eq ""} {
            ht putln "No injects have yet been executed for this CURSE."
            ht para
            return [ht /page]
        }

        # NEXT, get the driver data
        adb eval {SELECT * FROM gui_drivers WHERE driver_id=$driver_id} ddata {}


        ht putln \
            "Injects have been executed relative to this CURSE," \
            "all relative to driver $ddata(link).  The injects are as follows:"

        ht para

        set vars(driver_id) $driver_id
        set where {driver_id=$vars(driver_id)}

        appserver::firing query $udict vars $where

        ht para

        return [ht /page]
    }
}




