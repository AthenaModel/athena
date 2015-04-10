app_arachne(n) Automated Test Suite
----------------------------------------------------------------------

This directory contains the automated test suite for app_arachne(n).  The
entire test suite is executed by the command line

    $ kite test app_arachne

Individual test scripts can be executed as well.  See 'kite help test'
for details.  

All of these tests run in the context of the loaded arachne(1) 
application; it is loaded by the [ted init] command, in ted.tcl, which 
is loaded (if need be) by each test file.  Note that when running all 
tests, the application code is loaded once, and all .test files execute 
in the same instance of Arachne.

The following things should be covered by the test suite:

* Test utilities
* Application Modules

Note that the test suite explicitly does *NOT* cover the web server
itself.

The test suite files fall in numbered categories, to control
the order of execution.

001:     Test infrastructure
010:     Application modules
020:     URL Handlers
