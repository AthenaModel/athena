// comparison-controller.js
'use strict';

angular.module('arachne')
.controller('ComparisonController', 
['$routeParams', '$scope', 'Comparison', 'Tab',
function($routeParams, $scope, Comparison, Tab) {
	var controller = this;

    //-----------------------------------------------------
    // Route Parameters

    this.caseId1 = $routeParams.caseId1;
    this.caseId2 = $routeParams.caseId2;
    this.compId = Comparison.compId(this.caseId1, this.caseId2);
    $scope.compId = this.compId;

    //-----------------------------------------------------
    // Delegated Methods

    $scope.tab  = Tab.tabber('comp');
    var comp = Comparison.wrapper(this.compId);

    this.meta = comp.meta;
    this.case1 = comp.case1;
    this.case2 = comp.case2;

    //-----------------------------------------------------
    // Significance Levels

    this.siglevel = 20;

    this.levels = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 
                    50, 45, 40, 35, 30, 25, 20, 15, 10,  5, 0];
            

    //-----------------------------------------------------
    // Categories

    this.cat = $scope.tab.get;

    this.categories = comp.categories;

    this.catName = function(category) {
        var category = category || this.cat();
        return comp.catName(category);
    }

    this.catSize = function(category) {
        var category = category || this.cat();
        return comp.catSize(category);
    }

    //-----------------------------------------------------
    // Outputs and Significant Outputs

    this.outputs = function() {
        return comp.byCat(this.cat());
    }

    this.sigOutputs = function() {
        var outputs = this.outputs();
        var result = [];

        for (var i = 0; i < outputs.length; i++) {
            if (outputs[i].score >= this.siglevel) {
                result.push(outputs[i]);
            }
        }

        return result;
    }

    this.sigSize = function() {
        return this.sigOutputs().length;
    }

    //-----------------------------------------------------
    // Sorting

    this.sortby = function(column) {
        $scope.sortby = column;
        $scope.reverse = (column === 'score');
    }

    this.sortby('score')



    //-----------------------------------------------------
    // Initialization

    if (!$scope.tab.get()) {
        $scope.tab.set('political');
    }
}]);