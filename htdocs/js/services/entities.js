// entities.js: Entity retrieval service
//
// This service creates objects that retrieve entity data from the 
// Arachne server and make it available.
'use strict';

angular.module('arachne')
.factory('Entities', ['$http', 
                      '$q', 
function($http, $q) {
    var service = {};

    // retriever(otype, url) -- Returns an entity retriever.
    //
    // url    - The URL to retrieve the array of objects of that type.
    // keyattr - The name of the key attribute; defaults to 'id'.
    //
    // Returns an object that will retrieve and store the data of that
    // type.
    
    service.retriever = function(url, keyattr) {
        var store = []; // Array of entities of the given type.
        var index = {};

        keyattr = keyattr || 'id';

        var buildIndex = function() {
            for (var i = 0; i < store.length; i++) {
                var id = store[i][keyattr];
                index[id] = i;
            }
        };

        var retriever = {};

        retriever.refresh = function() {
            var deferred = $q.defer();

            $http.get(url).success(function(data) {
                store = data;
                buildIndex(); 
                deferred.resolve(data);
            }).error(function(data) {
                deferred.reject(data);
            });

            return deferred.promise;
        };

        retriever.all = function() {
            return store;
        };

        retriever.get = function(id) {
            if (index[id] !== undefined) {
                return store[index[id]];
            }
            return;
        };

        retriever.add = function(entity) {
            var id = entity[keyattr];
            if (index[id] === undefined) {
                store.push(entity);
                index[id] = store.length - 1;
            } else {
                store[index[id]] = entity;
            }
        };

        return retriever;
    }

    // Return the new service.
    return service;
}]);