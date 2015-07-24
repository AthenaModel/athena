// case-controller.js
'use strict';

angular.module('arachne')
.controller('CaseController', ['$routeParams', 
                               '$http', 
                               '$timeout', 
                               '$scope', 
                               'Arachne', 
                               'Tab',
function($routeParams, $http, $timeout, $scope, Arachne, Tab) {
	var controller = this;

    // Template URL
    this.template = function(suffix) {
        return '/templates/pages/case' + suffix;
    }

    //-----------------------------------------------------
    // Route Parameters

    // store case ID from route for use by page
    this.caseId = $routeParams.caseId;

    //-----------------------------------------------------
    // Arachne Delegates

    this.statusData = Arachne.statusData;

    //-----------------------------------------------------
    // Tab Management 

    $scope.tab = Tab.tabber(this.caseId);

    // Initialize tab service to 'manage'
    if (!$scope.tab.get()) {
        $scope.tab.set('manage');
    }

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
    // Scenario Model Parameters

    this.parmtree     = []; //Complete heirarchy of parms
    this.parms        = []; //Only parms with actual values
    this.currparm     = "";
    this.show         = 'all';

    this.refreshParms = function () {
        var url = '/scenario/' + this.caseId + '/parmdb.json';

        $http.get(url).success(function(data) {
            controller.parmtree     = data;
            controller.parms        = [];
            for (var i=0 ; i < data.length ; i++) {
                // Store parms and flag changed parms
                if (data[i].value) {
                    if (data[i].value !== data[i].default) {
                        data[i].changed = true;
                    }
                    controller.parms.push(data[i]);
                }
            }
        });
    }

    //-----------------------------------------------------
    // Model Parameter Operations

    this.parmField  = '';
    this.parmError  = '';

    this.opSetParm = function () {
        // FIRST, reset errmsg
        this.parmError = '';

        // NEXT, if no parm or no entry, done.
        if (!this.currparm || !this.parmField) {
            return;
        }

        var url = '/scenario/' + this.caseId + '/order.json';
        var qparms = {order_: 'PARM:SET', 
                      parm:   this.currparm, 
                      value:  this.parmField};

        Arachne.request('', url, qparms).then(function (stat) {
            if (stat.ok) {
                controller.refreshParms();
            } else {
                controller.parmError = stat.errors.value;
            }
        });        

        this.parmField = '';
    }

    this.opResetParms = function () {
        // FIRST, reset error message
        this.parmError = '';

        var url = '/scenario/' + this.caseId + '/order.json';

        Arachne.request('', url, {
            order_: 'PARM:RESET'
        }).then(function (stat) {
            if (stat.ok) {
                controller.refreshParms();
            }
        });  

        this.parmField = '';
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
        })
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

    // Model Variables
    this.weeksToAdvance = '1';

    // Lock Scenario
    this.opLock = function() {
        var url = "/scenario/" + this.caseId + "/lock.json";

        Arachne.request('case-manage', url, {}).then(function(stat) {
            if (stat.ok) {
                stat.message = 'Locked scenario.';
                controller.refreshMetadata();
            }
        });
    };

    // Unlock Scenario
    this.opUnlock = function() {
        var url = "/scenario/" + this.caseId + "/unlock.json";

        Arachne.request('case-manage', url, {}).then(function(stat) {
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
        }).then(function (stat) {
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
    this.refreshParms();
}]);