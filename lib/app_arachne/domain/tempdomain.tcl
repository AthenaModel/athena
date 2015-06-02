#-----------------------------------------------------------------------
# TITLE:
#    tempdomain.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_arachne(n): Temporary file domain
#
#    This is an object that serves files from a temporary directory.
#    The client can create files in this directory (i.e., to hold
#    large query results) and then redirect to them.
#
#-----------------------------------------------------------------------

oo::class create tempdomain {

    #-------------------------------------------------------------------
    # Instance variables

    variable domain    ;# The domain prefix
    variable counter   ;# A counter for generating file names.
    variable tempdir   ;# The path of the temporary directory.
    

    #-------------------------------------------------------------------
    # Constructor

    # constructor domain_
    #
    # domain_   - The domain, e.g., /temp

    constructor {domain_} {
        set domain $domain_
        set counter 0
        set temproot [::fileutil::tempdir]

        while {1} {
            set rnd [expr {round(rand()*10**8)}]

            set tempdir [file join $temproot $rnd]

            if {![file exists $tempdir]} {
                file mkdir $tempdir
                break
            }
        }

        # TBD: Could add -callback to remove file after it's read.
        ahttpd::doc addroot $domain $tempdir 
    }

    #-------------------------------------------------------------------
    # Client utilities

    # domain
    #
    # Returns the domain name.

    method domain {} {
        return $domain
    }

    # tempdir
    #
    # Returns the name of the temp directory

    method tempdir {} {
        return $tempdir
    }

    # namegen ftype
    #
    # ftype   - The file type, e.g., ".json"
    #
    # Returns the name of a new file in the tempdir.

    method namegen {ftype} {
        set name [my GetName $ftype]

        while {[file exists $name]} {
            set name [my GetName $ftype]
        }

        return $name
    }

    # GetName ftype
    #
    # Returns a new name in the tempdir by incrementing the counter.

    method GetName {ftype} {
        set name "temp[incr counter]$ftype"
        return [file join $tempdir $name]        
    }
}

