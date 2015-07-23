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

    $scope.tab      = Tab.tabber('comp');
    this.categories = Comparison.categories;
    this.catname    = Comparison.catname;
    $scope.comp     = Comparison.wrapper(this.compId);

    //-----------------------------------------------------
    // Chain Display

    this.chain = '';

    this.setChain = function(varname) {
        this.chain = varname;
        $scope.tab.set('chain');
    }

    //-----------------------------------------------------
    // Initialization

    if (!$scope.tab.get()) {
        $scope.tab.set('political');
    }
}]);