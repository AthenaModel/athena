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

    // Get the list of scenarios
    this.status = {
        op: "",
        ok: true,
        message: ""
    };
    this.scenarios = [];

    // Functions

    // Getting the list of scenarios
    this.retrieveAll = function () {
        $http.get('/scenario/index.json').success(function(data) {
            that.scenarios = data;
        });
    };

    // Reset Query Parms
    this.resetQuery = function() {
        this.newLongname = '';
        this.replacing   = '';
    };

    // Set status
    this.setStatus = function(op, data) {
        this.status.op = op;
        this.jsonData = data;

        if (data[0] === 'OK') {
            this.status.ok = true;
            this.status.message = "Operation completed successfully.";
        } else {
            this.status.ok = false;
            this.status.message = data[1];
        };

        this.resetQuery();
    };

    // isOK: handled a particular operation successfully.
    this.isOK = function(op) {
        return op === this.status.op && this.status.ok;
    };

    this.isError = function(op) {
        return op === this.status.op && !this.status.ok;
    };

    this.gotData = function(op) {
        return op === this.status.op && this.jsonData !== '';
    };



    // Requesting a new scenario.  How do we make the
    this.newScenario = function() {
        var query = {
            case: this.replacing,
            longname: this.newLongname
        };

        $http({
            url:    "/scenario/new.json",
            method: "GET",
            params: query
        }).success(function(data) {
            that.retrieveAll();
            that.setStatus('new',data);
            that.status.message = 'Created new scenario "' + data[1] + '".';
        }).failure(function() {
            that.setStatus('new',['error','Could not retrieve data']);
        });
    };

    // Initialization
    this.retrieveAll();
    this.resetQuery();
}]);

app.controller('ScenarioOpsController', function() {
    this.tab = 'import';
    this.setTab = function(which) {
        this.tab = which;
    };
    this.isSet = function(tab) {
        return this.tab === tab;
    };
});


}());  // End of Module
