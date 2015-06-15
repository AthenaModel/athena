// arachne-controller.js
'use strict';

angular.module('arachne')
.controller('ArachneController', ['$http', function($http) {
    var controller = this;
    this.meta = {
        version: 'v6.X.YaZ'
    };

    // Functions
    this.version = function() {
        return this.meta.version;
    };

    // Retrieve metadata
    $http.get('/meta.json').success(function(data) {
        controller.meta = data;
    });
}]);

