// comp-controller.js
'use strict';

angular.module('arachne')
.controller('CompController', 
['$routeParams', '$scope', 'Comp', function($routeParams, $scope, Comp) {
	var controller = this;

    //-----------------------------------------------------
    // Route Parameters

    // store comp ID from route for use by page
    this.compId = $routeParams.compId;
    $scope.compId = this.compId;

    //-----------------------------------------------------
    // Lookup Tables

    var catNames = {
        political:      "Political",
        military:       "Military",
        economic:       "Economic",
        social:         "Social",
        information:    "Information",
        infrastructure: "Infrastructure"
    };

    //-----------------------------------------------------
    // Queries

    this.comp = function() {
        Comp.comp(this.compId);
    }

    this.case1 = function() {
        Comp.case1(this.compId);
    }

    this.case2 = function() {
        Comp.case2(this.compId);
    }

    this.categories = function() {
        return Object.keys(catNames);
    }

    this.categoryName = function(category) {
        return catNames[category];
    }

    //-----------------------------------------------------
    // Initialization

    this.comp  = Comp.comp(this.compId);
    this.case1 = Comp.case1(this.compId);
    this.case2 = Comp.case2(this.compId);
    this.outputs = {};

    Comp.getOutputs(this.compId).then(function(data) {
        controller.outputs = data;
    });

}]);