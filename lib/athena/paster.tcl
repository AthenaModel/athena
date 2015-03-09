#-----------------------------------------------------------------------
# TITLE:
#    paster.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena_sim(1): Paste Manager
#
#    This object knows how to convert "copy sets" into orders to paste
#    into a scenario for various kinds of copied data.  It is 
#    a component of athenadb(n), exposed as "$adb paste".
#
#-----------------------------------------------------------------------

snit::type ::athena::paster {
    #-------------------------------------------------------------------
    # Components

    component adb ;# The athenadb(n) instance

    #-------------------------------------------------------------------
    # Constructor

    # constructor adb_
    #
    # adb_    - The athenadb(n) that owns this instance.
    #
    # Initializes instances of the type.

    constructor {adb_} {
        set adb $adb_
    }

    #-------------------------------------------------------------------
    # Pasting of blocks

    # block agent copysets
    #
    # agent     - The agent whose strategy will receive the blocks
    # copysets  - A list of block copysets from [$bean copydata].
    #
    # Pastes the blocks into the given agent's strategy, pasting tactics 
    # and conditions recursively.  The orders are sent in a
    # flunky transaction.

    method block {agent copysets} {
        # FIRST, paste the copied blocks into the agent's strategy
        $adb order transaction "Paste Block(s)" {
            foreach copyset $copysets {
                # FIRST, get the block data
                set bdict [$self GetParmsFromCopySet $copyset block_id \
                            BLOCK:UPDATE]

                # NEXT, create the block with default settings
                set block_id [$adb order senddict gui STRATEGY:BLOCK:ADD \
                                    [list agent $agent]]

                # NEXT, update the block with the right data.
                dict set bdict block_id $block_id
                $adb order senddict gui BLOCK:UPDATE $bdict

                # NEXT, paste the conditions and tactics
                $adb paste condition $block_id [dict get $copyset conditions]
                $adb paste tactic    $block_id [dict get $copyset tactics]
            }
        }
    }

    #-------------------------------------------------------------------
    # Pasting of Conditions

    # condition block_id copysets
    #
    # block_id  - The ID of the block to receive the conditions
    # copysets  - A list of condition copysets from [$bean copydata].
    #
    # Pastes the conditions into the given block.   The orders are sent 
    # in a flunky transaction.

    method condition {block_id copysets} {
        # FIRST, paste the copied conditions into the block
        $adb order transaction "Paste Condition(s)" {
            foreach copyset $copysets {
                # FIRST, get the condition data
                set cls   [dict get $copyset class_]
                set cname [$cls typename]
                set cdict [$self GetParmsFromCopySet $copyset condition_id \
                                CONDITION:$cname]

                # NEXT, create the condition with default settings
                set condition_id \
                    [$adb order senddict gui BLOCK:CONDITION:ADD \
                        [list block_id $block_id typename $cname]]

                # NEXT, update the condition with the right data.
                $adb order senddict gui CONDITION:$cname \
                    [list condition_id $condition_id {*}$cdict]
            }
        }
    }

    #-------------------------------------------------------------------
    # Pasting of Tactics

    # tactic block copysets
    #
    # block_id  - The ID of the block to receive the tactics
    # copysets  - A list of tactic copysets from [$bean copydata].
    #
    # Pastes the tactics into the given block.  The orders are sent 
    # in a flunky transaction.

    method tactic {block_id copysets} {
        # FIRST, paste the copied tactics into the block
        $adb order transaction "Paste Tactic(s)" {
            foreach copyset $copysets {
                # FIRST, get the tactic data
                set cls   [dict get $copyset class_]
                set tname [$cls typename]
                set tdict [$self GetParmsFromCopySet $copyset tactic_id \
                                TACTIC:$tname]

                # NEXT, create the tactic with default settings
                set tactic_id \
                    [$adb order senddict gui BLOCK:TACTIC:ADD \
                        [list block_id $block_id typename $tname]]

                # NEXT, update the tactic with the right data.
                $adb order senddict gui TACTIC:$tname \
                    [list tactic_id $tactic_id {*}$tdict]
            }
        }
    }


    #-------------------------------------------------------------------
    # Helper Routines
    

    # GetParmsFromCopySet copyset idparm order
    #
    # copyset - The copyset from [$bean copydata]
    # idparm  - The bean type's ID parameter name
    # order   - The order to send to paste the items in this copyset.
    #
    # Pulls out the required parameters from the copyset.

    method GetParmsFromCopySet {copyset idparm order} {
        set pdict [dict create]

        foreach parm [::athena::orders parms $order] {
            if {$parm eq $idparm || $parm eq "name"} {
                continue
            }

            dict set pdict $parm [dict get $copyset $parm]
        }

        return $pdict
    }

}


