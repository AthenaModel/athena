// case-controller.js
'use strict';

angular.module('arachne')
.controller('CaseController', ['$routeParams', '$http', '$timeout', 'LastTab',
function($routeParams, $http, $timeout, LastTab) {
	var controller = this;

    //-----------------------------------------------------
    // Route Parameters

    // store case ID from route for use by page
    this.caseId = $routeParams.caseId;

    //-----------------------------------------------------
    // Tab Management 

	// Tab control, initialize last tab service to 'manage'
	if (!LastTab.get(this.caseId)) {
		// This registers this set of tabs with the service
		LastTab.set(this.caseId, 'manage');
	}

    // 
    this.setTab = function(which) {
        this.clearStatus();
    	LastTab.set(this.caseId, which);
    };

    this.isSet = function(tab) {
        return LastTab.get(this.caseId) === tab;
    };

    //----------------------------------------------------
    // Scenario Metadata

    this.metadata = [];     // Scenario Metadata

    this.refreshMetadata = function () {
        $http.get('/scenario/' + this.caseId + '/index.json')
            .success(function(data) {
                var oldState = controller.metadata.state;

                controller.metadata = data;

                if (controller.isBusy()) {
                    controller.scheduleRefresh();
                } else if (oldState != controller.metadata.state) {
                    controller.refreshData();
                }
            });
    }

    this.scheduleRefresh = function() {
        $timeout(function() {
            controller.refreshMetadata();
        }, 1000);
    }

    this.isUnlocked = function () {
        return this.metadata.state === 'PREP';
    }

    this.isLocked = function () {
        return this.metadata.state !== 'PREP';
    }

    this.isBusy = function () {
        return this.metadata.state === 'BUSY' ||
               this.metadata.state === 'RUNNING';
    }

    this.stateClass = function() {
        switch(this.metadata.state) {
            case "PREP":
                return "label-info";
            case "PAUSED":
                return "label-primary";
            case "BUSY":
            case "RUNNING":
                return "label-warning";
            default:
                return "";
        }
    }

    //----------------------------------------------------
    // Scenario Objects

    // Object storage
	this.actors    = [];    // List of actors in case
    this.nbhoods   = [];    // List of nbhoods in case
	this.groups    = [];    // List of groups by gtype in case

	// Model interface
	this.gtypes    = ['CIV', 'FRC', 'ORG', 'ALL'];
	this.gtype     = 'ALL';


    // Data retrieval
	this.getActors = function () {
        $http.get('/scenario/' + this.caseId + '/actors/index.json')
            .success(function(data) {
                controller.actors = data;
        });
    };

	this.getNbhoods = function () {
        $http.get('/scenario/' + this.caseId + '/nbhoods/index.json')
            .success(function(data) {
                controller.nbhoods = data;
        });
    };

    this.getGroups = function () { 
        var url ;      	
    	switch (this.gtype) {
    		case 'ALL' :
    		    url = '/scenario/' + this.caseId + '/group/index.json' ;
		        break;
		    case 'CIV' :
		        url = '/scenario/' + this.caseId + '/group/civ.json' ;
		        break;
		    case 'FRC' :
		        url = '/scenario/' + this.caseId + '/group/frc.json' ;
		        break;
		    case 'ORG' :
		        url = '/scenario/' + this.caseId + '/group/org.json' ;
		        break;
		    default :
		        url = '/scenario/' + this.caseId + '/group/index.json' ;
		}
		
        $http.get(url).success(function(data) {
            controller.groups = data;
        });
	};

    //-------------------------------------------------------
    // Operations

    // TBD: I'd like the status record and update methods to 
    // be reusable code.

    // Status Record: data from JSON requests that return status.
    this.status = {
        op:      '',     // Last operation we did.
        data:    [],     // Raw JSON data
        code:    'OK',   // Status Code
        message: '',     // Error message
        errors:  {},     // Parameter Errors by parameter name
        stack:   ''      // Tcl Stack Trace
    };

    // Form Data
    this.weeksToAdvance = '1';

    // Reset Query Parms
    this.resetQuery = function() {
        // weeksToAdvance needn't be reset.
    };

    // Clear Status
    this.clearStatus = function() {
        this.status.op = null;
    }

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

    // Lock Scenario
    this.opLock = function() {
        var url    = "/scenario/" + this.caseId + "/lock.json";

        $http.get(url).success(function(data) {
            controller.refreshMetadata();
            controller.setStatus('case',data);
            if (data[0] === 'OK') {
                controller.status.message = 
                    'Locked scenario.';
            }
        }).error(function() {
            controller.setStatus('export', ['error','Could not retrieve data']);
        });
    };

    // Unlock Scenario
    this.opUnlock = function() {
        var url    = "/scenario/" + this.caseId + "/unlock.json";

        $http.get(url).success(function(data) {
            controller.refreshMetadata();
            controller.setStatus('case',data);
            if (data[0] === 'OK') {
                controller.status.message = 
                    'Unlocked scenario.';
            }
        }).error(function() {
            controller.setStatus('export', ['error','Could not retrieve data']);
        });
    };

    this.opAdvance = function() {
        var url    = "/scenario/" + this.caseId + "/advance.json";
        var params = {
            params: {
                weeks: this.weeksToAdvance
            }
        };

        $http.get(url, params).success(function(data) {
            controller.refreshMetadata();
            controller.setStatus('case',data);
            if (data[0] === 'OK') {
                controller.status.message = 
                    'Advancing time by ' + controller.weeksToAdvance + ' weeks.';
            }
        }).error(function() {
            controller.setStatus('export', ['error','Could not retrieve data']);
        });
    };



    //-------------------------------------------------------
    // Refresh

    this.refreshMetadata();

    this.refreshData = function () {
        this.getActors();
        this.getNbhoods();
        this.getGroups('ALL');
    }

    this.refreshMetadata();
	this.refreshData();
}]);