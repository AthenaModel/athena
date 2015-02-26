#-----------------------------------------------------------------------
# TITLE:
#    sigeventbrowser.tcl
#
# AUTHORS:
#    Will Duquette
#
# DESCRIPTION:
#    sigeventbrowser(sim) package: Significant Events Browser
#
#    This widget displays the significant events log in a lightweight
#    mybrowser.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Widget Definition

snit::widgetadaptor sigeventbrowser {
    #-------------------------------------------------------------------
    # Options

    # Options delegated to the hull
    delegate option * to hull

    #-------------------------------------------------------------------
    # Components

    # None

    #--------------------------------------------------------------------
    # Constructor

    constructor {args} {
        # FIRST, Install the hull
        installhull using mybrowser            \
            -toolbar      no                   \
            -sidebar      no                   \
            -home         my://app/sigevents   \
            -hyperlinkcmd {::app show}         \
            -messagecmd   {::app puts}         \
            -reloadon {
                ::adb <Sync>
                ::adb <Tick>
            }

        # NEXT, get the options.
        $self configurelist $args
    }

    #-------------------------------------------------------------------
    # Public Methods

    delegate method * to hull

}




