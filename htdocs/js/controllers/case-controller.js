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
        Arachne.clearRequest();
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
    // Scenario Model Parameters

    this.allparms = []; //Complete heirarchy of parms
    this.parms    = []; //Only parms with actual values
    this.cparm    = "";

    this.getParms = function () {
        var url = '/scenario/' + this.caseId + '/parmdb.json';

        $http.get(url).success(function(data) {
            controller.allparms = [];
            controller.parms    = [];
            controller.allparms = data;
            for (var i=0 ; i < data.length ; i++) {
                // Store the parms with values separately
                if (data[i].value) {
                    controller.parms.push(data[i]);
                }
            }
        });
    }

    this.setCurrParm = function(e) {
        // FIRST, if the parm was clicked again, toggle off.
        if (this.cparm === e.currentTarget.innerText) {
            this.cparm = '';
            return;
        }

        // NEXT, set is as the current parameter and find it's value
        this.cparm = e.currentTarget.innerText;
        var result = $.grep(this.parms, function(e) {
                return e.name === controller.cparm; 
            });

        // NEXT, set new parm value as current value
        this.newParmVal = result[0].value;

    }

    //-----------------------------------------------------
    // Model Parameter Operations

    this.newParmVal = '';
    this.errmsg     = '';

    this.opSetParm = function () {
        // FIRST, if no parm or no new value, done.
        if (!this.cparm || !this.newParmVal) {
            return;
        }

        console.log('Set ' + this.cparm + ' to ' + this.newParmVal);

        var url = '/scenario/' + this.caseId + '/order.json';
        var qparms = {order_: 'PARM:SET', 
                      parm:   this.cparm, 
                      value:  this.newParmVal};

        console.log('URL= ' + url + ' qparms ' + qparms);

        Arachne.request('case-parm', url, qparms)
        .then(function (stat) {
            if (stat.ok) {
                controller.getParms();
            } else {
                controller.errmsg = stat.errors;
            }
        });        

        this.newParmVal = '';
    }

    this.opResetParm = function () {
        if (!this.cparm) {
            return;
        }

        var result = $.grep(this.parms, function(e){
            return e.name === controller.cparm; 
        });

        var defval = result[0].default;

        var url = '/scenario/' + this.caseId + '/order.json';

        var qparms = {order_: 'PARM:RESET', 
                      parm:   this.cparm};

        Arachne.request('case-parm', url, qparms)
        .then(function (stat) {
            if (stat.ok) {
                controller.getParms();
            }
        });  

        console.log('Reset ' + this.cparm);

        this.newParmVal = '';
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
    this.getParms();
}]);