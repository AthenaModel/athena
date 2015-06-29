// arachne.js: Arachne service
//
// This service retrieves toplevel data from the Arachne server, and
// also provides scenario management services.
'use strict';

angular.module('arachne')
.factory('Arachne', ['$http', function($http) {
    var me = {
        meta: {
            version: 'v?.?.?'
        }
    };

    me.version = function () {
        return this.meta.version;
    };

    //----------------
    // Data Retrieval 

    me.refresh = function() {
        me.refreshMetadata();
    };

    me.refreshMetadata = function() {
        $http.get('/meta.json').success(function(data) {
            me.meta = data;
        });
    };

    //------------------------
    // Dynamic Initialization
    me.refresh();

    return me;
}]);