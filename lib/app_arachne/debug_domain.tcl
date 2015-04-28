#-----------------------------------------------------------------------
# TITLE:
#   debug_domain.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   debug_domain: The smartdomain(n) for scenario data.
#
#-----------------------------------------------------------------------

oo::class create debug_domain {
    superclass ::projectlib::smartdomain

    #-------------------------------------------------------------------
    # Constructor

    constructor {} {
        next /debug

        # FIRST, define helpers
        ::projectlib::htmlbuffer create hb   \
            -domain    /debug                \
            -cssfile   "/athena.css"         \
            -headercmd [mymethod htmlHeader] \
            -footercmd [mymethod htmlFooter]

        # NEXT, define content.  All urls are prefixed with /debug.
        my url /index.html [mymethod index.html] {Debugging Tools}
        my url /mods.html  [mymethod mods.html]  {Software Mods}
    }            

    #-------------------------------------------------------------------
    # Header and Footer

    method htmlHeader {hb title} {
        $hb h1 "&nbsp;Arachne: Athena Regional Stability Simulation" \
            -style "background: red;"
    }

    method htmlFooter {hb} {
        $hb hr
        $hb putln "Athena Arachne [app version] - [clock format [clock seconds]]"
        $hb para
    }

    

    #-------------------------------------------------------------------
    # General Content

    # index.html
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Displays a list of the debugging tools.

    method index.html {sd qdict} {
        hb page "Debugging"
        hb h1 "Debugging"

        hb putln "The following tools are available:"
        hb para

        hb ul {
            hb li-with {
                hb iref /mods.html "Software Mods"
            }
        }

        return [hb /page]
    }

    # mods.html
    #
    # sd       - The smartdomain object (e.g., [self])
    # qdict    - Query Dictionary
    #
    # Displays a list of the loaded mods.

    method mods.html {sd qdict} {
        hb page "Software Mods"
        hb h1 "Software Mods"

        switch -- [$qdict prepare op -tolower] {
            reload {
                try {
                    mod load
                    mod apply
                } trap MODERROR {result} {
                    hb span -class error \
                        "Could not reload mods: $result"
                    hb para
                }
            }
        }


        set table [mod list]

        if {[llength $table] == 0} {
            hb putln "No mods have been loaded or applied."
            hb para
            return [hb /page]
        }

        set t [clock format [mod modtime]]

        hb putln "The following mods were loaded at $t "
        hb iref /mods.html?op=reload "(Reload)"
        hb put ":"
        hb para
        hb table -headers {
            "Package" "Version" "Mod#" "Title" "Mod File"
        } {
            foreach row $table {
                hb tr {
                    hb td [dict get $row package] 
                    hb td [dict get $row version] 
                    hb td [dict get $row num    ] 
                    hb td [dict get $row title  ] 
                    hb td [dict get $row modfile] 
                }
            }
        }
        hb para

        # Code Search
        hb hr
        hb para
        hb form
        hb label cmdline "Command:"
        hb entry cmdline -size 60
        hb submit "Search"
        hb /form
        hb para

        set cmdline [$qdict prepare cmdline]

        if {$cmdline ne ""} {
            hb putln "<b>Command:</b> <tt>$cmdline</tt>"
            hb para

            set code [join [cmdinfo getcode $cmdline -related] \n]

            if {$code eq ""} {
                hb putln "No matching code found."
                hb para
            } else {
                hb pre -class example $code
            }
        }

        # For mod testing.
        my dummy

        return [hb /page]
    }

    #-------------------------------------------------------------------
    # Helper Methods

    method dummy {} {
    }
    
}

