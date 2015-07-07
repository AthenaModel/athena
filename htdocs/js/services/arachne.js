// arachne.js: Arachne service
//
// This service retrieves toplevel data from the Arachne server, and
// also provides scenario management services.
'use strict';

angular.module('arachne')
.factory('Arachne', ['$http', '$timeout', function($http, $timeout) {
    //---------------------------------------------------------
    // Service object

    var service = {
        connectedFlag: false,     // Are we talking to the server?
        meta: {                   // Server metadata
            version: 'v?.?.?',    // Server version
            startTime: 0          // Server start time (msec)
        },
        caseRecords: [],          // Array of case records
        fileRecords: []           // Array of scenario file records
    };

    //----------------------------------------------------------
    // Data Retrieval 

    // Refresh all data.  It's usually easier to just reload the app.
    service.refresh = function() {
        service.refreshMetadata();
        service.refreshCases();
        service.refreshFiles();
    };

    //----------------------------------------------------------
    // Metadata Retrieval
    //
    // We retrieve the server metadata initially and every 
    // five seconds thereafter, to catch server halts and updates.

    service.refreshMetadata = function() {
        $http.get('/meta.json').success(function(data) {
            // TBD: If the startTime has changed, we might want to
            // emit a notification event.
            service.connectedFlag = true;
            service.meta = data;
            service.scheduleRefreshMetadata();
        }).error(function() {
            service.connectedFlag = false;
            service.scheduleRefreshMetadata();
        });
    };

    service.scheduleRefreshMetadata = function() {
        $timeout(function() {
            service.refreshMetadata();
        }, 5000);
    };

    //----------------------------------------------------------
    // Case Records

    service.cases = function() {
        return service.caseRecords;
    }

    service.refreshCases = function(callback) {
        $http.get('/scenario/index.json').success(function(data) {
            service.caseRecords = data;

            if (callback) {
                callback();
            }
        });
    };

    service.gotCase = function(caseid) {
        for (var i = 0; i < service.caseRecords.length; i++) {
            if (service.caseRecords[i].name === caseid) {
                return true;
            }
        }
        return false;
    };


    //----------------------------------------------------------
    // Scenario File Records

    service.files = function() {
        return service.fileRecords;
    }

    service.refreshFiles = function (callback) {
        $http.get('/scenario/files.json').success(function(data) {
            service.fileRecords = data;

            if (callback) {
                callback();
            }
        });
    };

    service.gotFile = function(filename) {
        for (var i = 0; i < service.fileRecords.length; i++) {
            if (service.fileRecords[i].name === filename) {
                return true;
            }
        }
        return false;
    };

    //----------------------------------------------------------
    // Service Queries
    
    service.connected = function() {
        return service.connectedFlag;
    }
    service.version = function () {
        return service.meta.version;
    };

    service.startTime = function () {
        return service.meta.startTime;
    };

    service.files = function() {
        return service.fileRecords;
    }

    service.cases = function() {
        return service.caseRecords;
    }

    //------------------------
    // Dynamic Initialization
    service.refresh();

    // Return the new service.
    return service;
}]);