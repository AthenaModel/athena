#-----------------------------------------------------------------------
# TITLE:
#    test_entitytree.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    projectgui: Test Script for entitytree(n).
#
#-----------------------------------------------------------------------

package require projectgui

namespace import marsutil::* marsgui::* projectgui::*

proc ChangeCmd {name} {
    puts "Selected: <$name>"
}

sqldocument rdb
rdb open test.adb

rdb eval {
    CREATE TABLE actors(a TEXT PRIMARY KEY);
    CREATE TABLE civgroups(g TEXT PRIMARY KEY);

    INSERT INTO actors    VALUES('JOE');
    INSERT INTO actors    VALUES('BOB');
    INSERT INTO actors    VALUES('MARCUS');
    INSERT INTO actors    VALUES('DAVE');
    INSERT INTO actors    VALUES('BRIAN');
    INSERT INTO actors    VALUES('WILL');

    INSERT INTO civgroups VALUES('SUNN');
    INSERT INTO civgroups VALUES('SHIA');
    INSERT INTO civgroups VALUES('KURD');
    INSERT INTO civgroups VALUES('PASH');
    INSERT INTO civgroups VALUES('HIND');
}

entitytree .etree \
    -rdb    ::rdb \
    -height 300   \
    -changecmd ChangeCmd

pack .etree -fill both -expand yes

.etree add actors    a "Actors"    ::projectgui::icon::actor12
.etree add civgroups g "CivGroups" ::projectgui::icon::civgroup12

.etree refresh

bind all <F12> {debugger new}







