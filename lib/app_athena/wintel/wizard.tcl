#-----------------------------------------------------------------------
# FILE: wizard.tcl
#
#   Wizard Main Ensemble.
#
# PACKAGE:
#   wintel(n) -- package for athena(1) intel ingestion wizard.
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

 
#-----------------------------------------------------------------------
# wizard
#
# Intel Ingestion Wizard main module.

snit::type ::wintel::wizard {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Variables

    # Wizard Window Name
    typevariable win .wintelwizard   

    # checkpointed data array
    #
    # Data saved in the scenario.
    #
    # nextIngestion  - serial number of next ingestion.

    typevariable cpdata -array {
        nextIngestion 1
    }

    # cpdata changed flag
    typevariable cpChanged 0

    # info array: data structure for the ingested data.
    #
    # events => dictionary of simevents by event type
    #        -> $eventType => list of ::simevent::$eventType objects

    typevariable info -array {
        sorting      {}
        events       {}
    }

    #-------------------------------------------------------------------
    # Wizard Invocation

    # invoke
    #
    # Invokes the wizard.  This initializes the underlying modules, and
    # creates the wizard window.  We enter the WIZARD state when the
    # window is created, and remain in it until the wizard window
    # has completed or is destroyed.

    typemethod invoke {} {
        assert {[$type caninvoke]}

        # NEXT, initialize the non-GUI modules
        wizdb ::wintel::wdb
        tigr init

        # NEXT, create the real main window.
        wizwin $win
    }

    # cleanup
    #
    # Cleans up all transient wizard data.

    typemethod cleanup {} {
        # Destroy all remaining simevents.
        foreach id [simevent ids] {
            [simevent get $id] destroy
        }

        # Destroy wizard objects
        bgcatch { wdb destroy }

        # Reset the sim state, if necessary.
        sim wizard off
    }

    #-------------------------------------------------------------------
    # Queries

    # caninvoke
    #
    # Returns 1 if it's OK to invoke the wizard, and 0 otherwise.  We
    # can invoke the wizard if we are in the PREP state, and the wizard
    # window isn't already in existence.

    typemethod caninvoke {} {
        expr {[sim state] eq "PREP" && ![winfo exists $win]}
    }

    #-------------------------------------------------------------------
    # Predicates
    #
    # These subcommands indicate whether we've acquired needed information
    # or not.

    # gotMessages
    #
    # Returns 1 if we've got some messages, and 0 otherwise.

    typemethod gotMessages {} {
        return [wdb exists {SELECT cid FROM messages}]
    }

    # gotSorting
    #
    # Returns 1 if we've sorted the messages by event, and 0 otherwise.

    typemethod gotSorting {} {
        return [wdb exists {SELECT cid FROM cid2etype}]
    }

    #-------------------------------------------------------------------
    # Mutators

    # retrieveTestMessages
    #
    # Retrieves our canned test messages.

    typemethod retrieveTestMessages {} {
        tigr readTestData

        notifier send ::wintel::wizard <update>
    }

    # retrieveMessages filenames
    #
    # Ideally, this should have search arguments to pass along to
    # TIGR; or perhaps the wiztigr widget should talk directly to
    # tigr.

    typemethod retrieveMessages {filenames} {
        tigr readfiles $filenames

        notifier send ::wintel::wizard <update>
    }
    
    # saveSorting sorting
    #
    # sorting   - A sorting of message IDs into event bins, or ""
    #
    # Gives the current sorting to the ingestor.  If "", there is no
    # current sorting.

    typemethod saveSorting {sorting} {
        wdb eval {DELETE FROM cid2etype}
        
        dict for {bin idlist} $sorting {
            if {$bin in {unsorted ignored}} {
                continue
            }

            foreach id $idlist {
                wdb eval {
                    INSERT INTO cid2etype(cid,etype)
                    VALUES($id,$bin)
                }
            }
        }

        notifier send ::wintel::wizard <update>
    }

    # ingestEvents 
    #
    # Creates candidate events based on the message sorting.

    typemethod ingestEvents {} {
        simevent ingest $cpdata(nextIngestion)
    }

    # docs
    #
    # Returns HTML documentation for the ingested messages.

    typemethod docs {} {
        set ht [htools %AUTO%]

        $ht page "Ingestion Report"

        $ht title "Ingestion Report"

        set nEvents [llength [simevent normals]]
        set nTigr   [llength [tigr ids]]

        $ht putln "<b>At:</b> [clock format [clock seconds]]<br>"
        $ht putln "<b>Ingested:</b> $nEvents Athena events<br>"
        $ht putln "<b>From:</b> $nTigr TIGR messages<br>"

        $ht para

        foreach id [simevent normals] {
            set e [simevent get $id]

            $ht putln [$e htmltext]
        }

        $ht /page

        return [$ht get]
    }

    # saveFile filename text
    #
    # filename   - A user selected file name
    # text       - The text to save
    #
    # Attempts to save the text to disk.
    # Errors are handled by caller.

    typemethod saveFile {filename text} {
        set f [open $filename w]
        puts $f $text
        close $f
        return
    }

    # saveEvents
    #
    # Saves the ingested events into the scenario.

    typemethod saveEvents {} {
        set num [llength [simevent normals]]

        cif transaction "Ingest $num Intel Events" {
            foreach id [simevent normals] {
                set e [simevent get $id]

                $e sendevent
            }
        }

        app puts "Ingested $num intel events into the scenario." 
    }

    #-------------------------------------------------------------------
    # Finish: Ingest the events into the scenario

    # finish
    #
    # Ingests the selected sim events into the scenario.

    typemethod finish {} {
        # FIRST, the wizard is done; we're about to make things happen.
        sim wizard off

        # NEXT, ingest the events into the scenario
        $type saveEvents  

        # NEXT, update the ingestion number.
        incr cpdata(nextIngestion)
        set cpChanged 1      

        # NEXT, cleanup.
        destroy $win
    }
    
    #-------------------------------------------------------------------
    # Saveable(i) interface

    # checkpoint ?-saved?
    #
    # Returns a checkpoint of the non-RDB simulation data.  If 
    # -saved is specified, the data is marked unchanged.
    #

    typemethod checkpoint {{option ""}} {
        if {$option eq "-saved"} {
            set cpChanged 0
        }

        return [array get cpdata]
    }

    # restore checkpoint ?-saved?
    #
    # checkpoint - A string returned by the checkpoint typemethod
    #
    # Restores the non-RDB state of the module to that contained
    # in the checkpoint.  If -saved is specified, the data is marked
    # unchanged.
    
    typemethod restore {checkpoint {option ""}} {
        array unset cpdata
        array set cpdata $checkpoint

        if {$option eq "-saved"} {
            set cpChanged 0
        }
    }

    # changed
    #
    # Returns 1 if saveable(i) data has changed, and 0 otherwise.
    #
    # Syntax:
    #   changed

    typemethod changed {} {
        return $cpChanged
    }

    
}



