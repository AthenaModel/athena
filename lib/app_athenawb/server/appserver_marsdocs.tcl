#-----------------------------------------------------------------------
# TITLE:
#    appserver_marsdocs.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: External Mars Documents
#
#    my://app/mars/docs/...
#
# TBD:
#    This module provides access to files in Athena's /mars/docs directory.
#    As now installed, this directory is mostly empty, containing one
#    index.html file, and some PDFs and other documents; the man pages
#    are no longer accessible.  Either we should simply get rid of this
#    capability, or we should add the ability to invoke .pdf and .docx
#    files, and use the capability to make the MAG accessible
#    from within Athena.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module MARSDOCS {
    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /mars/docs/{path}.html {mars/docs/(.+\.html)} \
            text/html [myproc /mars/docs:html]                           \
            "An HTML file in the Athena mars/docs/ tree."

        appserver register /mars/docs/{path}.txt {mars/docs/(.+\.txt)} \
            text/plain [myproc /mars/docs:html]                        \
            "A .txt file in the Athena mars/docs/ tree."

        appserver register /mars/docs/{image} {mars/docs/(.+\.(gif|jpg|png))} \
            tk/image [myproc /mars/docs:image] {
                A .gif, .jpg, or .png file in the Athena mars/docs/ tree.
            }   

    }

    #-------------------------------------------------------------------
    # /mars/docs/{path}.html:   Text files the browser can render for itself.
    # /mars/docs/{path}.txt
    #
    # Match Parameters:
    # 
    # {path} ==> $(1)   - Path within the mars/docs directory

    # /mars/docs:html udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    # Retrieves the file.  Note that this routine works fine for plain
    # text.

    proc /mars/docs:html {udict matchArray} {
        upvar 1 $matchArray ""

        set path $(1)

        return [appfile:text mars/docs $path]
    }

    #-------------------------------------------------------------------
    # /mars/docs/{path}.gif:   Image Files
    # /mars/docs/{path}.jpg
    # /mars/docs/{path}.png
    #
    # Match Parameters:
    # 
    # {path} ==> $(1)   - Path within the mars/docs directory

    # /mars/docs:image udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    # Retrieves the image as a Tk image command.

    proc /mars/docs:image {udict matchArray} {
        upvar 1 $matchArray ""

        set path $(1)

        return [appfile:image mars/docs $path]
    }
}



