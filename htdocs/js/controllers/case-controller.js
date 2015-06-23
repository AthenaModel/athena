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
		this.actors    = []    ; // List of actors in case
		this.nbhoods   = []    ; // List of nbhoods in case
		this.groups    = []    ; // List of groups by gtype in case

		// Model interface
		this.gtypes    = ['CIV', 'FRC', 'ORG', 'ALL'];
		this.gtype     = 'ALL';

        // store case ID from route for use by page
		this.caseId = $routeParams.caseId;

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

        // Refresh
        this.refresh = function () {
            this.getActors();
            this.getNbhoods();
            this.getGroups('ALL');
        }

		this.refresh();
	}
]);