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
    var meta   = [];
    var svals  = [];
    var store  = [];
    var header = [];
    var data   = [];
    var labels = [];
    var series = [];

    this.template = function(suffix) {
        return '/templates/pages/case' + suffix;
    }

    //-----------------------------------------------------
    // Route Parameters

    // store case ID from route for use by page
    this.caseId  = $routeParams.caseId;
    this.varName = $routeParams.varName;

    // Query history service for meta data for this case
    meta = History.meta(controller.caseId);

    this.getKeys = function() {
        for (var i=0 ; i<meta.length ; i++) {
            if (meta[i].name === controller.varName) {
                return meta[i].keys;
            }
        }
    }

    this.getDesc = function() {
        for (var i=0 ; i<meta.length ; i++) {
            if (meta[i].name === controller.varName) {
                return meta[i].desc;
            }
        }        
    }

    this.getHist = function() {
        var keys  = [];
        var parms = new Array();

        // Extract keys for selected history variable
        for (var i=0 ; i<meta.length ; i++) {
            if (meta[i].name === controller.varName) {
                keys = meta[i].keys;
            }
        }

        // Extract selected values, there may be none
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
                controller.store = data[1]; 
            }

            controller.header = Object.keys(controller.store[0]);
            controller.labels = new Array();
            controller.series = new Array();
            controller.data   = new Array();
            var tdata = new Array();
            controller.series.push("Vert. Rel.");
            for (var i=0 ; i < controller.store.length ; i++) {
                controller.labels.push(controller.store[i].t);
                tdata.push(controller.store[i].vrel);
            }
            controller.data.push(tdata);
        });    
    }
}]);