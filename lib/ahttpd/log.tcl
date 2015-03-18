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
#    This is a file-based logging module for TclHttpd.
#
#    This starts a new log file each day with Log_SetFile
#    It also maintains an error log file that is always appended to
#    so it grows over time even when you restart the server.
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

    #-------------------------------------------------------------------
    # Type Variables
    
    # Info Array
    #
    # lognames  - If 1, log host names; otherwise, log IP addresses. 
    # cookies   - If 1, log cookie values.
    # basename  - Base name of current log
    # logfile   - Current log file name.

    typevariable info -array {
        lognames 0
        cookies  0
        basename ""
        logfile  ""
    }

    typevariable fd -array {
        log   ""
        error ""
    }

    # setfile basename
    #
    # basename   - Base log file name, including directory, or ""
    #
    # Opens log files, closing any previous log files.  
    # If basename is the empty string, just closes the log.
    
    typemethod setfile {basename} {
        # FIRST, save the new base name.
        if {$basename ne ""} {
            set info(basename) $basename
        }

        if {$info(basename) eq ""} {
            return
        }

        # TBD: Ugly!
        catch {Counter_CheckPoint}      ;# Save counter data

        # set the log file and error file.
        set info(logfile) $info(basename)
        catch {close $fd(log)}
        catch {close $fd(error)}

        # Create log directory, if neccesary, then open the log files
        catch {file mkdir [file dirname $info(logfile)]}

        if {[catch {set fd(log) [open $info(logfile) a]} err]} {
            Stderr $err
        }

        if {[catch {set fd(error) [open $info(basename)error a]} err]} {
            Stderr $err
        }
    }

    # basename
    #
    # Returns the base name, or ""

    typemethod basename {} {
        return $info(basename)
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
        # TBD: Need a better mechanism
        upvar #0 Httpd$sock data

        switch -- $reason {
            "Close" {
                set now [clock seconds]
                set result [LogStandardData $sock $now]
                if {[catch {puts $fd(log) $result} err]} {
                    # TBD: urk?
                    set urk !
                }

                catch {flush $fd(log)}
            }
            default {
                set now [clock seconds]
                append result { } \[[clock format $now -format %d/%h/%Y:%T]\]
                append result { } $sock { } $reason { } $args
                if {[info exists data(url)]} {
                    append result { } $data(url)
                }
                catch { 
                    puts $fd(error) $result
                    flush $fd(error) 
                }
            }
        }
    }

    # flush
    #
    # Flush the output to the log file.  Do this periodically, rather than
    # for every transaction, for better performance

    typemethod flush {} {
        catch {flush $fd(log)}
        catch {flush $fd(error)}
    }

    #-------------------------------------------------------------------
    # Standard HTTP Logging

    # LogStandardData sock now
    #
    # sock  - The client connection.
    # now   - The timestamp for the connection, in seconds
    #
    # Generate a standard web log file record for the current connection.
    # This records the client address, the URL, the time, the error
    # code, and so forth.  Returns the record string.

    proc LogStandardData {sock now} {
        return [LogStandardPrint [LogStandardList $sock $now]]
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
                time {
                    append result \
                        $sep\[[clock format $v -format "%d/%h/%Y:%T %Z"]\]
                }
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

    # LogStandardList sock now
    #
    # sock  - The client connection.
    # now   - The timestamp for the connection, in seconds
    #
    # Like LogStandardData, but return the data in a name, value list
    # suitable for use in foreach loops, array get, or long term
    # storage.

    proc LogStandardList {sock now} {
        # TBD: Need better mechanism.
        upvar #0 Httpd$sock data

        if {$info(lognames)} {
            if {[catch {lappend result ipaddr [Httpd_Peername $sock]}]} {
                lappend result ipaddr [LogValue data(ipaddr)]
            }
        } else {
            lappend result  ipaddr [LogValue data(ipaddr)]
        }

        lappend result authuser  [LogValue data(mime,auth-user)]
        lappend result username  [LogValue data(mime,username)]
        lappend result time      $now
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

