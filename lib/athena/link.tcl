#-----------------------------------------------------------------------
# TITLE:
#    link.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Link Create/Translator
#
#    Athena objects use a simple linking scheme in their narrative
#    strings for embedded references to entities (e.g., actors).  This
#    module contains the code required to translate the links to
#    HTML or plain text.
#
#    Links have the form {<entityType>:<entityID>}.  The default
#    HTML translation is simply a link to this URL:
#
#        my://app/<entityType>/<entityID>
#
#-----------------------------------------------------------------------

namespace eval ::athena:: {
    namespace export \
        link
}

snit::type ::athena::link {
    # Make it a singleton
    pragma -hasinstances no

    #-------------------------------------------------------------------
    # Link Builders

    # make etype eid
    #
    # etype   - The entity type
    # eid     - The entity ID
    #
    # Returns the link text, or "???" if the entity ID is empty.
    #
    # TBD: At some point, we'll want to verify that the EID is valid,
    # given the etype, and return the bare ID if it isn't.

    typemethod make {etype eid} {
        if {$eid eq ""} {
            return "???"
        } else {
            return "{$etype:$eid}"
        }
    }
    

    #-------------------------------------------------------------------
    # Link Translators

    # html narrative
    #
    # narrative - A narrative string
    #
    # Translates links in the narrative to HTML.

    typemethod html {narrative} {
        regsub -all -- {{(\w+):(\w+)}} $narrative \
            {<a href="my://app/\1/\2">\2</a>} \
            narrative

        return $narrative
    }

    # text narrative
    #
    # narrative - A narrative string
    #
    # Translates links in the narrative to just the entity name
    # as plain text.

    typemethod text {narrative} {
        regsub -all -- {{(\w+):(\w+)}} $narrative {\2} narrative

        return $narrative
    }
}