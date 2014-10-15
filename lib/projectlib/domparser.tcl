#-----------------------------------------------------------------------
# TITLE:
#    domparser.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#
#    Provides DOM parsing capabilities.  This object is essentially 
#    a wrapper for commands in the tDOM package and includes some of
#    the more common DOM traversing functions.
#
#-----------------------------------------------------------------------

namespace eval ::projectlib:: {
    namespace export domparser
}

snit::type ::projectlib::domparser {
    pragma -hastypedestroy 0 -hasinstances 0 

    #-------------------------------------------------------------------
    # Type components

    typecomponent dtree  ;# The DOM tree

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        namespace import ::marsutil::*
    }

    # doc xml
    #
    # Given a chunk of XML, parse it with the DOM parser
    # and return the DOM tree

    typemethod doc {xml} {
        set dtree [dom parse $xml]
    }

    # root
    #
    # Returns the root element of the DOM tree, provided the DOM
    # exists.

    typemethod root {} {
        if {$dtree eq ""} {
            error "No DOM tree created."
        }

        return [$dtree documentElement]
    }

    # nodebyname tag
    #
    # returns the first node in the DOM tree that has the supplied tag
    # name

    typemethod nodebyname {tag} {
        if {$dtree eq ""} {
            error "No DOM tree created."
        }

        return [lindex [$dtree getElementsByTagName $tag] 0]
    }

    # delete 
    # 
    # Deletes the DOM tree and sets it to the null string

    typemethod delete {} {
        if {$dtree eq ""} {
            error "No DOM tree created."
        }

        $dtree delete
        set dtree ""
    }

    # cnodebyname node tag
    #
    # node   - a DOM node
    # tag    - a tag to search for in the subtree below node
    #
    # This method expects to find one and only one child with the 
    # supplied tag as a name somewhere below node in the DOM if 
    # found, the node is returned otherwise the empty string is
    # returned.  Error if there is more than one child with the
    # supplied tag.

    typemethod cnodebyname {node tag} {
        set children [$node getElementsByTagName $tag]

        if {[llength $children] == 0} {
            return ""
        } elseif {[llength $children] > 1} {
            error "Too many $tag elements in [$node nodeName]"
        } 

        set child [lindex $children 0]
        return $child
    }

    # elemtext node tag
    #
    # node   - a DOM node
    # tag    - a tag to search for in the subtree below node
    #
    # This method expects to find one and only one child with the
    # supplied tag as a name somewhere below node in the DOM. If
    # found, the text enclosed by the start and end tag is returned
    # otherwise the empty string is returned.  Error if there is 
    # more than one child with the supplied tag.

    typemethod ctextbyname {node tag} {
        set children [$node getElementsByTagName $tag]

        if {[llength $children] == 0} {
            return ""
        } elseif {[llength $children] > 1} {
            error "Too many $tag elements in [$node nodeName]"
        } else {
            set child [lindex $children 0]
            
            return [$child text]
        }
    }

    # elemlist node tag ?caps?
    #
    # node  - a DOM node
    # tag   - a tag to search for in the subtree below node
    # caps  - if 1, return all caps otherwise return text as found
    #         default is 0
    #
    # This method searches the subtree below node for all children
    # with the supplied tag. If found, a list of the text enclosed
    # by the start and end tag is returned otherwise an empty string
    # is returned.

    typemethod cnodesbyname {node tag {caps 0}} {
        set children [$node getElementsByTagName $tag]

        if {[llength $children] == 0} {
            return ""
        } else {
            set clist [list]
            
            foreach child $children {
                if {$caps} {
                    lappend clist [string toupper [$child text]]
                } else {
                    lappend clist [$child text]
                }
            }

            return $clist
        }
    }

    # attr node name
    #
    # node   - a DOM node
    # name   - the name of an attribute in node
    #
    # This method returns the value of an attribute found within
    # the supplied node. If not found, an error is generated.

    typemethod attr {node name} {
        if {[$node hasAttribute $name]} {
            return [$node getAttribute $name]
        } else {
            error "[$node nodeName]: no attribute named $name"
        }
    }

}

