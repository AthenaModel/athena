// case-controller.js
'use strict';

angular.module('arachne')
.controller('ObjectController', ['$scope', '$routeParams', '$http',
	function($scope, $routeParams, $http) {
		var controller = this;

        // Data storage
		this.data = '' ; // JSON response

        // store case ID from route for use by page
		this.caseId     = $routeParams.caseId;
		this.objectType = $routeParams.objectType;
		this.objectId   = $routeParams.objectId;

        // Data retrieval
		this.getData = function () {
			var url = '/scenario/' + this.caseId + '/' + 
			          this.objectType + '/' + this.objectId + '/index.json'
	        $http.get(url).success(function(data) {
	                controller.data = data;
	        });
        };

        this.getData() ;

	}
]);