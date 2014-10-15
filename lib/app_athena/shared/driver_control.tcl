#------------------------------------------------------------------------
# TITLE:
#    driver_control.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#   Athena Driver Assessment Model (DAM): CONTROL rules
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# control_rules

driver type define CONTROL {n} {
    #-------------------------------------------------------------------
    # Look-up tables

    # C11sat -- satisfaction magnitude dict for CONTROL-1-1.  Key
    # is abs(Vdelta), value is unsigned qmag(n).  

    typevariable C11sat {
        1.4 XXXL
        1.0 XXL
        0.6 L
        0.2 M
    }

    # C11acoop -- effect on civgroup f's cooperation
    # with force groups owned by actor a for CONTROL-1-1.  Key is
    # vrel.fa, value is qmag(n).

    typevariable C11acoop -array {
        SUPPORT S+
        LIKE    0
        INDIFF  S-
        DISLIKE M-
        OPPOSE  L-
    }

    # C11bcoop -- effect on civgroup f's cooperation
    # with force groups owned by actor b for CONTROL-1-1.  Key is
    # vrel.fb, value is qmag(n).

    typevariable C11bcoop -array {
        SUPPORT L+
        LIKE    M+
        INDIFF  S+
        DISLIKE 0
        OPPOSE  0
    }

    # C11sat -- effect on civgroup f's satisfaction for CONTROL-1-2
    # Key is vrel.fa, value is qmag(n).

    typevariable C12sat -array {
        SUPPORT XXL-
        LIKE    XL-
        INDIFF  S-
        DISLIKE L+
        OPPOSE  XL+
    }

    # C12acoop -- effect on civgroup f's cooperation with actor a's
    # force groups for CONTROL-1-2
    # Key is vrel.fa, value is qmag(n).

    typevariable C12acoop -array {
        SUPPORT XL+
        LIKE    L+
        INDIFF  S-
        DISLIKE L-
        OPPOSE  XL-
    }

    # C12ccoop -- effect on civgroup f's cooperation with every
    # other actor c's force groups for CONTROL-1-2
    # Key is vrel.fa, value is qmag(n).

    typevariable C12ccoop -array {
        SUPPORT L+
        LIKE    M+
        INDIFF  S+
        DISLIKE 0
        OPPOSE  0
    }

    # C13sat -- effect on civgroup f's satisfaction for CONTROL-1-3
    # Key is vrel.fa, value is qmag(n).

    typevariable C13sat -array {
        SUPPORT XXL+
        LIKE    XL+
        INDIFF  S+
        DISLIKE L-
        OPPOSE  XL-
    }

    # C13bcoop -- effect on civgroup f's cooperation with actor b's
    # force groups for CONTROL-1-3
    # Key is vrel.fa, value is qmag(n).

    typevariable C13bcoop -array {
        SUPPORT L+
        LIKE    M+
        INDIFF  S+
        DISLIKE 0
        OPPOSE  0
    }

    # C21 -- Effect on civgroup g's vertical relationship with actor a,
    # given vrel.ga,<case> where case is G (gained control), L (lost 
    # control), or N (neither).
    
    typevariable C21 -array {
        SUPPORT,G  L+
        LIKE,G     M+
        INDIFF,G   0
        DISLIKE,G  M-
        OPPOSE,G   L-

        SUPPORT,N  M-
        LIKE,N     S-
        INDIFF,N   0
        DISLIKE,N  0
        OPPOSE,N   0

        SUPPORT,L  L-
        LIKE,L     M-
        INDIFF,L   0
        DISLIKE,L  XS-
        OPPOSE,L   S-
    }
    
    #-------------------------------------------------------------------
    # Public Typemethods

    # assess fdict
    #
    # fdict  - Dictionary of aggregate event attributes:
    #
    #       n          - The neighborhood in which control shifted.
    #       a          - The actor that lost control, or "" if none.
    #       b          - The actor that gained control, or "" if none.
    #
    # This call adds "dtype" to the dictionary before passing it to the
    # rule sets.
    #
    # Assesses the satisfaction and cooperation implications of the event.

    typemethod assess {fdict} {
        set dtype CONTROL
        dict set fdict dtype $dtype

        if {![dam isactive $dtype]} {
            log warning $dtype \
                "driver type has been deactivated"
            return
        }

        dict with fdict {}
        
        # Skip if the neighborhood is empty.
        if {[demog getn $n population] == 0} {
            log normal $dtype \
                "skipping, nbhood $n is empty." 
            return
        }
        
        bgcatch {
            log detail $dtype $fdict
            $type ruleset1 $fdict
            $type ruleset2 $fdict
        }
    }

    #-------------------------------------------------------------------
    # Narrative Type Methods

    # sigline signature
    #
    # signature - The driver signature
    #
    # Returns a one-line description of the driver given its signature
    # values.

    typemethod sigline {signature} {
        set n $signature
        return "Shift in control of nbhood $n"
    }

    # narrative fdict
    #
    # fdict - Firing dictionary; see rulesets, below.
    #
    # Produces a one-line narrative text string for a given rule firing

    typemethod narrative {fdict} {
        dict with fdict {}

        if {$a eq ""} {
            set a "NONE"
        } else {
            set a "{actor:$a}"
        }

        if {$b eq ""} {
            set b "NONE"
        } else {
            set b "{actor:$b}"
        }

        return "Control of {nbhood:$n} shifted from $a to $b"
    }
    
    # detail fdict 
    #
    # fdict - Firing dictionary; see rulesets, below.
    # ht    - An htools(n) buffer
    #
    # Produces a narrative HTML paragraph including all fdict information.

    typemethod detail {fdict ht} {
        dict with fdict {}

        if {$b ne ""} {
            $ht putln "Actor "
            $ht link my://app/actor/$b $b
            $ht putln "has taken control of neighborhood\n"
            $ht link my://app/nbhood/$n $n

            if {$a ne ""} {
                $ht putln "from "
                $ht link my://app/actor/$a $a
                $ht put "."
            }
        } else {
            $ht putln "Actor "
            $ht link my://app/actor/$a $a
            $ht putln "has lost control of neighborhood\n"
            $ht link my://app/nbhood/$n $n
            $ht put ","
            $ht putln "which is now in a state of chaos."
        }

        $ht para
    }


    #-------------------------------------------------------------------
    # Rule Set: CONTROL: Shift in neighborhood control.
    #
    # Event.  This rule set determines the effect of a shift in
    # control of a neighborhood.  CONTROL-1 handles the satisfaction
    # and cooperation effects, and CONTROL-2 handles the vertical
    # relationship effects.

    typemethod ruleset1 {fdict} {
        dict with fdict {}

        set flist [demog gIn $n]

        # CONTROL-1-1
        #
        # If Actor b has taken control of nbhood n from Actor a,
        # Then for each CIV pgroup f in the neighborhood
        dam rule CONTROL-1-1 $fdict {
            $a ne "" && $b ne ""
        } {
            foreach f $flist {
                # FIRST, get the vertical relationships
                set Vfa [vrel.ga $f $a]
                set Vfb [vrel.ga $f $b]

                # NEXT, get the satisfaction effects.
                let Vdelta {$Vfb - $Vfa}

                if {$Vdelta > 0.0} {
                    set sign "+"
                } elseif {$Vdelta < 0.0} {
                    set sign "-"
                } else {
                    set sign ""
                }

                set mag 0

                dict for {bound sym} $C11sat {
                    if {$bound < abs($Vdelta)} {
                        set mag $sym$sign
                        break
                    }
                }
                
                dam sat P $f AUT $mag [format "DV=%+4.1f" $Vdelta]

                # NEXT, get the cooperation effects with a's troops
                set Vfa [qaffinity name $Vfa]
                set Vfb [qaffinity name $Vfb]

                dam coop P $f [actor frcgroups $a] \
                    $C11acoop($Vfa) "a's group, V.fa=$Vfa"
                dam coop P $f [actor frcgroups $b] \
                    $C11bcoop($Vfb) "b's group, V.fb=$Vfb"
            }
        }

        # CONTROL-1-2
        #
        # If Actor a has lost control of nbhood n, which is now
        # in chaos,
        # Then for each CIV pgroup f in the neighborhood
        dam rule CONTROL-1-2 $fdict {
            $a ne "" && $b eq ""
        } {
            foreach f $flist {
                # FIRST, get the vertical relationships
                set Vsym [qaffinity name [vrel.ga $f $a]]

                dam sat P $f AUT $C12sat($Vsym) "V.fa=$Vsym"

                # NEXT, get the cooperation effects with each
                # actor's troops
                foreach actor [actor names] {
                    set glist [actor frcgroups $actor]

                    if {$actor eq $a} {
                        set mag $C12acoop($Vsym)
                        set note "a's group, V.fa=$Vsym"
                    } else {
                        set Vc [qaffinity name [vrel.ga $f $actor]]
                        set mag $C12ccoop($Vc)
                        set note "c's group, V.fc=$Vc"
                    }

                    dam coop P $f $glist $mag $note
                }
            }
        }

        # CONTROL-1-3
        #
        # If Actor b has gained control of nbhood n, which was previously
        # in chaos,
        # Then for each CIV pgroup f in the neighborhood
        dam rule CONTROL-1-3 $fdict {
            $a eq "" && $b ne ""
        } {
            foreach f $flist {
                # FIRST, get the vertical relationships
                set Vsym [qaffinity name [vrel.ga $f $b]]

                dam sat P $f AUT $C13sat($Vsym) "V.fb=$Vsym"

                # NEXT, get the cooperation effects with actor b's
                # troops.
                set glist [actor frcgroups $b]
                set mag $C13bcoop($Vsym)
                dam coop P $f $glist $mag "b's group, V.fb=$Vsym"
            }
        }
    }

    typemethod ruleset2 {fdict} {
        set ag [dict get $fdict b]
        set al [dict get $fdict a]

        set glist [demog gIn [dict get $fdict n]]
        set alist [actor names]

        dam rule CONTROL-2-1 $fdict {1} {
            foreach g $glist {
                foreach a $alist {
                    # FIRST, get the vertical relationship
                    set Vga [qaffinity name [vrel.ga $g $a]]

                    # NEXT, did actor a lose, gain, or neither?
                    if {$a eq $al} {
                        set case L
                        set note "V.ga=$Vga, lost control"
                    } elseif {$a eq $ag} {
                        set case G
                        set note "V.ga=$Vga, gained control"
                    } else {
                        set case N
                        set note "V.ga=$Vga, neither"
                    }

                    # NEXT, enter the vrel input
                    dam vrel P $g $a $C21($Vga,$case) $note
                }
            }
        }
    }
}




