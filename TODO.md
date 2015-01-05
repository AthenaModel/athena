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
      - Define [enterx] executive command to allow popping up the
        dialog.
- Application
  - Once we convert, get <OrderEntry> events from "::flunky" rather than
    from "::order".
    - Should orderx_dialog instances call ::flunky explicitly?
      - No; it's a GUI thing.