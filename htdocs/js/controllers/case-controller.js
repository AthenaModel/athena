// case-controller.js
'use strict';

angular.module('arachne')
.controller('CaseController', ['$routeParams', '$http', '$timeout', 'Arachne', 'LastTab',
function($routeParams, $http, $timeout, Arachne, LastTab) {
	var controller = this;

    //-----------------------------------------------------
    // Route Parameters

    // store case ID from route for use by page
    this.caseId = $routeParams.caseId;

    //-----------------------------------------------------
    // Arachne Delegates

    this.statusData = Arachne.statusData;


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

    this.isGroups = function(tab) {
        return LastTab.get(this.caseId).indexOf('groups') != -1;
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
                    controller.refreshAllObjects();
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
    this.objectSuffix = {
        actors:    '/actors/index.json',
        nbhoods:   '/nbhoods/index.json',
        groups:    '/group/index.json',
        civgroups: '/group/civ.json',
        frcgroups: '/group/frc.json',
        orggroups: '/group/org.json'
    };

    this.objectData = {
    };

    this.refreshObjects = function(otype) {
        var url = '/scenario/' + this.caseId + 
                  this.objectSuffix[otype];

        if (!this.objectData[otype]) {
            this.objectData[otype] == []
        }

        $http.get(url).success(function(data) {
            controller.objectData[otype] = data;
        });
    };

    this.objects = function (otype) {
        return controller.objectData[otype];
    };

    this.refreshAllObjects = function () {
        for (var otype in this.objectSuffix) {
            this.refreshObjects(otype);
        }
    }

    //-------------------------------------------------------
    // Operations

    // Form Data
    this.weeksToAdvance = '1';

    // Lock Scenario
    this.opLock = function() {
        var url = "/scenario/" + this.caseId + "/lock.json";

        Arachne.request('case-manage', url, {}, function (stat) {
            if (stat.ok) {
                stat.message = 'Locked scenario.';
                controller.refreshMetadata();
            }
        });
    };

    // Unlock Scenario
    this.opUnlock = function() {
        var url = "/scenario/" + this.caseId + "/unlock.json";

        Arachne.request('case-manage', url, {}, function (stat) {
            if (stat.ok) {
                stat.message = 'Unlocked scenario.';
                controller.refreshMetadata();
            }
        });
    };

    this.opAdvance = function() {
        var url    = "/scenario/" + this.caseId + "/advance.json";


        Arachne.request('case-manage', url, {
            weeks: this.weeksToAdvance
        }, function (stat) {
            if (stat.ok) {
                stat.message = 'Advancing time by ' + 
                    controller.weeksToAdvance + ' weeks.';
                controller.refreshMetadata();
            }
        });
    };



    //-------------------------------------------------------
    // Refresh

    this.refreshMetadata();
}]);