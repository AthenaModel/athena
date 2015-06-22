// case-controller.js
'use strict';

angular.module('arachne')
.controller('CaseController', ['$scope', '$routeParams', '$http',
	function($scope, $routeParams, $http) {
		var controller = this;

		// Tab control
	    this.tab = 'actors';
	    this.setTab = function(which) {
	        this.tab = which;
	    };
	    this.isSet = function(tab) {
	        return this.tab === tab;
	    };

        // Object storage
		this.actors    = [] ;
		this.nbhoods   = [] ;

        // store case ID from route for use by page
		$scope.caseId = $routeParams.caseId;

        // Data retrieval
		this.retrieveActors = function () {
	        $http.get('/scenario/' + $scope.caseId + '/actors/index.json')
	            .success(function(data) {
	                controller.actors = data;
	        });
        };

		this.retrieveNbhoods = function () {
	        $http.get('/scenario/' + $scope.caseId + '/nbhoods/index.json')
	            .success(function(data) {
	                controller.nbhoods = data;
	        });
        };

        // Refresh
        this.refresh = function () {
            this.retrieveActors();
            this.retrieveNbhoods();
        }

		this.refresh();
	}
]);