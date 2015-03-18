#----------------------------------------------------------------------
# TITLE:
#    webpage.tcl
#
# AUTHOR:
#    Dave Hanks
#
# DESCRIPTION:
#    webpage is where common HTML and javascript modules are loaded
#    from. This is essentially static content for use by any JNEM
#    web page and controls the look and feel of the content.
#
#-----------------------------------------------------------------------

#----------------------------------------------------------------------
# webpage singleton 


snit::type webpage {
    pragma -hasinstances 0 -hastypedestroy 0

    #------------------------------------------------------------------
    # Type Components

    # none
    #
    #------------------------------------------------------------------
    # Typevariables
    
    # none
    #------------------------------------------------------------------
    # Type Constructor

    typeconstructor {
        # FIRST, head tags that should appear in each web page. These
        # only need to be specified once.
        html::headTag "link rel='stylesheet' href='spinstyle.css' type='text/css' media='screen' /"
        html::headTag "script type='text/javascript' src='spinbox.js'></script"
    }

    #------------------------------------------------------------------
    # Public Type methods
    #------------------------------------------------------------------
    # Typemethod css
    #
    # Returns all CSS properties 
    #
    # The properties are as follows:
    #
    # .header           - The top of the main index.html page
    # .header h2        - <h2> tag properties within header
    # .header h1        - <h1> tag properties within header
    # .container        - for container classes, the tables are in this
    # .sidebar          - sidebar properties
    # .sidebar h2       - <h2> tag properties within sidebar
    # .reportcontent    - defines properties for all reports
    # .reportcontent h2 - <h2> tags within a report, the report headers
    # .reportcontent h4 - <h4> tags within a report, the report data
    # .reportcontent th - <th> tags within a report
    # .reportcontent td - <td> tags within a report
    # img               - <img> tag common properties
    # #thinborder       - a style to put a thin border around an image

    typemethod css {} {
        return [outdent {
            <style type='text/css'>
            .header { 
                width: 100%;
                height: 225px;
                background-color: #CCCCCC;
                font-family: 'Luxi Sans';
                font-weight: bold;
                text-align: center;
            }
    
            .header h1 {
                background-color: #CCCCCC;
                text-align: center;
            }
    
            .header h2 {
                background-color: #CCCCCC;
                text-align: center;
            }
    
            .container {
                position: relative;
                width: 100%;
                background: #FFFFFF;
                margin: 0 auto;
                text-align: left;
            }
            
            .sidebar {
                float: left;
                width: 220px;
                height: 700px;
                background-color: #CCCCCC;
                font-family: 'Luxi Sans';
            }
            
            .sidebar h2 {
                font-weight: bold;
            }

            .sidebar a {
                font-size: small;
            }

            .reportcontent {
                margin: 0 0 0 220px;
                padding: 5px;
                background-color: #FFFFFF;
                font-family: 'Luxi Sans'
            }
    
            .reportcontent h2 {
                text-align: center;
            }
    
            .reportcontent h4 {
                text-align: center;
            }
    
            .reportcontent th {
                background-color: #996633;
            }
    
            .reportcontent td {
                text-align: center;
                font-size: small;
                background-color: #CC9966;
            }
    
            .links {
                display: block;
                text-align: center;
                width: 140px;
                margin: auto;
                padding-top: 5px;
            }
    
            img {
                border: 0px;
            }

            img.thinborder {
                border: 1px solid;
                color: #000000;
            }

            .scrollheader {
                margin: 0 15px 0 225px;
                background-color: #FFFFFF;
                font-family: 'Luxi Sans';
            }

            .scrollheader h2 {
                text-align: center;
            }

            .scrollheader h4 {
                text-align: center;
            }

            .scrollheader th {
                background-color: #996633;
            }

            .scrollheader td {
                text-align: center;
                font-size: small;
                background-color: #CC9966;
            }

            .scrollcontent {
                margin: 0 0 0 225px;
                height: 550px;
                overflow: auto;
                background-color: #FFFFFF;
                font-family: 'Luxi Sans';
            }

            .scrollcontent td {
                text-align: center;
                font-size: small;
                background-color: #CC9966;
            }

            </style>
        }]
    }
    
    #------------------------------------------------------------------
    # Type method: js   max
    #
    # max   - A max number for the spinbox to allow for display
    #
    # This method returns javascript code to the caller, normally this
    # code would be included in a webpage that needed to include a spinbox
    # and a submit button.
    # 
    # This method assumes that the spinbox will be included in a span tag
    # with the id 'select' and that the webpage including this spinbox
    # has a method called 'sendRequest' in javascript that handles the
    # onclick event when the submit button is pressed.

    typemethod js {max} {
        return "
        <script type='text/javascript'>
          var spinCtrl = new SpinControl($max);
          spinCtrl.GetAccelerationCollection().Add(new SpinControlAcceleration(5, 500));
          spinCtrl.GetAccelerationCollection().Add(new SpinControlAcceleration(15, 1750));
          var sb = document.getElementById('select');
          sb.appendChild(spinCtrl.GetContainer());
          spinCtrl.StartListening();
          var elem = document.createElement('input');

          elem.setAttribute('type', 'submit');
          elem.setAttribute('name', 'submit');
          elem.setAttribute('value', 'Submit');
          elem.onclick = function() {sendRequest(spinCtrl.GetCurrentValue());};

          sb.appendChild(elem);
        </script>"
    }

    #------------------------------------------------------------------
    # Type method: doctype
    #
    # Returns the DOCTYPE declaration. It may be necessary to make
    # different versions of this for different browsers.
    typemethod doctype {} {
        set html "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\" \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n"

        return $html
    }

    #------------------------------------------------------------------
    # Type method: head title
    #
    # Returns the HTML header and uses the title provided. That title 
    # appears in the title bar of the browser window.
    
    typemethod head {title} {
        set html "<meta http-equiv=\"Content-Type\" content=\"text-html; charset=UTF-8\">\n"
        # NEXT, JNEM logo linked to the home page
        append html [html::head $title]\n
        return $html
    }
    
    #------------------------------------------------------------------
    # Type method: header title
    #
    #	Generate HTML for the standard page header
    #
    # Arguments:
    #	title	The page title
    #
    # Results:
    #	HTML for the page header.
    
    typemethod header {title} {
        # FIRST, the head
        set html [html::head $title]\n
    
        # NEXT, JNEM logo linked to the home page
        append html "<a href='/'>"
        append html "<img src=/images/JNEM_Logo.png alt='Home'>"
        append html "</a>"
        # NEXT, the body tag
        append html [html::bodyTag]\n
        return $html
    }
}
