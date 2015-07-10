// comp.js: Comp service
//
// This service makes comparison data available to controllers.
//
// Unlike cases, comparisons are static; once data is retrieved,
// it remains valid until the comparison is destroyed.

'use strict';

angular.module('arachne')
.factory('Comp', ['$http', '$timeout', '$q', 'Arachne',
function($http, $timeout, $q, Arachne) {
    var service = {};    // The service object

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

    //--------------------------------------------------
    // Primary Data Structures

    var comps = {};   // Cached data by comp

    //--------------------------------------------------
    // Data Retrieval

    // retrieve(compId)
    //
    // compId   - A comparison ID, e.g., 'comp00'
    //
    // Retrieves the comparison data if it hasn't already been loaded.
    // If the comparison no longer exists, removes its data.

    service.retrieve = function(compId) {
        var meta = Arachne.getComp(compId);

        // FIRST, if comp is not defined, remove any data that exists
        // for that comp.
        if (!meta) {
            delete comps[compId];
            return;
        }

        // NEXT, if we've already got the comp, we've got it.
        if (comps[compId]) {
            return
        }

        // NEXT, fill in the basics
        comps[compId] = {
            meta:  meta,
            case1: Arachne.getCase(meta.case1),
            case2: Arachne.getCase(meta.case2),
            byName: {},
            byCat:  {},
            byType: {},
            typesByCat: {}
        }

        for (var cat in catNames) {
            comps[compId].byCat[cat]      = [];
            comps[compId].typesByCat[cat] = [];
        }

        // NEXT, get the comparison's outputs; we'll grab
        // chains later as needed.
        var url = '/comparison/' + compId + '/outputs.json';

        $http.get(url).success(function(data) {
            CategorizeOutputs(comps[compId], data);
        });
    }

    // CategorizeOutputs(comp, data)
    //
    // comp  - A comp object, as stored in comps[].
    // data  - A list of output records from the server
    //
    // Steps through the data records, indexing them as needed,
    // and adding results to comp.

    var CategorizeOutputs = function(comp, data) {
        // FIRST, get the outputs by name, the types by category, and the
        // output names by type

        for (var i = 0; i < data.length; i++) {
            var item = data[i];

            // FIRST, save the item by name and category
            comp.byName[item.name] = item;
            comp.byCat[item.category].push(item.name);

            // NEXT, save output names by type name.
            if (!comp.byType[item.type]) {
                comp.byType[item.type] = [];
            }

            comp.byType[item.type].push(item.name);

            // NEXT, save type names by category.
            if (comp.typesByCat[item.category].indexOf(item.type) === -1) {
                comp.typesByCat[item.category].push(item.type)
            }
        }

        // NEXT, sort the lists of names.
        for (var cat in comp.byCat) {
            comp.byCat[cat] = comp.byCat[cat].sort();
            comp.typesByCat[cat] = comp.typesByCat[cat].sort();
        }

        for (var type in comp.byType) {
            comp.byType[type] = comp.byType[type].sort();
        }
    };

    //--------------------------------------------------
    // Comparison Queries

    // meta(compId) -- Return comparison metadata
    service.meta = function(compId) {
        if (comps[compId]) {
            return comps[compId].meta;
        } else {
            return "Unknown";
        }
    }

    // case1(compId) -- Return case1 metadata
    service.case1 = function(compId) {
        if (comps[compId]) {
            return comps[compId].case1
        }
    }

    // case2(compId) -- Return case2 metadata
    service.case2 = function(compId) {
        if (comps[compId]) {
            return comps[compId].case2
        }
    }

    // categories() -- Return the list of output categories
    service.categories = function() {
        return Object.keys(catNames);
    }

    // catname(cat) -- Return the category name
    service.catname = function(cat) {
        return catNames[cat] || 'Unknown';
    }

    // num() -- Number of outputs
    service.num = function(compId) {
        if (comps[compId]) {
            return Object.keys(comps[compId].byName).length;
        } else {
            return 0;
        }        
    }

    // numInCat(cat) -- Number of outputs in the category
    service.numInCat = function(compId,cat) {
        if (comps[compId]) {
            return comps[compId].byCat[cat].length;
        } else {
            return 0;
        }
    }

    // byCat(compId, cat) -- Returns the outputs by category
    service.byCat = function(compId, cat) {
        var result = [];

        if (!comps[compId]) {
            return;
        }

        var comp = comps[compId]

        for (var i = 0; i < comp.byCat[cat].length; i++) {
            var name = comp.byCat[cat][i];
            result.push(comp.byName[name]);
        }

        return result;
    }

    // outputs(compId) -- Returns all outputs
    service.outputs = function(compId) {
        if (!comps[compId]) {
            return;
        }

        var result = [];

        for (var name in comps[compId].byName) {
            result.push(comps[compId].byName[name]);
        }

        return result;
    }

    return service;
}]);
