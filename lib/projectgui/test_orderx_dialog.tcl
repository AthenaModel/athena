#-----------------------------------------------------------------------
# FILE: test_orderdialog.tcl
#
#   orderdialog(n) test script
#
# PACKAGE:
#   marsgui(n) -- Mars GUI Infrastructure Library
#
# PROJECT:
#   Mars Simulation Infrastructure Library
#
# AUTHOR:
#    Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# Required packages

package require marsutil
package require marsgui

namespace import marsutil::*
namespace import marsgui::*

#-----------------------------------------------------------------------
# Look-up Tables

# rdbSchema -- Schema for the test RDB

set rdbSchema {
    CREATE TABLE people(
        name TEXT PRIMARY KEY,
        age  INTEGER                
    );

    INSERT INTO people(name,age) VALUES('ART', 23); 
    INSERT INTO people(name,age) VALUES('BILL',45); 
    INSERT INTO people(name,age) VALUES('CARL',67); 

    CREATE TABLE idx(n);
    INSERT INTO idx VALUES('1');
    INSERT INTO idx VALUES('2');
    INSERT INTO idx VALUES('3');
    INSERT INTO idx VALUES('4');    
    INSERT INTO idx VALUES('5');    
    INSERT INTO idx VALUES('6');    

    CREATE TABLE grid(
        i     TEXT,
        j     TEXT,
        value TEXT,
        PRIMARY KEY (i,j)
    );

    CREATE VIEW grid_universe AS
    SELECT I.n AS i, J.n AS j
    FROM idx AS I JOIN idx AS J;

    INSERT INTO grid VALUES('1','4','ART');
    INSERT INTO grid VALUES('2','5','BILL');
    INSERT INTO grid VALUES('3','6','CARL');
}


# orderStates -- List of order states

set orderStates {A B C}

# Choices enumeration

enum echoices {
    good  "The Good"
    bad   "The Bad"
    ugly  "The Ugly"
}

#-------------------------------------------------------------------
# Other Variables

# info array
#
# obRow   - Order button row
# obCol   - Order button column

array set info {
    obRow 1
    obCol 0
}



#-----------------------------------------------------------------------
# Orders

order define TEST:GENERAL {
    title "Test General Stuff"

    options \
        -sendstates     "A B" \
        -schedulestates "A B" \
        -refreshcmd {Echo -refreshcmd}

    parm x text "Parm X" -defval 123 -tags integer
    parm y text "Parm Y" -tags flag
    parm z text "Parm Z" -tags double -schedwheninvalid yes
} {
    prepare x -required -type snit::integer
    prepare y -required -type snit::boolean
    prepare z -required -type snit::double

    returnOnError -final

    Echo TEST:GENERAL x $parms(x) y $parms(y) z $parms(z)
}

order define TEST:FIELDS {
    title "Test Field Types"
    options -refreshcmd RefreshTestFields

    parm fkey1        key    "Key 1"       -table    grid -keys {i j}
    parm fkey2        key    "Key 2"       -table    grid -keys {i j} \
                                           -labels   {I J}            \
                                           -widths   {1 1}
    parm fnewkey      newkey "New Key"     -table    grid -keys {i j} \
                                           -universe grid_universe    \
                                           -labels   {I J}            \
                                           -widths   {1 1}
    parm fcolor       color  "Color"
    parm fdisp        disp   "Display"
    parm fenum        enum   "Enum"        -enumtype ::echoices
    parm fenumlong    enum   "EnumLong"    -enumtype ::echoices \
                                           -displaylong yes
    parm fenumrefresh enum   "EnumRefresh" 
    parm fmulti       multi  "Multi"       -table people -key name
} {
    returnOnError -final

    Echo TEST:FIELDS [array get parms]
}

proc RefreshTestFields {dlg changed fdict} {
    if {"fdisp" in $changed} {
        set values [echoices names]
        $dlg field configure fenumrefresh -values $values
        $dlg set fenumrefresh [lindex $values 0]
    }
}

order define TEST:CONTEXT {
    title "Test Context Parms"

    parm name key  "Name (Context)" -table people -keys name -context yes
    parm x    text "Parm Y"
    parm y    text "Parm Z"
} {
    returnOnError -final

    Echo TEST:CONTEXT name $parms(name) x $parms(x) y $parms(y)
}


#-----------------------------------------------------------------------
# Main

proc main {argv} {
    # FIRST, Create a test RDB.
    sqldocument rdb
    rdb open :memory:
    rdb register ::marsutil::eventq
    rdb clear

    rdb eval $::rdbSchema

    eventq init ::rdb

    # NEXT, initialize the order module
    order init \
        -subject      ::order    \
        -rdb          ::rdb      \
        -clock        ::simclock \
        -cancelstates {A B}

    order interface configure gui \
        -checkstate no

    order state A

    # NEXT, initialize the order dialog module
    orderdialog init \
        -appname "Mars Test" \
        -helpcmd {Echo help} \
        -parent  .           \
        -refreshon {
            ::app <Refresh>
        }
    
    # NEXT, create the app GUI
    . configure -padx 10 -pady 10

    ttk::frame .bar

    # statebox
    ttk::label .bar.statelabel \
        -text "Order State"

    menubox .bar.statebox \
        -values  $::orderStates \
        -width   3              \
        -command {order state [.bar.statebox get]}

    .bar.statebox set "A"

    # checkstate
    set ::checkstate 0
    ttk::checkbutton .bar.checkstate \
        -text     "CheckState?"  \
        -onvalue  yes            \
        -offvalue no             \
        -variable ::checkstate   \
        -command {order interface configure gui -checkstate $::checkstate}

    # NEXT, grid them in
    grid .bar.statelabel .bar.statebox .bar.checkstate
    grid .bar -sticky ew

    grid [ttk::separator .sep1] -sticky ew -pady 2

    # Order buttons
    obutton TEST:GENERAL
    obutton TEST:GENERAL x 1 y no z 0.5
    obutton TEST:FIELDS fdisp "Data to Display" fmulti {ART BILL}
    obutton TEST:CONTEXT
    obutton TEST:CONTEXT name "BILL"


    grid [ttk::separator .sep2] -sticky ew -pady 2

    # Puck buttons
    puckbutton integer 5
    puckbutton flag yes
    puckbutton double 0.5


    # NEXT, prepare to echo notifications
    notifier trace {Echo notifier:}

    # NEXT, allow the debugger to invoked
    bind all <F12> {debugger new}
}

# obutton name ?parm value...?
#
# name   - An order name
# parm   - A parameter name
# value  - A parameter value
#
# Creates and grids an order button for the named order; it will
# enter the dialog with the specified parameter values.

proc obutton {name args} {
    variable info

    set w .ob[incr info(obRow)]

    ttk::button $w \
        -text "$name $args" \
        -command [list order enter $name {*}$args]

    grid $w -sticky ew
}

# puckbutton ?tag value?
#
# tag/value     Field tags and values
#
# Creates a button that calls "order puck" with the specified tag dict.

proc puckbutton {args} {
    variable info

    set w .pb[incr info(obRow)]

    ttk::button $w \
        -text "puck $args" \
        -command [list order puck $args]

    grid $w -sticky ew
}

# Echo args...
#
# Writes a message to stdout with its arguments

proc Echo {args} {
    puts "$args"
}


#-------------------------------------------------------------------
# Invoke the program

main $argv









