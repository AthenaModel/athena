#-----------------------------------------------------------------------
# TITLE:
#    appserver_bean.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: Beans
#
#    my://app/bean/{id}
#
#    Each bean class can provide an "html" method which produces 
#    content.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module BEAN {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /beans {beans/?}         \
            text/html [myproc /beans:html] {
                Links to all of the currently defined beans.
            }

        appserver register /bean/{id} {bean/(\w+)/?} \
            text/html [myproc /bean:html]            \
            "Detail page for bean {id}."
    }

    #-------------------------------------------------------------------
    # /beans: All defined beans

    # /beans:html udict matchArray
    #
    # Tabular display of bean data.
    #
    # The following query parameters may be used:
    #
    #   page_size    - The number of rows to display on one page.
    #   page         - The page number, 1 to N, to display


    proc /beans:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, get the query parameters
        set query [dict get $udict query]
        set qdict [urlquery get $query {page_size page}]

        dict with qdict {
            restrict page_size epagesize 20
            restrict page      ipositive 1
        }


        # NEXT, Begin the page
        ht page "Beans"
        ht title "Beans"

        ht putln "The scenario currently includes the following beans:"
        ht para

        # NEXT, insert the control form.
        ht hr
        ht form -autosubmit 1
        ht label page_size "Page Size:"
        ht input page_size enum $page_size -src enum/pagesize -content tcl/enumdict
        ht /form
        ht hr
        ht para

        # NEXT, get output stats
        set items [llength [adb bean ids]]
     
        if {$page_size eq "ALL"} {
            set page_size $items
        }

        let pages {entier(ceil(double($items)/$page_size))}

        if {$page > $pages} {
            set page 1
        }

        let offset {($page - 1)*$page_size}

        ht pager $qdict $page $pages

        # NEXT, get the ids.
        set ids [lrange [lrange [adb bean ids] $offset end] 0 $page_size-1]

        # NEXT, include the table
        ht table {
            "ID" "Class" "Object" "Parent"
        } {
            foreach id $ids {
                set bean [adb bean get $id]
                set cls  [info object class $bean]

                set bdict [$bean getdict]
                if {[dict exists $bdict parent]} {
                    set parent [adb bean get [dict get $bdict parent]]
                } else {
                    set parent ""
                }

                # TBD: Get parent, if any.

                ht tr {
                    ht td center { 
                        ht link my://app/bean/$id $id 
                    }
                    ht td left { 
                        ht put "<tt>[info object class $bean]</tt>"
                    }
                    ht td left { 
                        ht link my://app/bean/$id "<tt>$bean</tt>"
                    }
                    ht td left {
                        if {$parent ne ""} {
                            ht link my://app/bean/[$parent id] "<tt>$parent</tt>"
                        } else {
                            ht put "n/a"
                        }
                    }
                }
            }
        }

        ht /page

        return [ht get]
    }

    

    #-------------------------------------------------------------------
    # /bean/{id}: A single bean {id}
    #
    # Match Parameters:
    #
    # {id} => $(1)    - The bean's id

    # /bean:html udict matchArray
    #
    # Detail page for a single bean {id}

    proc /bean:html {udict matchArray} {
        upvar 1 $matchArray ""

        # FIRST, is there a bean with this id?
        set id [string toupper $(1)]

        if {![adb bean has $id]} {
            return -code error -errorcode NOTFOUND \
                "Unknown entity: [dict get $udict url]."
        }

        set bean [adb bean get $id]

        # NEXT, does it have an "htmlpage" method?
        if {"htmlpage" ni [info object methods $bean -all]} {
            ht page "Bean $id" {
                ht title "Bean $id"

                ht putln "No information available"
            }
        } else {
            $bean htmlpage ::appserver::ht
        }

        return [ht get]
    }
}