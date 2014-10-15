#-----------------------------------------------------------------------
# TITLE:
#    wizdummy.tcl
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
#    wizdummy(n): A wizard manager page for choosing an
#    athena scenario.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# wizdummy widget


snit::widget ::wintel::wizdummy {
    #-------------------------------------------------------------------
    # Layout

    # The HTML layout for this widget.
    typevariable layout {
        Not Implemented Yet
    }
    
    #-------------------------------------------------------------------
    # Components

    component hframe     ;# htmlframe(n) widget to contain the content.
    
    #-------------------------------------------------------------------
    # Options

    delegate option * to hull

    #-------------------------------------------------------------------
    # Variables

    # Info array: wizard data
    #

    variable info -array {
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

        # NEXT, create the other widgets.
        # TBD

        # NEXT, lay it out.
        $hframe layout $layout
    }

    #-------------------------------------------------------------------
    # Event handlers


    #-------------------------------------------------------------------
    # Wizard Page Interface

    # enter
    #
    # This command is called when wizman selects this page for
    # display.  It should do any necessary set up (i.e., pull
    # data from the data model).

    method enter {} {
        # Nothing to do
    }


    # finished
    #
    # This command is called to determine whether or not the user has
    # completed all necessary tasks on this page.  It returns 1
    # if we can go on to the next page, and 0 otherwise.

    method finished {} {
        return 1
    }


    # leave
    #
    # This command is called when the user presses the wizman's
    # "Next" button to go on to the next page.  It should trigger
    # any processing that needs to be done as the result of the
    # choices made on this page, before the next page is entered.

    method leave {} {
        # Nothing to do
    }
}