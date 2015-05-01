#-----------------------------------------------------------------------
# TITLE:
#    appserver_home.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Application Home Page
#
#    /app/
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module HOME {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register / {/?} \
            text/html [myproc /:html] \
            "Athena Welcome Page"

    }

    #-------------------------------------------------------------------
    # /:    Athena welcome page
    #
    # No match parameters

    # /:html udict matchArray
    #
    # Formats and displays the welcome page from welcome.ehtml.

    proc /:html {udict matchArray} {
        if {[catch {
            set text [readfile [file join $::app_athenawb::library welcome.ehtml]]
        } result]} {
            return -code error -errorcode NOTFOUND \
                "The Welcome page could not be loaded from disk: $result"
        }

        return [tsubst $text]
    }
}
