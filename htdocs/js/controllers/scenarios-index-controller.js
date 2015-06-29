// slist-controller.js
'use strict';

angular.module('arachne')
.controller('ScenariosIndexController', ['$http', function($http) {
    var controller = this;   // For use in callbacks

    // Status Record: data from JSON requests that return status.
    this.status = {
        op:      '',     // Last operation we did.
        data:    [],     // Raw JSON data
        code:    'OK',   // Status Code
        message: '',     // Error message
        errors:  {},     // Parameter Errors by parameter name
        stack:   ''      // Tcl Stack Trace
    };

    // Context Data
    this.scenarios = []; // List of loaded scenarios
    this.files = [];     // List of available scenario files

    // User Variables
    this.selectedCase = '';   // Case ID selected in case list, or ''
    this.selectedFile = '';   // File name selected in file list, or ''
    this.replacing    = '';   // Case to replace on new, clone, import
    this.newLongname  = '';   // Long name for new case


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
        this.exportFilename = '';
    };

    // Set status
    this.setStatus = function(op, data) {
        this.status.op         = op;
        this.status.data       = data;
        this.status.code       = data[0];
        this.status.message    = '';
        this.status.errors     = null;
        this.status.stackTrace = '';

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
            case 'EXCEPTION':
                this.status.message = data[1];
                this.status.stackTrace = data[2];
            default:
                this.status.code = 'ERROR';
                this.status.message = "Unexpected response: " + data;
                break;
        } 

        this.resetQuery();
    };

    this.jsonData = function(op) {
        if (op === this.status.op && this.status.data !== '') {
            return this.status.data;
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


    // Exporting a scenario.
    this.canExport = function () {
        return this.selectedCase !== '' && this.exportFilename !== '';
    };

    this.opExport = function() {
        var url    = "/scenario/export.json";
        var params = {
            params: {
                case: this.selectedCase,
                filename: this.exportFilename
            }
        };

        $http.get(url, params).success(function(data) {
            var caseid = controller.selectedCase;
            var filename = controller.exportFilename

            controller.retrieveFiles();
            controller.setStatus('export',data);
            if (data[0] === 'OK') {
                controller.status.message = 
                    'Exported scenario: "' + caseid + '" as "' +
                    filename + '".';
            }
        }).error(function() {
            controller.setStatus('export', ['error','Could not retrieve data']);
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
    this.canClone = function () {
        return this.selectedCase !== '';
    };

    this.opClone = function() {
        this.createScenario('clone', {
            source:   this.selectedCase,
            target:   this.replacing,
            longname: this.newLongname
        });
    };

    // Removing a scenario.
    this.canRemove = function () {
        return this.selectedCase !== '' && this.selectedCase !== 'case00';
    };

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
