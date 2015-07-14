#-----------------------------------------------------------------------
# TITLE:
#   domain/index.tcl
#
# PROJECT:
#   athena - Athena Regional Stability Simulation
#
# PACKAGE:
#   app_arachne(n): Arachne Implementation Package
#
# AUTHOR:
#   Will Duquette
#
# DESCRIPTION:
#   /index.html: A direct URL for the main index page.
#
#-----------------------------------------------------------------------

#-----------------------------------------------------------------------
# FIRST, define the domain.

proc /index.html {} {
    return [subst -nobackslashes -novariables {

<html><head>
<title>Arachne: Main Index</title>
<link rel="stylesheet" href="/athena.css">
</head>

<body>

[athena::element header Arachne]

<table cellpadding="5" width="100%" class="linkbar">
<tr class="oddrow" valign="top" class valign="bottom">
<td><div class="linkbar">
<a href="/index.html">Home</a>
<a href="/scenario/index.html">Scenarios</a>
<a href="/help/index.html">Help</a>
</div></td></tr>
</table><p> 

<h2>Documentation</h2>

<ul>
<li> <a href="arachne.html">Arachne Interface Specification</a>
</ul>

[athena::element footer]

</body>
</html>

    }]    
}

