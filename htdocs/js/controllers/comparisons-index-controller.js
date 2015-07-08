// comparisons-index-controller.js
'use strict';

angular.module('arachne')
.controller('ComparisonsIndexController', 
['$filter','Arachne', function($filter,Arachne) {
    var controller = this;   // For use in callbacks

    // Delegated Functions
    this.cases = Arachne.cases;
    this.comps = Arachne.comps;
    this.statusData = Arachne.statusData;
    this.case = Arachne.getCase;

    // Operations
    this.remove = function(compId) {
        Arachne.request('comp-manage', '/comparison/remove.json', {
            comp:     compId
        }).then(function (stat) {
            if (stat.ok) {
                stat.message = 'Removed comparison "' + compId + '".'
                Arachne.refreshComps();
            }
        });
    }

    this.compare = function() {
        Arachne.request('comp-manage', '/comparison/new.json', {
            case1: this.caseid1,
            case2: this.caseid2
        }).then(function (stat) {
            if (stat.ok) {
                var meta = stat.result[0];
                stat.message = 'Created comparison "' + meta.id + '".'
                Arachne.refreshComps();
            }
        });      
    }

    this.json = function() {
        var jsonData = Arachne.statusData('comp-manage');

        if (jsonData) {
            return $filter('json')(jsonData,2);
        } else {
            return undefined;
        }
    }
}]);
