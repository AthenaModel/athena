// slist-controller.js
'use strict';

angular.module('arachne')
.controller('ScenarioListController', ['$http', function($http) {
    var controller = this;

    // Get the list of scenarios
    this.status = {
        op:      '',
        code:    'OK',
        message: '',     // Error message
        errors:  {}      // Parameter Errors
    };
    this.scenarios = [];
    this.selectedCase = '';

    this.files = [];
    this.selectedFile = '';


    // Functions

    // Retrieve all required data
    this.retrieveAll = function () {
        this.retrieveCases();
        this.retrieveFiles();
    };

    // Getting the list of loaded cases
    this.retrieveCases = function () {
        $http.get('/scenario/index.json').success(function(data) {
            controller.scenarios = data;
            if (!controller.gotCase(controller.selectedCase)) {
                controller.selectedCase = '';
            }
        });
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



    // Getting the list of scenario files
    this.retrieveFiles = function () {
        $http.get('/scenario/files.json').success(function(data) {
            controller.files = data;
            if (!controller.gotFile(controller.selectedFile)) {
                controller.selectedFile = '';
            }
        });
    };

    this.gotFile = function(filename) {
        var file;
        for (file in this.files) {
            if (file.name === filename) {
                return true;
            }
        }
        return false;
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

        this.status.code = data[0];
        this.status.message = '';
        this.status.errors = null;

        // TBD: Handle all four cases, with stack trace on EXCEPTION
        switch(this.status.code) {
            case 'OK':
                this.status.message = "Operation completed successfully.";
                break;
            case 'REJECT':
                this.status.errors = data[1];
                break;
            case 'ERROR':
                this.status.message = data[1];
                break;
            default:
                this.status.message = "Unexpected response: " + data;
                break;
        } 

        this.resetQuery();
    };

    // isOK: handled a particular operation successfully.
    this.isOK = function(op) {
        return op === this.status.op && this.status.code === 'OK';
    };

    this.isRejected = function(op) {
        return op === this.status.op && this.status.code === 'REJECT';
    };

    this.isError = function(op) {
        return op === this.status.op 
            && this.status.code !== 'OK' 
            && this.status.code !== 'REJECT';
    };

    this.gotData = function(op) {
        return op === this.status.op && this.jsonData !== '';
    };

    this.getData = function(op) {
        if (op === this.status.op && this.jsonData !== '') {
            return this.jsonData;
        } else {
            return null;
        }
    };

    // Import Scenario
    this.opImport = function() {
        this.createScenario('import', {
            filename: this.selectedFile,
            case:     this.replacing,
            longname: this.newLongname
        });
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
            var caseid = controller.selectedCase;

            controller.retrieveCases();
            controller.setStatus('remove',data);
            if (data[0] === 'OK') {
                controller.status.message = 'Removed scenario: "' + caseid + '".';
            }
        }).error(function() {
            controller.setStatus('remove', ['error','Could not retrieve data']);
        });
    };

    // Creating a scenario.
    this.createScenario = function(op, query) {
        var url    = "/scenario/" + op + ".json";
        var params = {params: query};

        $http.get(url, params).success(function(data) {
            controller.retrieveCases();
            controller.setStatus(op,data);
            if (data[0] === 'OK') {
                controller.status.message = 'Created new scenario "' + data[1] + '".';
            }
        }).error(function() {
            controller.setStatus(op, ['error','Could not retrieve data']);
        });
    };

    // Initialization
    this.retrieveAll();
}]);
