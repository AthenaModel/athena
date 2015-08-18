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

    service.refreshMeta = function (caseId) {
        meta = [];

        var url = '/scenario/' + caseId + '/history/meta.json';
        $http.get(url).success(function(data) {
            meta = data;
        });
    };

    service.getMeta = function() {
        return meta;
    }

    // Return the new service.
    return service;
}]);