app_athena(n) Automated Test Suite
----------------------------------------------------------------------

This directory contains the automated test suite for app_athena(n).  The
entire test suite is executed by the command line

    $ kite test app_athena

To run tests without Tk loaded, 

    $ kite test app_athena -notk

Individual test scripts can be executed as well.  See 'kite help test'
for details.  

All of these tests run in the context of the loaded athena(1) application;
it is loaded by the [ted init] command, in ted.tcl, which is loaded 
(if need be) by each test file.  Note that when running all tests, the
application is loaded once, and all .test files execute in the same
instance of Athena.

The following things should be covered by the test suite:

* Test utilities
* Simulation Orders
* Module mutators and queries
* Notifier Events

Note that the test suite explicitly does *NOT* cover the GUI.

The test suite files fall in numbered categories, to control
the order of execution.

001:     Test infrastructure
002-009: Application infrastructure (UNUSED)
010:     Scenario and Simulation modules
020:     Simulation orders
030:     Athena Executive commands and functions
040:     Driver Types (I.e., rule sets)
050:     appserver pages (UNUSED)
