// slist-controller.js
'use strict';

angular.module('arachne')
.controller('ScenariosIndexController', 
['$scope', 'Arachne', 'Tab', function($scope, Arachne,Tab) {
    var controller = this;   // For use in callbacks

    // Delegated Functions
    this.cases = Arachne.cases;
    this.files = Arachne.files;
    this.statusData = Arachne.statusData;
    $scope.tab = Tab.tabber('scenario');

    // Model Variables
    this.selectedCase = '';   // Case ID selected in case list, or ''
    this.selectedFile = '';   // File name selected in file list, or ''
    this.replacing    = '';   // Case to replace on new, clone, import
    this.newLongname  = '';   // Long name for new case

    // Retrieve all required data
    this.retrieveAll = function () {
        this.retrieveCases();
        this.retrieveFiles();
    };

    // Getting the list of loaded cases
    this.retrieveCases = function () {
        Arachne.refreshCases().then(function() {
            if (!Arachne.gotCase(controller.selectedCase)) {
                controller.selectedCase = '';
            }
        });
    };

    // Getting the list of scenario files
    this.retrieveFiles = function () {
        Arachne.refreshFiles().then(function() {
            if (!Arachne.gotFile(controller.selectedFile)) {
                controller.selectedFile = '';
            }
        });
    };

    // Reset Query Parms
    this.resetQuery = function() {
        this.newLongname = '';
        this.replacing   = '';
        this.exportFilename = '';
    };


    // Import Scenario
    this.opImport = function() {
        Arachne.request('scen-import', '/scenario/import.json', {
            filename: this.selectedFile,
            case:     this.replacing,
            longname: this.newLongname
        }).then(function (stat) {
            if (stat.ok) {
                stat.message = 'Imported new scenario "' + stat.data[1] + '".';
                controller.retrieveCases();
            }
            controller.resetQuery();
        });
    };


    // Exporting a scenario.
    this.canExport = function () {
        return this.selectedCase !== '' && this.exportFilename !== '';
    };

    this.opExport = function() {
        Arachne.request('scen-export', '/scenario/export.json', {
                case: this.selectedCase,
                filename: this.exportFilename
        }).then(function (stat) {
            if (stat.ok) {
                stat.message = 'Exported scenario "' + 
                               controller.selectedCase + '" as "' +
                               controller.exportFilename + '".';
                controller.retrieveFiles();
            }
            controller.resetQuery();
        });
    };

    // Brand new scenario
    this.opNew = function() {
        Arachne.request('scen-new', '/scenario/new.json', {
            case:     this.replacing,
            longname: this.newLongname
        }).then(function (stat) {
            if (stat.ok) {
                stat.message = 'Created new scenario "' + stat.data[1] + '".'
                controller.retrieveCases();
            }
            controller.resetQuery();
        });
    }

    // Cloning a scenario.
    this.canClone = function () {
        return this.selectedCase !== '';
    };

    this.opClone = function() {
        Arachne.request('scen-clone', '/scenario/clone.json', {
            source:   this.selectedCase,
            target:   this.replacing,
            longname: this.newLongname
        }).then(function (stat) {
            if (stat.ok) {
                stat.message = 'Cloned new scenario "' + stat.data[1] + '".'
                controller.retrieveCases();
            }
            controller.resetQuery();
        });
    };

    // Removing a scenario.
    this.canRemove = function () {
        return this.selectedCase !== '' && this.selectedCase !== 'case00';
    };

    this.opRemove = function() {
        Arachne.request('scen-remove', '/scenario/remove.json', {
            case: this.selectedCase
        }).then(function (stat) {
            if (stat.ok) {
                stat.message = 'Removed scenario "' + 
                    controller.selectedCase + '".';
                controller.retrieveCases();
            }
            controller.resetQuery();
        });
    };

    // Initialization
    if (!$scope.tab.get()) {
        $scope.tab.set('new');
    }

    this.retrieveAll();
}]);
