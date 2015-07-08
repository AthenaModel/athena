// arachne.js: Arachne service
//
// This service retrieves toplevel data from the Arachne server, and
// also provides scenario management services.
'use strict';

angular.module('arachne')
.factory('Arachne', ['$http', '$timeout', '$q', function($http, $timeout, $q) {
    //---------------------------------------------------------
    // Service Data

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
        service.refreshAllObjects();
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
    // Object Store

    var objectUrls = {
        cases: '/scenario/index.json',
        comps: '/comparison/index.json',
        files: '/scenario/files.json'
    };

    var store = {}; // Store of lists of objects retrieved from the
                        // server.

    service.refreshObjects = function(otype) {
        var url = objectUrls[otype];
        var deferred = $q.defer();

        if (!store[otype]) {
            store[otype] = []
        }

        $http.get(url).success(function(data) {
            store[otype] = data;
            deferred.resolve(data);
        }).error(function(data) {
            deferred.reject(data);
        });

        return deferred.promise;
    };

    service.refreshAllObjects = function() {
        for (var otype in objectUrls) {
            service.refreshObjects(otype);
        }
    }

    service.gotObject = function(otype,id) {
        var objects = store[otype];

        for (var i = 0; i < objects.length; i++) {
            if (objects[i].id === id) {
                return true;
            }
        }
        return false;
    }

    service.get = function(otype,id) {
        var objects = store[otype];

        for (var i = 0; i < objects.length; i++) {
            if (objects[i].id === id) {
                return objects[i];
            }
        }
        return null;
    }

    //----------------------------------------------------------
    // Case Records

    service.refreshCases = function() {
        return service.refreshObjects('cases');
    };

    service.gotCase = function(caseid) {
        return service.gotObject('cases',caseid);
    };

    service.getCase = function(caseid) {
        return service.get('cases',caseid);
    }


    //----------------------------------------------------------
    // Comparison Records

    service.refreshComps = function() {
        return service.refreshObjects('comps');
    };

    service.gotComp = function(compid) {
        return service.gotObject('comps',compid);
    };

    //----------------------------------------------------------
    // Scenario File Records

    service.refreshFiles = function() {
        return service.refreshObjects('files');
    };

    service.gotFile = function(filename) {
        return service.gotObject('files',filename);
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

    service.cases = function() {
        return store['cases'];
    }

    service.comps = function() {
        return store['comps'];
    }

    service.files = function() {
        return store['files'];
    }

    //------------------------
    // Dynamic Initialization
    service.refresh();

    // Return the new service.
    return service;
}]);