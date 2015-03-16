# TODO.md - Athena TODO List

- Significant Outputs:
  - All history variable base names should be unique, e.g., nbsecurity.n rather
    than security.n.
  - If possible, the column names in the hist_* table should match the 
    variable base name.  (But don't break old post-processors.)
  - `::athena::athena compare` is the command to compare two scenarios. 
    - Returns an ::athena::comparison object.
    - Knowledge of how to do output and input comparisons resides in 
      athena/compare.tcl.
  - Comparison objects:
    - Provide comparison data in a variety of forms.
    - Can ask individual vardiff objects for causal chain info.
    - Each vardiff object knows how to determine its potentially significant
      inputs, and how to score them, and is responsible for drilling down.
      - Scores must be saved at the vardiff level. 
  - Comparisons should be provided to front end in JSON form
    - Raw data, not cooked narrative (unless they ask for it).
  - vardiff records provide simple Tcl dictionaries.
  - Comparison object puts together following dictionary of outputs
```
comp => Dictionary of variable types by PMESII category
     -> <cty> => political, social, etc.
              -> <vtype> => Metadata by var. type name, e.g., "nbmood.n"
                         -> TBD...
                         -> sigdiffs => List of vars with significant diffs.
                                     -> <vname> => Dict of diff parms by var name.
                                                -> <key1> -> <keyval1>
                                                ...
                                                -> <keyN> -> <keyvalN>
                                                -> val1 -> <value1>
                                                -> val2 -> <value2>
                                                -> score -> <score>
``` 

  - For example,

```
    political {
      nbsecurity.n {
        ... metadata, TBD
        sigdiffs {
          nbsecurity.N1 {
            n     N1
            val1  25
            val2  75
            score 50
          }
          ...
        }
      }
      ...
    }
    social {
      sat.g.c {
        ... metadata, TBD
        sigdiffs {
          sat.CH1.AUT {
            g     CH1
            c     AUT
            val1  -30.0
            val2  -70.0
            score 40.0
          }
          ...
        }
      }
      ...
    }
```
- Causal Chains


- Document athena(n)
- Make mods work with all athena(n) applications.
- New tests:
  - 010-abevent.test
  - 010-athenadb.test
  - 010-athena.test
- athena(n) HTML generation
  - What to do about icon names?
    - Replace with .png files, with valid URLs?
      - That's probably easiest.
  - Generation of URLs:
    - htools is configured with a dictionary of symbolic names and base URLs.
    - The `$ht link` command will translate "%name/" at the beginning of a
      URL to "$baseurl/".
    - If the "name" is unknown, no link is created; just the link text is
      put in the buffer.
    - athena(n) gets the same dictionary, and delegates it to athenadb(n).
    - athenadb(n) provides a factory method for creating configured htools
      buffers.
    - Code using htools buffers get them from athenadb(n).
- See about giving athena(n) a read-only db.
- Write cellide manpage.



