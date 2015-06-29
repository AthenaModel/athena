// scenops-controller.js
'use strict';

angular.module('arachne')
.controller('ScenarioOpsController', ['LastTab', function(LastTab) {
	// Tab control 
	// Initialize last tab service to 'new'
	if (!LastTab.get('scenario')) {
		// This registers this set of tabs with the service
		LastTab.set('scenario', 'new');
	}

    this.setTab = function(which) {
    	LastTab.set('scenario', which);
    };

    this.isSet = function(tab) {
        return LastTab.get('scenario') === tab;
    };
}]);
