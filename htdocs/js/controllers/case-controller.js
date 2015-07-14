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

    // Initialize last tab service to 'manage'
    if (!$scope.tab.get()) {
        $scope.tab.set('manage');
    }

    this.isGroups = function(tab) {
        return Tab.get(this.caseId).indexOf('groups') != -1;
    };

    this.isParms = function(tab) {
        return Tab.get(this.caseId).indexOf('parms') != -1;
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
    this.changedparms = []; //Only parms that have changed
    this.currparm     = "";

    this.refreshParms = function () {
        var url = '/scenario/' + this.caseId + '/parmdb.json';

        $http.get(url).success(function(data) {
            controller.parmtree     = data;
            controller.parms        = [];
            controller.changedparms = [];
            for (var i=0 ; i < data.length ; i++) {
                // Store parms and non-default parms separately
                if (data[i].value) {
                    controller.parms.push(data[i]);
                    if (data[i].value !== data[i].default) {
                        controller.changedparms.push(data[i]);
                    }
                }
            }
        });
    }

    this.setCurrParm = function(e) {
        // FIRST, clear any error message that may be there
        this.parmError = '';

        // NEXT, if the parm was clicked again, toggle off.
        if (this.currparm === e.currentTarget.innerText) {
            this.currparm = '';
            return;
        }

        // NEXT, set is as the current parameter and find it's value
        this.currparm = e.currentTarget.innerText;
        var result = $.grep(this.parms, function(e) {
                return e.name === controller.currparm; 
            });

        // NEXT, set parm field as current value
        this.parmField = result[0].value;

    }

    this.getParms = function() {
        if ($scope.tab.isSet('changedparms')) {
            return controller.changedparms;
        }

        return controller.parms;
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

        Arachne.request('', url, qparms)
        .then(function (stat) {
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
        var qparms = {order_: 'PARM:RESET'};

        Arachne.request('', url, qparms)
        .then(function (stat) {
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