// comparison.js: Comparison service
//
// This service is used to interact with the server regarding 
// scenario comparisons, and to provide the data to pages.
'use strict';

angular.module('arachne')
.factory('Comparison', 
['$http', '$q', 'Arachne', 'Entities',
function($http, $q, Arachne, Entities) {
    //---------------------------------------------------------
    // Service Data

    var service = {};

    //-------------------------------------------------
    // Look-up Tables

    var catNames = {
        political:      "Political",
        military:       "Military",
        economic:       "Economic",
        social:         "Social",
        information:    "Information",
        infrastructure: "Infrastructure"
    };

    //----------------------------------------------------------
    // Object Store

    var comps = Entities.retriever('/comparison/index.json');
    var byCat = {};
    var byName = {};
    var chains = {};

    //----------------------------------------------------------
    // Delegated Methods

    service.refresh = comps.refresh;
    service.get     = comps.get;
    service.all     = comps.all;

    //----------------------------------------------------------
    // Requests

    // request(tag, caseId1, caseId2)
    //
    // Request a comparison from the server.  The tag is an
    // Arachne request tag.

    service.request = function(tag,caseId1, caseId2) {
        var deferred = $q.defer();

        Arachne.request(tag, '/comparison/request.json', {
            case1: caseId1,
            case2: caseId2
        }).then(function (stat) {
            if (stat.ok) {
                comps.add(stat.result[0]);
                PopulateIndices();
            }
            deferred.resolve(stat);
        });      

        return deferred.promise;
    } 

    service.compId = function(caseId1, caseId2) {
        if (caseId2) {
            return caseId1 + '/' + caseId2;
        } else {
            return caseId1;
        }
    }

    // requestChain(compId, varname)
    //
    // Requests the chain data structure for the named variable
    // from the server.

    service.requestChain = function(compId, varname) {
        Arachne.request('comp-chain', '/comparison/chain.json', {
            comp: compId,
            varname: varname
        }).then(function (stat) {
            if (stat.ok) {
                chains[compId] = chains[compId] || {}
                chains[compId][varname] = ProcessChain(stat.result[0]);
            }
        });
    }

    // chain(compId, varname)
    //
    // Retrieves the chain data structure for the named variable,
    // requesting it if need be.

    service.chain = function(compId, varname) {
        // FIRST, if we have it just return it.
        if (chains[compId] && chains[compId][varname]) {
            return chains[compId][varname];
        } else {
            return [];
        }
    }

    //----------------------------------------------------------
    // Processing the Chain

    // ProcessChain(raw) returns the processed chain.
    var ProcessChain = function(raw) {
        // FIRST, make an index, by name.
        var ndx = {};

        for (var i = 0; i < raw.length; i++) {
            ndx[raw[i].name] = raw[i];
        }

        // NEXT, build up the chain.
        var chain = [];
        var next  = raw[0].name;
        ExtendChain(chain, null, 0, ndx, next);

        return chain;
    };

    var ExtendChain = function ExtendChain(chain, parent, level, ndx, next) {
        var diff = ndx[next];
        diff.numInputs = Object.keys(diff.inputs).length;

        // FIRST, copy the inputs into an array, and annotate them.
        var inputs = [];

        for (name in diff.inputs) {
            var input = ndx[name];
            input.parent = parent;
            input.level  = level;
            input.class  = "indent"+level;
            input.score  = diff.inputs[name];
            inputs.push(input);
        }

        // NEXT, sort the array in decreasing order by score.
        inputs.sort(function(a, b) {
            if (a.score < b.score) {
                return 1;
            } else if (a.score > b.score) {
                return -1;
            } else {
                return 0;
            }
        });

        // NEXT, add the array to the chain, finding child inputs.
        for (var i = 0; i < inputs.length; i++) {
            inputs[i].id = chain.length;
            chain.push(inputs[i]);

            ExtendChain(chain, inputs[i].id, level+1, ndx, inputs[i].name);
        }
    }

    //----------------------------------------------------------
    // Queries

    // categories() -- Return the list of output categories
    service.categories = function() {
        return Object.keys(catNames);
    }

    // catName(cat) -- Return the category name
    service.catName = function(cat) {
        return catNames[cat] || 'Unknown';
    }

    // case1(compId) -- Return case1 metadata
    service.case1 = function(compId) {
        var comp = comps.get(compId);

        if (comp) {
            return Arachne.getCase(comp.case1);
        }
    }

    // case2(compId) -- Return case2 metadata
    service.case2 = function(compId) {
        var comp = comps.get(compId);

        if (comp) {
            return Arachne.getCase(comp.case2);
        }
    }

    // size() -- Number of outputs
    service.size = function(compId) {
        return service.outputs(compId).length;
    }

    // catSize(cat) -- Number of outputs in the category
    service.catSize = function(compId,cat) {
        if (byCat[compId]) {
            return byCat[compId][cat].length;
        } else {
            return 0;
        }
    }

    // byCat(compId, cat) -- Returns the outputs by category
    service.byCat = function(compId, cat) {
        var comp = comps.get(compId);

        if (!comp) {
            return [];
        }

        var result = [];

        for (var i = 0; i < byCat[compId][cat].length; i++) {
            var ndx = byCat[compId][cat][i];
            result.push(comp.outputs[ndx]);
        }

        return result;
    }

    // outputs(compId) -- Returns a possibly empty array of outputs.
    service.outputs = function(compId) {
        var comp = comps.get(compId);

        if (comp) {
            return comp.outputs;
        } else {
            return [];
        }
    }

    service.outputNames = function(compId) {
        var outputs = service.outputs(compId);
        var result = [];

        for (var i = 0; i < outputs.length; i++) {
            result.push(outputs[i].name);
        }

        return result.sort();
    }

    service.output = function(compId, varname) {
        var outputs = service.outputs(compId);

        if (byName[compId] && byName[compId][varname]) {
            return outputs[byName[compId][varname]];
        }

        return null;
    }

    //----------------------------------------------------------
    // Comparison wrapper

    // wrapper(compId)
    //
    // compId   - A comparison ID, e.g., 'case00/case01'
    //
    // Returns a wrapper object for this comparison ID.
    // TBD: caseId1, caseId2 instead of compId?

    service.wrapper = function(compId) {
        return {
            categories: service.categories,
            catName:    service.catName,
            meta:    function()     { return service.get(compId);          },
            case1:   function()     { return service.case1(compId);        },
            case2:   function()     { return service.case2(compId);        },
            size:    function()     { return service.size(compId);         },
            outputs: function()     { return service.outputs(compId);      },
            catSize: function(cat)  { return service.catSize(compId, cat); },
            byCat:   function(cat)  { return service.byCat(compId, cat);   },
            output:  function(name) { return service.output(compId, name); }
        };
    }

    //----------------------------------------------------------
    // Chain wrapper

    // chainWrapper(compId,varname)
    //
    // compId   - A comparison ID, e.g., 'case00/case01'
    // varname  - A variable name included in the comparison.
    //
    // Returns a wrapper object for this comparison ID and chain variable.

    service.chainWrapper = function(compId,varname) {
        var w = {
            categories: service.categories,
            catName:    service.catName,
            meta:    function()     { return service.get(compId);          },
            case1:   function()     { return service.case1(compId);        },
            case2:   function()     { return service.case2(compId);        },
            size:    function()     { return service.size(compId);         },
            outputs: function()     { return service.outputs(compId);      },
            catSize: function(cat)  { return service.catSize(compId, cat); },
            byCat:   function(cat)  { return service.byCat(compId, cat);   },
            output:  function(name) { return service.output(compId, name); }
        };

        w.items = function() { return service.chain(compId, varname); }

        return w;
    }


    //----------------------------------------------------------
    // Helpers

    var PopulateIndices = function() {
        byCat = {};
        byName = {};

        for (var i = 0; i < comps.all().length; i++) {
            var comp = comps.all()[i];

            byCat[comp.id] = {};
            byName[comp.id] = {};

            for (var cat in catNames) {
                byCat[comp.id][cat] = [];
            }

            for (var j = 0; j < comp.outputs.length; j++) {
                var output = comp.outputs[j];
                // TBD: I think this should be done before the data
                // is saved.
                output.numInputs = Object.keys(output.inputs).length;
                byCat[comp.id][output.category].push(j);
                byName[comp.id][output.name] = j;
            }
        }
    };


    //----------------------------------------------------------
    // Dynamic Initialization
    service.refresh().then(function() {
        PopulateIndices();
    });

    // Return the new service.
    return service;
}]);