#-----------------------------------------------------------------------
# TITLE:
#    appserver_image.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Tk Images
#
#    /app/image/...
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module IMAGE {
    #-------------------------------------------------------------------
    # Type Variables

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /image/{name} {image/(.+)} \
            tk/image [myproc /image:image]            \
            "Any Tk image, by its {name}."
    }

    #-------------------------------------------------------------------
    # /image/{name}:   Any Tk image, given its fully-qualified command
    #                  name.
    #
    # Match Parameters:
    # 
    # {name} ==> $(1)   - Tk image name

    # /image:image udict matchArray
    #
    # Validates $(1) as a Tk image, and returns it as the tk/image
    # content.

    proc /image:image {udict matchArray} {
        upvar 1 $matchArray ""

        if {[catch {image type $(1)} result]} {
            return -code error -errorcode NOTFOUND \
                "Image not found: [dict get $udict url]"
        }

        return $(1)
    }
}



