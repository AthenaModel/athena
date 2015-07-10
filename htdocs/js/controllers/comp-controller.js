// comp-controller.js
'use strict';

angular.module('arachne')
.controller('CompController', 
['$routeParams', '$scope', 'Comp', 'Tab',
function($routeParams, $scope, Comp, Tab) {
	var controller = this;

    //-----------------------------------------------------
    // Route Parameters

    // store comp ID from route for use by page
    this.compId = $routeParams.compId;
    $scope.compId = this.compId;

    //-----------------------------------------------------
    // Delegated Methods

    this.categories = Comp.categories;
    this.catname    = Comp.catname;
    $scope.tab        = Tab.tabber('comp');
    $scope.comp       = Comp.comparison(this.compId);

    //-----------------------------------------------------
    // Initialization

    if (!$scope.tab.get()) {
        $scope.tab.set('political');
    }
}]);