#-----------------------------------------------------------------------
# TITLE:
#    wizscenario.tcl
#
# AUTHOR:
#    Will Duquette
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# DESCRIPTION:
#    wizscenario(n): A wizard manager page for verifying that intel
#    can be ingested into the current scenario.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizscenario widget


snit::widget ::wintel::wizscenario {
    #-------------------------------------------------------------------
    # Layout

    # The HTML layout for this widget.
    template proc Layout {ncount cgcount} {
        |<--
        <h1>Intel Ingestion</h1>
        
        This wizard retrieves TIGR intel messages for a given area of
        interest and time period, and helps the user ingest them into
        the current Athena scenario.<p>

        The scenario determines the area of interest, its breakdown
        into "neighborhoods", the civilian residents, and the 
        significant political, military, and economic actors.<p>

        At present, intel ingestion depends on the neighborhoods and on
        the civilian groups.<p>

        <table>
        <tr><td>Neighborhoods defined:</td>
            <td align="right">$ncount</td></tr>
        <tr><td>Civilian groups defined:</td>
            <td align="right">$cgcount</td></tr>
        </table><p>
    }
    
    #-------------------------------------------------------------------
    # Components

    component hframe     ;# htmlframe(n) widget to contain the content.
    component bbrowse    ;# "browse" button
    
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    #-------------------------------------------------------------------
    # Variables

    # Info array: wizard data
    #
    # ncount  - The number of neighborhoods in the scenario.
    # cgcount - The number of civilian groups in the scenario.
    # errmsg  - Error message for bad scenario.

    variable info -array {
        ncount  0
        cgcount 0
        errmsg  {}
    }

    #-------------------------------------------------------------------
    # Constructor
    #

    constructor {args} {
        # FIRST, set the default size of this page.
        $hull configure \
            -height 300 \
            -width  400

        pack propagate $win off

        # NEXT, create the HTML frame.
        install hframe using htmlframe $win.hframe

        pack $hframe -fill both -expand yes

        $hframe layout [Layout 0 0]
    }

    #-------------------------------------------------------------------
    # Wizard Page Interface

    # enter
    #
    # This command is called when wizman selects this page for
    # display.  It should do any necessary set up (i.e., pull
    # data from the data model).

    method enter {} {
        set info(ncount)  [llength [nbhood names]]
        set info(cgcount) [llength [civgroup names]]

        set text [Layout $info(ncount) $info(cgcount)]

        if {[$self finished]} {
            append text [outdent {
                <span style="color: darkgreen">
                Intel can be ingested into this scenario.
                Press "Next" to continue.
                </span>
            }]
        } else {
            append text [outdent {
                <span style="color: #c7001b">
                The scenario must contain at least one neighborhood and 
                one civilian group.  Please close the wizard and add
                them. 
                </span>
            }]
        }

        $hframe layout $text
    }


    # finished
    #
    # This command is called to determine whether or not the user has
    # completed all necessary tasks on this page.  It returns 1
    # if we can go on to the next page, and 0 otherwise.

    method finished {} {
        return [expr {$info(ncount) > 0 && $info(cgcount) > 0}]
    }


    # leave
    #
    # This command is called when the user presses the wizman's
    # "Next" button to go on to the next page.  It should trigger
    # any processing that needs to be done as the result of the
    # choices made on this page, before the next page is entered.

    method leave {} {
        # Nothing to do
        return
    }
}
