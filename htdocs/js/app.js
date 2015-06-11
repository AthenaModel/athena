// app.js
'use strict';

(function() {

var app = angular.module('arachne', [ ]);

app.controller('ArachneController', function() {
    this.version = 'v6.X.YaZ';
});

app.controller('ScenarioListController', ['$http', function($http) {
    var my = this;
    my.scenarios = [];

    $http.get('/scenario/index.json').success(function(data) {
      my.scenarios = data;
    });
}]);


}());  // End of Module
