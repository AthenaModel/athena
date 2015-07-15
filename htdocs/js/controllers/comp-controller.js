// comp-controller.js
'use strict';

angular.module('arachne')
.controller('CompController', 
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
    $scope.comp     = {};

    //-----------------------------------------------------
    // Initialization

    // TBD: If comp were a dynamic object, calling back into
    // the service for everything and caching nothing but the compId,
    // we wouldn't need to do this.  Fix it!
    Comparison.refresh().then(function() {
        $scope.comp = Comparison.retrieve(controller.compId);
    });

    if (!$scope.tab.get()) {
        $scope.tab.set('political');
    }
}]);