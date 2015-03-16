#-----------------------------------------------------------------------
# TITLE:
#    gradient.tcl
#
# AUTHOR:
#    Will Duquette
#
# DESCRIPTION:
#    Color gradients for use by the GUI.
#
#-----------------------------------------------------------------------

# coopgradient: A fill color gradient for satisfaction levels

::marsutil::gradient coopgradient \
    -mincolor \#FF0000          \
    -midcolor \#FFFFFF          \
    -maxcolor \#00FF00          \
    -minlevel 0.0               \
    -midlevel 50.0              \
    -maxlevel 100.0

# covgradient: A fill color gradient for coverage fractions

::marsutil::gradient covgradient \
    -mincolor \#FFFFFF          \
    -midcolor \#FFFFFF          \
    -maxcolor \#0000FF          \
    -minlevel 0.0               \
    -midlevel 0.0               \
    -maxlevel 1.0

# pcfgradient: A fill color gradient for econ_n pcf's

::marsutil::gradient pcfgradient \
    -mincolor \#FF0000          \
    -midcolor \#FFFFFF          \
    -maxcolor \#00FF00          \
    -minlevel 0.0               \
    -midlevel 1.0               \
    -maxlevel 2.0

# satgradient: A fill color gradient for satisfaction levels

::marsutil::gradient satgradient \
    -mincolor \#FF0000          \
    -midcolor \#FFFFFF          \
    -maxcolor \#00FF00          \
    -minlevel -100.0            \
    -midlevel 0.0               \
    -maxlevel 100.0

# secgradient: A fill color gradient for security levels

::marsutil::gradient secgradient \
    -mincolor \#FF0000          \
    -midcolor \#FFFFFF          \
    -maxcolor \#00FF00          \
    -minlevel -100.0            \
    -midlevel 0.0               \
    -maxlevel 100.0

# relgradient: A fill color gradient for affinities and relationships

::marsutil::gradient relgradient \
    -mincolor \#FF0000          \
    -midcolor \#FFFFFF          \
    -maxcolor \#00FF00          \
    -minlevel -1.0              \
    -midlevel 0.0               \
    -maxlevel 1.0






