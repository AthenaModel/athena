// hist-controller.js
'use strict';

angular.module('arachne')
.controller('HistController', ['$routeParams', 
                               '$http', 
                               '$timeout', 
                               '$scope',
                               'History',
function($routeParams, $http, $timeout, $scope, History) {
	var controller = this;
    var metadata   = [];
    var svals      = [];
    var store      = [];
    var header     = [];
    var varName    = "";

    this.template = function(suffix) {
        return '/templates/pages/case' + suffix;
    }

    //-----------------------------------------------------
    // Route Parameters
    this.caseId  = $routeParams.caseId;


    //----------------------------------------------------
    // Scenario History

    History.refreshMeta(controller.caseId);
    this.varName = "";

    // Query history service for meta data for this case
    this.meta = function() {
        metadata = History.getMeta();

        // Initialize varName to first table in metadata
        if (metadata.length > 0 && controller.varName === "") {
            controller.varName = metadata[0].name
        }

        return metadata;
    }

    this.getKeys = function() {
        metadata = History.getMeta();
        for (var i=0 ; i<metadata.length ; i++) {
            if (metadata[i].name === controller.varName) {
                return metadata[i].keys;
            }
        }
    }

    this.getHist = function() {
        var keys  = [];
        var parms = new Array();

        // Extract keys for selected history variable
        for (var i=0 ; i<metadata.length ; i++) {
            if (metadata[i].name === controller.varName) {
                keys = metadata[i].keys;
            }
        }

        // Extract selected values
        if (controller.svals) {
            for (var i=0 ; i<keys.length ; i++) {
                var key = keys[i].key;
                var val = controller.svals[i];

                parms[key] = val;
            } 
        }

        // Request the data
        var url = '/scenario/' + controller.caseId + 
                  '/history/' + controller.varName + '/index.json';

        $http.get(url, {params: parms}).success(function(data) {
            if (data[0] === 'OK') {
                controller.store  = data[1]; 
                controller.header = Object.keys(controller.store[0]);
            }
        });    
    }
}]);