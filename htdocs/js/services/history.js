// entities.js: Entity retrieval service
//
// This service creates objects that retrieve entity data from the 
// Arachne server and make it available.
'use strict';

angular.module('arachne')
.factory('History', ['$http', 
                      '$q', 
function($http, $q) {
    var service = {};

    var meta  = []; // History meta data
    var keys  = [];
    var desc  = [];

    service.refreshMeta = function (caseId) {
        var deferred = $q.defer();
        meta = [];

        var url = '/scenario/' + caseId + '/history/meta.json';
        $http.get(url).success(function(data) {
            for (var i=0 ; i<data.length ; i++) {
                if (data[i].size) {
                    meta.push(data[i]);
                    continue;
                }
            }
            deferred.resolve(data); 
        }).error(function(data) {
            deferred.reject(data);
        });
    };

    service.getkeys = function(histvar) {
        for (var i=0; i<meta.length ; i++) {
            if (meta[i].name === histvar) {
                return meta[i].keys;
            }
        }
    };

    service.getDesc = function(histvar) {
        for (var i=0; i<meta.length ; i++) {
            if (meta[i].name === histvar) {
                return meta[i].desc;
            }
        }        
    }

    service.meta = function(caseId) {
        service.refreshMeta(caseId);
        return meta;
    };

    // Return the new service.
    return service;
}]);