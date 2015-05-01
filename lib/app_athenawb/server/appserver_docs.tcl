#-----------------------------------------------------------------------
# TITLE:
#    appserver_docs.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    app_sim(n), appserver(sim) module: External Documents
#
#    /app/docs/...
#
# TBD:
#    This module provides access to files in Athena's /docs directory.
#    As now installed, this directory is mostly empty, containing one
#    index.html file, and some PDFs and other documents; the man pages
#    are no longer accessible.  Either we should simply get rid of this
#    capability, or we should add the ability to invoke .pdf and .docx
#    files, and use the capability to make the AAG, AUG, etc., available
#    from within Athena.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# appserver module

appserver module DOCS {
    #-------------------------------------------------------------------
    # Type Variables

    #-------------------------------------------------------------------
    # Public methods

    # init
    #
    # Initializes the appserver module.

    typemethod init {} {
        # FIRST, register the resource types
        appserver register /docs/{path}.html {docs/(.+\.html)} \
            text/html [myproc /docs:html]                      \
            "An HTML file in the Athena docs/ tree."

        appserver register /docs/{path}.txt {docs/(.+\.txt)} \
            text/plain [myproc /docs:html]                   \
            "A .txt file in the Athena docs/ tree."

        appserver register /docs/{imageFile} {docs/(.+\.(gif|jpg|png))} \
            tk/image [myproc /docs:image]                               \
            "A .gif, .jpg, or .png file in the Athena /docs/ tree."
    }

    #-------------------------------------------------------------------
    # /docs/{path}.html:   Text files the browser can render for itself.
    # /docs/{path}.txt
    #
    # Match Parameters:
    # 
    # {path} ==> $(1)   - Path within the docs directory

    # /docs:html udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    #     (1) - *.html or *.txt
    #
    # Retrieves the file.  Note that this routine works fine for plain
    # text.

    proc /docs:html {udict matchArray} {
        upvar 1 $matchArray ""

        set path $(1)

        return [appfile:text docs $path]
    }

    #-------------------------------------------------------------------
    # /docs/{path}.gif:   Image Files
    # /docs/{path}.jpg
    # /docs/{path}.png
    #
    # Match Parameters:
    # 
    # {path} ==> $(1)   - Path within the docs directory

    # /docs:image udict matchArray
    #
    # udict      - A dictionary containing the URL components
    # matchArray - Array of pattern matches
    #
    # Retrieves the image as a Tk image command.

    proc /docs:image {udict matchArray} {
        upvar 1 $matchArray ""

        set path $(1)

        return [appfile:image docs $path]
    }
}



