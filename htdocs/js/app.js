// app.js
'use strict';

(function() {

var app = angular.module('arachne', [ ]);

app.controller('ArachneController', function() {
    this.version = 'v6.X.YaZ';
});

app.controller('MainTabController', function() {
    this.tab = 'home';
    this.setTab = function(which) {
        this.tab = which;
    };
    this.isSet = function(tab) {
        return this.tab === tab;
    };
});

app.controller('ScenarioListController', ['$http', function($http) {
    var my = this;
    my.scenarios = [];

    $http.get('/scenario/index.json').success(function(data) {
      my.scenarios = data;
    });
}]);


}());  // End of Module
