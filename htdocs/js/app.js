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
    var that = this;

    // Select a scenario?
    this.selectFlag = true;
    this.allowSelection = function() {
        if (arguments.length > 0) {
            this.selectFlag = arguments[0];
        }
        return this.selectFlag;
    };
    this.selectedCase = "case00";

    // Get the list of scenarios
    that.scenarios = [];

    $http.get('/scenario/index.json').success(function(data) {
      that.scenarios = data;
    });
}]);


}());  // End of Module
