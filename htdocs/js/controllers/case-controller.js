// case-controller.js
'use strict';

angular.module('arachne')
.controller('CaseController', ['$routeParams', '$http', 'LastTab',
	function(routeParams, http, LastTab) {
		var controller = this;

        // store case ID from route for use by page
		this.caseId = routeParams.caseId;

		// Tab control, initialize last tab service to 'actors'
		if (!LastTab.get(this.caseId)) {
			// This registers this set of tabs with the service
			LastTab.set(this.caseId, 'actors');
		}

        // 
	    this.setTab = function(which) {
	    	LastTab.set(this.caseId, which);
	    };

	    this.isSet = function(tab) {
	        return LastTab.get(this.caseId) === tab;
	    };

        // Object storage
		this.actors    = []    ; // List of actors in case
		this.nbhoods   = []    ; // List of nbhoods in case
		this.groups    = []    ; // List of groups by gtype in case

		// Model interface
		this.gtypes    = ['CIV', 'FRC', 'ORG', 'ALL'];
		this.gtype     = 'ALL';


        // Data retrieval
		this.getActors = function () {
	        http.get('/scenario/' + this.caseId + '/actors/index.json')
	            .success(function(data) {
	                controller.actors = data;
	        });
        };

		this.getNbhoods = function () {
	        http.get('/scenario/' + this.caseId + '/nbhoods/index.json')
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
			
	        http.get(url).success(function(data) {
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