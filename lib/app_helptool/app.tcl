#-----------------------------------------------------------------------
# TITLE:
#    app.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    athena helptool(1) Application
#
#    Compiler for help(5) files.
#
#        package require app_helptool
#        app init $argv
#
#    This is a help compiler that can build .helpdb files that can be 
#    read by helpserver(n) and browsed in a mybrowser(n).
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# app ensemble

snit::type app {
    pragma -hastypedestroy 0 -hasinstances 0

    #-------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        snit::stringtype ::app::slug \
            -regexp {^[-A-Za-z0-9_:=]+$}
    }

    #-------------------------------------------------------------------
    # Type Components

    typecomponent compiler ;# Slave interpreter used to parse the input

    #-------------------------------------------------------------------
    # Application Initializer

    # init argv
    #
    # argv         Command line arguments
    #
    # This the main program.

    typemethod init {argv} {
        # FIRST, we need to be in the project and get the project data.
        project root

        if {![project intree]} {
            throw FATAL \
                "helptool(1) can only be used within a project tree."
        }

        project load


        # NEXT, validate the remaining arguments.
        set infile ""
        set outfile ""

        set argc [llength $argv]

        if {$argc == 1} {
            set infile  [lindex $argv 0]
            set outfile [file rootname $infile].helpdb
        } elseif {$argc == 2} {
            set infile  [lindex $argv 0]
            set outfile [lindex $argv 1]
        } else {
            app usage
            exit 1
        }

        puts "Input: $infile"
        puts "Output: $outfile"

        # NEXT, if the outfile exists, delete it.
        file delete $outfile

        if {[file exists $outfile]} {
            puts "Error, output file already exists and cannot be deleted."
            exit 1
        }

        # NEXT, initialize the .help compiler and the page macro processor.
        $type CompilerInit
        $type MacroInit

        # NEXT, create the help db in the global namespace so that
        # the macro code can see it.

        sqldocument ::hdb   \
            -autotrans off  \
            -rollback  off

        hdb open $outfile
        hdb clear
        hdb eval [readfile [file join $::app_helptool::library help.sql]]

        # NEXT, create a parmdb so that the help can acquire the parm
        # docs.
        ::athena::parmdb ::pdb

        # NEXT, process the input file.
        set code [catch {$type CompileInputFile $infile} result]

        if {$code} {
            puts $::errorInfo
        }

        # NEXT, close the database.
        hdb close

        # NEXT, if there was a problem, notify the user and
        # delete the outfile.
        if {$code} {
            puts "Could not compile input file $infile:\n$result"
            file delete $outfile
        }

        return
    }

    # usage
    # 
    # Displays the application usage.

    typemethod usage {} {
        puts [outdent {
            Usage: helptool [options...] file.help [file.helpdb]
        }]
    }

    #-------------------------------------------------------------------
    # Page Body macro processor

    # MacroInit
    #
    # Initializes the macro processor.

    typemethod MacroInit {} {
        # FIRST, create the macro processor
        macro ::mac

        mac register ::kitedocs::ehtml
        mac register ::helpmacro
        mac reset

        mac smartalias super 0 - {args...} [mytypemethod Compiler_super]
    }
    

    #-------------------------------------------------------------------
    # Compiler

    # CompilerInit
    #
    # Initializes the compiler.

    typemethod CompilerInit {} {
        # FIRST, create the slave interpreter used to parse the input
        # files.
        set compiler [interp create -safe]

        $compiler alias page       $type Compiler_page
        $compiler alias alias      $type Compiler_alias
        $compiler alias include    $type Compiler_include
        $compiler alias image      $type Compiler_image
        $compiler alias macro      $type Compiler_macro
        $compiler alias macroproc  $type Compiler_macroproc
        $compiler alias super      $type Compiler_super
        $compiler alias object     $type Compiler_object
    }


    # CompileInputFile infile
    #
    # infile     The main input file.
    #
    # Compiles the input file into the help db.

    typemethod CompileInputFile {infile} {
        # FIRST, compile the input
        $compiler invokehidden -global source $infile

        # NEXT, translate the pages from ehtml(5) to html.
        hdb eval {
            SELECT * FROM helpdb_pages
        } pageInfo {
            unset -nocomplain pageInfo(*)

            # FIRST, get the expanded text, first making this page's
            # information available.
            helpmacro setinfo [array get pageInfo]
            set newText [mac expandonce $pageInfo(text)]

            # NEXT, strip out the HTML, for searching
            regsub -all -- {<[^>]+>} $newText "" searchText

            # NEXT, save it in the database.
            hdb eval {
                UPDATE helpdb_pages
                SET text = $newText
                WHERE path=$pageInfo(path);

                INSERT INTO helpdb_search(path,title,text)
                VALUES($pageInfo(path),$pageInfo(title),$searchText);
            }
        }
    }


    # Compiler_page parent slug title text
    #
    # parent      Path of parent page, or "" for root
    # slug        The page's name, or "" for the root
    # title       The page title
    # text        The raw text of the page.
    #
    # Defines a help page.

    typemethod Compiler_page {parent slug title text} {
        # FIRST, get the path.
        set path [$type MakePath $parent $slug]

        # NEXT, validate the input
        require {$text  ne ""} "Page \"$path\" has no text"

        # NEXT, make the page
        $type MakePage $parent $slug $title "" $text
    }

    # Compiler_alias parent slug title alias
    #
    # parent      Path of parent page, or "" for root
    # slug        The page's name, or "" for the root
    # title       The page title
    # alias       Path of page to which this is an alias.
    #
    # Defines a help page.

    typemethod Compiler_alias {parent slug title alias} {
        # FIRST, get the path.
        set path [$type MakePath $parent $slug]

        # NEXT, validate the input
        require {$alias ne ""} "Aliased page \"$path\" has no alias"

        # NEXT, make the page
        $type MakePage $parent $slug $title $alias ""
    }


    # MakePage parent slug title alias text
    #
    # parent      Path of parent page, or "" for root
    # slug        The page's name, or "" for the root
    # title       The page title
    # alias       Path of page to which this is an alias.
    # text        The raw text of the page.
    #
    # Creates a help page for the "page" and "alias" commands.

    typemethod MakePage {parent slug title alias text} {
        assert {$alias ne "" || $text ne ""}

        # FIRST, get the path.
        set path [$type MakePath $parent $slug]

        # NEXT, validate the input
        require {
            ($parent eq "" && $slug eq "") || 
            ($parent ne "" && $slug ne "")
        } "Only the root page can have an empty slug."

        if {$slug ne "" && [catch {slug validate $slug} result]} {
            error "Misformed slug for page \"$path\""
        }
        require {$title ne ""} "Page \"$path\" has no title"


        if {[hdb exists {
            SELECT path FROM helpdb_reserved WHERE path=$path}]
        } {
            error "Duplicate entity path: \"$path\""
        }

        if {$parent ne ""} {
            if {![hdb exists {
                SELECT path FROM helpdb_pages WHERE path=$parent
            }]} {
                error "Page \"$path\"'s parent does not exist: \"$parent\""
            }

            hdb eval {
                UPDATE helpdb_pages
                SET leaf=0
                WHERE path=$parent;
            }
        }

        if {$alias ne ""} {
            if {![hdb exists {
                SELECT path FROM helpdb_pages WHERE path=$alias
            }]} {
                error "Page \"$path\"'s alias page does not exist: \"$alias\""
            }

            hdb eval {
                SELECT alias FROM helpdb_pages WHERE path=$alias
            } row {
                require {$row(alias) eq ""} \
                    "Page \"$path\"'s alias page is itself aliased: \"$alias\""
            }
        }

        # NEXT, add the page footer.
        if {$text ne ""} {
            append text "<footer>"
        }

        # NEXT, save the page.
        hdb eval {
            INSERT INTO 
            helpdb_pages(path,parent,slug,title,alias,text)
            VALUES($path,$parent,$slug,$title,$alias,$text);
        }
    }

    # MakePath parent slug
    #
    # parent      Path of parent page, or "" for root
    # slug        The page's name, or "" for the root
    #
    # Returns the page's path given its parent and slug.

    typemethod MakePath {parent slug} {
        if {$parent eq "" && $slug eq ""} {
            return "/"
        } elseif {$parent eq "/"} {
            return "/$slug"
        } else {
            return "$parent/$slug"
        }
    }


    # Compiler_image slug title filename
    #
    # slug       The image slug; path is /image/$slug
    # title      A short title
    # filename   The image file on disk
    #
    # Loads an image into the helpdb so that it can be referenced
    # in help pages.

    typemethod Compiler_image {slug title filename} {
        # FIRST, get the path
        set path /image/$slug

        # NEXT, is the path unused?
        if {[hdb exists {
            SELECT path FROM helpdb_reserved WHERE path=$path}]
        } {
            error "Duplicate entity path: \"$path\""
        }

        # NEXT, is it a real image?
        if {[catch {
            set img [image create photo -file $filename]
        } result]} {
            error "Could not open the specified file as an image: $filename"
        }

        # NEXT, get the image data, and save it in the helpdb in PNG
        # format.
        set data [$img data -format png]

        hdb eval {
            INSERT OR REPLACE
            INTO helpdb_images(path,slug,title,data)
            VALUES($path,$slug,$title,$data)
        }

        image delete $img
    } 


    # Compiler_include filename
    #
    # filename   Another .help file
    #
    # Includes the filename into the current file name

    typemethod Compiler_include {filename} {
        $compiler invokehidden -global source $filename
    }

    # Compiler_macro name arglist ?initbody? template
    #
    # name      A name for this fragment
    # arglist   Macro arguments
    # initbody  Initialization body
    # template  tsubst(n) template.
    #
    # Defines a macro that can be used in page bodies.  The macro
    # is essentially a template(n) template.

    typemethod Compiler_macro {name args} {
        mac eval [list template $name {*}$args]
    }

    # Compiler_macroproc name arglist body
    #
    # name      A name for this fragment
    # arglist   Macro arguments
    # body      Proc body
    #
    # Defines a proc that can be used as a macro in page bodies.  
    # It is essentially a normal proc.

    typemethod Compiler_macroproc {name arglist body} {
        mac eval [list proc $name $arglist $body]
    }

    # Compiler_super args
    #
    # args    A command to execute in the main interpreter
    #
    # This command allows the help input to access information from
    # project libraries by accessing the main interpreter in a controlled
    # way.

    typemethod Compiler_super {args} {
        namespace eval :: $args
    }

    # Compiler_object name script
    #
    # name       The object's command name.
    # script     The object definition script.
    #
    # Creates an object type that can later be queried.

    typemethod Compiler_object {name script} {
        namespace eval ::objects:: { }

        if {[catch {
            set obj [object ::objects::$name $script]
        } result opts]} {
            error "Error in object definition \"$name\",\n$result"
        }

        # Make the object available for use as a macro
        mac smartalias $name 1 - {subcommand args...} ::objects::$name

        # Make the object available for use in procs
        $compiler alias $name ::objects::$name
    } 


    #-------------------------------------------------------------------
    # Utility Typemethods for use in macros and so forth.

    # image exists path
    #
    # path - An image path
    #
    # Returns 1 if the image exists, and 0 otherwise.

    typemethod {image exists} {path} {
        hdb exists {SELECT * FROM helpdb_images WHERE path=$path}
    }

    # page exists path
    #
    # path - A page path
    #
    # Returns 1 if the page exists, and 0 otherwise.

    typemethod {page exists} {path} {
        hdb exists {SELECT * FROM helpdb_pages WHERE path=$path}
    }

    # page title path
    #
    # path - A page path
    #
    # Returns the page's title

    typemethod {page title} {path} {
        hdb onecolumn {SELECT title FROM helpdb_pages WHERE path=$path}
    }

}


