#-----------------------------------------------------------------------
# TITLE:
#    log.tcl
#
# PROJECT:
#    athena - Athena Regional Stability Simulation
#
# DESCRIPTION:
#    ahttpd(n): server logging
#
#    This module is a simple adaptor from old-style TclHTTPD logging
#    to logger(n)-style logging.
#
#    Stephen Uhler / Brent Welch (c) 1997 Sun Microsystems
#    Brent Welch (c) 1998-2000 Ajuba Solutions
#    Will Duquette (c) 2015 California Institute of Technology
#
#    See the file "license.terms" for information on usage and redistribution
#    of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
#-----------------------------------------------------------------------

snit::type ::ahttpd::log {
    pragma -hasinstances no

    typevariable info -array {
        lognames 0
        cookies  0
    }

    # add sock reason args
    #
    # sock   - The client connection
    # reason - If "Close", then this is the normal completion of a request.
    #          Otherwise, this is some error tag, and the record goes to
    #          the error log.
    # args   - Additional information to put into the logs.
    #
    # Logs information about the activity of TclHttpd.  There are two 
    # kinds of log entries.  Normal entries goes into one log, one line
    # for each HTTP transaction.  All other log records are appended to an
    # error log file.

    typemethod add {sock reason args} {
        upvar #0 ::ahttpd::Httpd$sock data
        if {$reason eq "Close"} {
            ahttpd log normal $sock [LogStandardData $sock]
        } else {
            ahttpd log warning $sock "$reason $args"
        }
    }

    #-------------------------------------------------------------------
    # Standard HTTP Logging

    # LogStandardData sock
    #
    # sock  - The client connection.
    #
    # Generate a standard web log file record for the current connection.
    # This records the client address, the URL, the time, the error
    # code, and so forth.  Returns the record string.

    proc LogStandardData {sock} {
        return [LogStandardPrint [LogStandardList $sock]]
    }

    # LogStandardPrint data
    #
    # data - A data record
    #
    # Generate a standard web log file record for the current connection.
    # This records the client address, the URL, the time, the error
    # code, and so forth.
    #

    proc LogStandardPrint {data} {
        set sep ""
        set result ""
        foreach {n v} $data {
            if {$v == "" || $v == "-"} {
                append result ${sep}-
                continue
            }
            switch -- $n {
                http      -
                referer   -
                useragent -
                cookie    {
                    append result $sep"$v"
                }
                default {
                    append result $sep$v
                }
            }
            set sep " "
        }
        return $result
    }

    # LogStandardList sock
    #
    # sock  - The client connection.
    #
    # Like LogStandardData, but return the data in a name, value list
    # suitable for use in foreach loops, array get, or long term
    # storage.

    proc LogStandardList {sock} {
        upvar #0 ::ahttpd::Httpd$sock data

        if {$info(lognames)} {
            if {[catch {lappend result ipaddr [httpd peername $sock]}]} {
                lappend result ipaddr [LogValue data(ipaddr)]
            }
        } else {
            lappend result  ipaddr [LogValue data(ipaddr)]
        }

        lappend result authuser  [LogValue data(mime,auth-user)]
        lappend result username  [LogValue data(mime,username)]
        lappend result http      [LogValue data(line)]
        lappend result status    [LogValue data(code)]
        lappend result filesize  [LogValue data(file_size)]
        lappend result referer   [LogValue data(mime,referer)]
        lappend result useragent [LogValue data(mime,user-agent)]
        if {$info(cookies)} {
          # This field is not always present in logs
          lappend result cookie [LogValue data(mime,cookie)]
        }
        return $result
    }

    # LogValue --
    #
    #   Generate a field or the default "null field" representation.
    #
    # Arguments:
    #   var The variable whose value to use, if any
    #
    # Results:
    #   The value of the variable, or - as the default.
    #
    # Side Effects:
    #   None

    proc LogValue {var} {
        upvar $var data
        if {[info exists data]} {
            return $data
        } else {
           return -
        }
    }

}

