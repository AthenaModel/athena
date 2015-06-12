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

// TBD: This should be its own module.
app.controller('ScenarioListController', ['$http', function($http) {
    var that = this;

    // Get the list of scenarios
    this.status = {
        op: "",
        ok: true,
        message: ""
    };
    this.scenarios = [];
    this.selectedCase = ''

    // Functions

    // Getting the list of scenarios
    this.retrieveAll = function () {
        $http.get('/scenario/index.json').success(function(data) {
            that.scenarios = data;
            if (!that.gotCase(that.selectedCase)) {
                that.selectedCase = '';
            }
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
        }

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

    this.gotCase = function(caseid) {
        var scen;
        for (scen in this.scenarios) {
            if (scen.name === caseid) {
                return true;
            }
        }
        return false;
    };

    // Brand new scenario
    this.opNew = function() {
        this.createScenario('new', {
            case:     this.replacing,
            longname: this.newLongname
        });
    };

    // Cloning a scenario.
    this.opClone = function() {
        this.createScenario('clone', {
            source:   this.selectedCase,
            target:   this.replacing,
            longname: this.newLongname
        });
    };

    // Removing a scenario.
    this.opRemove = function() {
        var url    = "/scenario/remove.json";
        var params = {
            params: {
                case: this.selectedCase
            }
        };

        $http.get(url, params).success(function(data) {
            var caseid = that.selectedCase;

            that.retrieveAll();
            that.setStatus('remove',data);
            that.status.message = 'Removed scenario: "' + caseid + '".';
        }).failure(function() {
            that.setStatus('remove', ['error','Could not retrieve data']);
        });
    };

    // Creating a scenario.
    this.createScenario = function(op, query) {
        var url    = "/scenario/" + op + ".json";
        var params = {params: query};

        $http.get(url, params).success(function(data) {
            that.retrieveAll();
            that.setStatus(op,data);
            that.status.message = 'Created new scenario "' + data[1] + '".';
        }).failure(function() {
            that.setStatus(op, ['error','Could not retrieve data']);
        });
    };

    // Initialization
    this.retrieveAll();
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
