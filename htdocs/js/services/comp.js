// comp.js: Comp service
//
// This service makes comparison data available to controllers.
'use strict';

angular.module('arachne')
.factory('Comp', ['$http', '$timeout', '$q', 'Arachne',
function($http, $timeout, $q, Arachne) {
    var service = {};    // The service object

    service.comp = function(compId) {
        return Arachne.getComp(compId);
    };

    service.case1 = function(compId) {
        var comp = Arachne.getComp(compId);
        return Arachne.getCase(comp.case1);
    }

    service.case2 = function(compId) {
        var comp = Arachne.getComp(compId);
        return Arachne.getCase(comp.case2);
    }

    // Significant Outputs

    

    service.getOutputs = function(compId) {
        var url = '/comparison/' + compId + '/outputs.json';
        var deferred = $q.defer();

        $http.get(url).success(function(data) {
            deferred.resolve(CategorizeOutputs(data));
        }).error(function(data) {
            deferred.reject(data);
        });

        return deferred.promise;
    }


    var CategorizeOutputs = function(data) {
        var outputs = {
            bycat: {},      // List of output types by category
            bytype: {}      // List of outputs by type
        };

        for (var i = 0; i < data.length; i++) {
            var item = data[i];
            if (!outputs.bycat[item.category]) {
                outputs.bycat[item.category] = [];
            }

            if (outputs.bycat[item.category].indexOf(item.type) === -1) {
                outputs.bycat[item.category].push(item.type)
            }

            if (!outputs.bytype[item.type]) {
                outputs.bytype[item.type] = [];
            }

            outputs.bytype[item.type].push(item);
        }

        return outputs;
    };

    return service;
}]);
