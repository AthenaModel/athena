#-----------------------------------------------------------------------
# FILE: app.tcl
#
# Main Application Module
#
# PACKAGE:
#   app_athena_log(n) -- athena_log(1) implementation package
#
# PROJECT:
#   Athena Regional Stability Simulation
#
# AUTHOR:
#   Will Duquette
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# app
#
# This module defines app, the application ensemble.  app contains
# the application start-up code, as well a variety of subcommands
# available to the application as a whole.  To invoke the 
# application,
#
# > package require app_log
# > app init $argv

snit::type app {
    pragma -hasinstances 0
    
    #-------------------------------------------------------------------
    # Type Components
    
    typecomponent log      ;# The scrollinglog(n) widget
    typecomponent msgline  ;# The messageline(n) widget
    
    #-------------------------------------------------------------------
    # Type Variables
    
    # scrollLockFlag
    #
    # Do we auto-update and scroll, or not?
    typevariable scrollLockFlag 0
    
    #-------------------------------------------------------------------
    # Application Initializer

    # init
    #
    # Initializes the application, and processes the command line.
    #
    # Syntax:
    #   init _argv_
    #
    #   argv - Command line arguments (if any)
    #
    # The application expects a single argument, the root of the log
    # directory tree; if absent, it defaults to "./log".

    typemethod init {argv} {
        appdir init

        # FIRST, get the log directory.
        set logdir [appdir join log]
        
        # NEXT, set the default window title
        wm title . "Athena Log: [file normalize $logdir]"

        # NEXT, Exit the app when this window is closed, if it's a 
        # main window.
        wm protocol . WM_DELETE_WINDOW [list app exit]
        
        # NEXT, create the menus
        
        # Menu Bar
        set menubar [menu .menubar -relief flat]
        . configure -menu $menubar
        
        # File Menu
        set mnu [menu $menubar.file]
        $menubar add cascade -label "File" -underline 0 -menu $mnu

        $mnu add command                       \
            -label       "Exit"                \
            -underline   1                     \
            -accelerator "Ctrl+Q"              \
            -command     [list app exit]
        bind . <Control-q> [list app exit]
        bind . <Control-Q> [list app exit]

        # Edit menu
        set mnu [menu $menubar.edit]
        $menubar add cascade -label "Edit" -underline 0 -menu $mnu

        $mnu add command \
            -label "Cut" \
            -underline 2 \
            -accelerator "Ctrl+X" \
            -command {event generate [focus] <<Cut>>}

        $mnu add command \
            -label "Copy" \
            -underline 0 \
            -accelerator "Ctrl+C" \
            -command {event generate [focus] <<Copy>>}
        
        $mnu add command \
            -label "Paste" \
            -underline 0 \
            -accelerator "Ctrl+V" \
            -command {event generate [focus] <<Paste>>}
        
        $mnu add separator
        
        $mnu add command \
            -label "Select All" \
            -underline 7 \
            -accelerator "Ctrl+Shift+A" \
            -command {event generate [focus] <<SelectAll>>}
        
        # View Menu
        set mnu [menu $menubar.view]
        $menubar add cascade -label "View" -underline 2 -menu $mnu
        
        $mnu add checkbutton \
            -label    "Set Scroll Lock"                 \
            -variable [mytypevar scrollLockFlag]        \
            -command  [mytypemethod SetScrollLock]
        

        # NEXT, create the components
        
        # ROW 0 -- separator
        ttk::separator .sep0 -orient horizontal
        
        # ROW 1 -- Scrolling log
        set log .log
        scrollinglog .log                           \
            -relief        flat                     \
            -height        24                       \
            -logcmd        [mytypemethod puts]      \
            -loglevel      normal                   \
            -showloglist   yes                      \
            -showapplist   yes                      \
            -rootdir       [file normalize $logdir] \
            -parsecmd      [myproc LogParser]       \
            -format        {
                {t 19 yes}
                {w  7 yes}
                {v  7 yes}
                {c  9 yes}
                {m  0 yes}
             }
             
        # ROW 2 -- separator
        ttk::separator .sep2 -orient horizontal
        
        # ROW 3 -- message line
        set msgline [messageline .msgline]

        # NEXT, grid the components in
        grid .sep0    -row 0 -column 0 -sticky ew
        grid .log     -row 1 -column 0 -sticky nsew -pady 2
        grid .sep2    -row 2 -column 0 -sticky ew
        grid .msgline -row 3 -column 0 -sticky ew
        
        grid rowconfigure    . 1 -weight 1 ;# Content
        grid columnconfigure . 0 -weight 1
        
        # NEXT, addition behavior
        bind all <Control-F12> [list debugger new]
    }
    
    #-------------------------------------------------------------------
    # Event Handlers
    
    # SetScrollLock
    #
    # Locks/Unlocks the scrolling log's scroll lock.
    
    typemethod SetScrollLock {} {
        $log lock $scrollLockFlag
    }
    
    # LogParser
    #
    # Parses the log lines for the <log> and returns a list of lists.
    #
    # Syntax:
    #   LogParser _text_
    #
    #   text - A block of log lines
    
    proc LogParser {text} {
        set lines [split [string trimright $text] "\n"]
    
        set lineList {}

        foreach line $lines {
            set fields [list \
                            [lindex $line 0] \
                            [lindex $line 4] \
                            [lindex $line 1] \
                            [lindex $line 2] \
                            [lindex $line 3]]
            
            lappend lineList $fields
        }
        
        return $lineList
    }
    
    
    #-------------------------------------------------------------------
    # Utility Type Methods
    
    # exit ?code?
    #
    # Exits the program, with the specified exit code.
    
    typemethod exit {{code 0}} {
        # TBD: Put any special exit handling here.
        exit $code
    }
    
    # puts msg
    #
    # Display the _msg_ in the message line
    
    typemethod puts {msg} {
        $msgline puts $msg        
    }

    # usage
    #
    # Displays the application's command-line syntax
    
    typemethod usage {} {
        puts "Usage: athena_log"
    }

}



