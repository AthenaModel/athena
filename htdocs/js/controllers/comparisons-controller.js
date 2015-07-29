// comparisons-controller.js -- Page controller for #/comparisons
'use strict';

angular.module('arachne')
.controller('ComparisonsController', 
['$filter', 'Arachne', 'Comparison',
function($filter,Arachne,Comparison) {
    var controller = this;   // For use in callbacks

    // Template URL
    this.template = function(suffix) {
        return '/templates/pages/comparisons' + suffix;
    }


    // Delegated Functions
    this.cases = Arachne.cases;
    this.comps = Comparison.all;

    // Operations
    this.compare = function() {
        Comparison.request('comparisons-compare', 
                           this.caseid1, this.caseid2);      
    }

    this.json = function() {
        var jsonData = Arachne.statusData('comparisons-compare');

        if (jsonData) {
            return $filter('json')(jsonData,2);
        } else {
            return undefined;
        }
    }

}]);
