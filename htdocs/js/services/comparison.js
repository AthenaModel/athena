// comparison.js: Comparison service
//
// This service is used to interact with the server regarding 
// scenario comparisons, and to provide the data to pages.
'use strict';

angular.module('arachne')
.factory('Comparison', 
['$q', 'Arachne', 'Entities',
function($q, Arachne, Entities) {
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

    //----------------------------------------------------------
    // Delegated Methods

    service.refresh = comps.refresh;
    service.get     = comps.get;
    service.all     = comps.all;

    //----------------------------------------------------------
    // Requests

    service.request = function(tag,caseId1, caseId2) {

        var deferred = $q.defer();

        Arachne.request(tag, '/comparison/request.json', {
            case1: caseId1,
            case2: caseId2
        }).then(function (stat) {
            if (stat.ok) {
                comps.add(stat.result[0]);
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

    //----------------------------------------------------------
    // Comparison object

    service.retrieve = function(compId) {
        // FIRST, get the comparison; return undefined if it doesn't
        // exist.
        var comp = comps.get(compId);

        if (!comp) {
            return;
        }

        // NEXT, fill in the basics
        comp.longname1 = Arachne.getCase(comp.case1).longname;
        comp.longname2 = Arachne.getCase(comp.case1).longname;

        return comp;

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

        // NEXT, return a comparison object
        return {
            meta:    function()     { return service.meta(compId);          },
            case1:   function()     { return service.case1(compId);         },
            case2:   function()     { return service.case2(compId);         },
            size:    function()     { return service.size(compId);          },
            outputs: function()     { return service.outputs(compId);       },
            catSize: function(cat)  { return service.catSize(compId, cat); },
            byCat:   function(cat)  { return service.byCat(compId, cat);    },
            output:  function(name) { return service.output(compId, name);  }
        };

    }

    //----------------------------------------------------------
    // Queries

    // categories() -- Return the list of output categories
    service.categories = function() {
        return Object.keys(catNames);
    }

    // catname(cat) -- Return the category name
    service.catname = function(cat) {
        return catNames[cat] || 'Unknown';
    }



    //----------------------------------------------------------
    // Dynamic Initialization
    service.refresh();

    // Return the new service.
    return service;
}]);