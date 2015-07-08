// arachne.js: Arachne service
//
// This service retrieves toplevel data from the Arachne server, and
// also provides scenario management services.
'use strict';

angular.module('arachne')
.factory('Arachne', ['$http', '$timeout', '$q', function($http, $timeout, $q) {
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

    service.refreshCases = function() {
        var deferred = $q.defer();

        $http.get('/scenario/index.json').success(function(data) {
            service.caseRecords = data;
            deferred.resolve(data);
        }).error(function(data) {
            deferred.reject(data);
        });

        return deferred.promise;
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

    // refreshFiles()
    //
    // Refreshes the list of scenario files; returns a promise to be
    // called when (and if) the list is updated.
    service.refreshFiles = function () {
        var deferred = $q.defer();

        $http.get('/scenario/files.json').success(function(data) {
            service.fileRecords = data;
            deferred.resolve(data);
        }).error(function(data) {
            deferred.reject(data);
        });

        return deferred.promise;
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
    // Requests
    //
    // This submodule allows the client to send requests to the
    // server, getting the standard OK/ERROR/REJECTED protocol back.

    // Status Record: data from JSON requests that return status.
    service.statusRecord = {
        tag:     '',     // The last operation's tag.
        data:    [],     // Raw JSON data coming back from the request.
        code:    'OK',   // Status Code
        result:  [],     // OK Result: array, data[1] to end.
        message: '',     // Error message
        errors:  {},     // Parameter Errors by parameter name
        stack:   '',     // Tcl Stack Trace,
        ok:      false
    };

    service.request = function(tag, url, query) {
        var deferred = $q.defer();
        var params = { params: query };

        $http.get(url,params).success(function(data) {
            service.setStatus(tag, data);
            deferred.resolve(service.statusRecord);
        }).error(function() {
            service.setStatus(tag, ['error','Could not retrieve data']);
            deferred.resolve(service.statusRecord);
        });

        return deferred.promise;
    };

    service.clearRequest = function() {
        service.statusRecord.tag = '';
    };

    service.setStatus = function(tag, data) {
        var stat = service.statusRecord;

        stat.tag        = tag;
        stat.data       = data;
        stat.result     = data.slice(1);
        stat.code       = data[0];
        stat.ok         = false;
        stat.message    = '';
        stat.errors     = null;
        stat.stackTrace = '';

        switch(stat.code) {
            case 'OK':
                stat.message = "Operation completed successfully.";
                stat.ok = true;
                break;
            case 'REJECT':
                stat.errors = data[1];
                break;
            case 'ERROR':
                stat.message = data[1];
                break;
            case 'EXCEPTION':
                stat.message = data[1];
                stat.stackTrace = data[2];
            default:
                stat.code = 'ERROR';
                stat.message = "Unexpected response: " + data;
                break;
        } 

    }


    //----------------------------------------------------------
    // Service Queries
    
    service.connected = function() {
        return service.connectedFlag;
    };

    service.status = function() {
        return service.statusRecord;
    };

    service.statusData = function(tag) {
        var stat = service.statusRecord;

        if (tag == stat.tag && stat.data) {
            return stat.data;
        } else {
            return null;
        }
    };


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