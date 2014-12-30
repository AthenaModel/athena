# TODO.md - Athena TODO List

- Write cellide manpage.
- Orderx and Dialogs: Design
- Creating orderx instances with context:
  - An orderx can take a parmdict as a constructor argument.
  - An athena_order can take an athenadb object and a parmdict as
    a constructor argument.
  - An order_flunky's "make" method passes its arguments to the
    order being created.
  - An athena_flunky's "make" method inserts the athenadb object 
    at the beginning of the argument list, and calls "next".
  - Thus, to make an athena_order with all necessary context, 
    just use athena_flunky's "make" method.
- orderx_dialog:
  - Invoking a dialog:
    - Option 1: NO
      - flunky enter <orderName> ?parmdict or args?
      - Flunky creates and initializes the order instance.
      - Flunky invokes the dialog, configuring it with itself
        and the order instance.
        - The order has all it needs.
        - NOTE: Requires flunky to know about dialog type.
        - But this is really an application level thing.
    - Option 2: YES
      - orderx_dialog enter <flunky> <orderName> ?parms?
      - [orderx_dialog enter] uses flunky to create the
        order instance, and initializes the order instance
        with the parms.
        - [orderx_dialog enter] creates a dialog instance,
          initializing it with the flunky and the order object.
        - For convenience, [app enter] calls to 
          [orderx_dialog enter], passing the flunky as first 
          argument.
    - Option 2 maintains a better separation between library
      and application code.  An Athena back end won't load
      Tk, and its code base has no reason to know about
      orderx_dialog.
- Order Dynaforms
  - The essential thing is that the order dynaform's callbacks
    can reference the order object itself.
  - Dynaform already allows field callbacks to reference upstream
    fields.
  - Allow "-contextdict": additional values that are not part of
    the form parameters but which are made available to the
    callbacks.
