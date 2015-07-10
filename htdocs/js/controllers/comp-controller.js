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
    this.tab        = Tab.tabber('comp');

    if (!this.tab.get()) {
        this.tab.set('political');
    }

    //-----------------------------------------------------
    // Queries


    // Simplified queries
    this.comp = function() {
        return Comp.meta(this.compId);
    }

    this.case1 = function() {
        return Comp.case1(this.compId);
    }

    this.case2 = function() {
        return Comp.case2(this.compId);
    }

    this.num = function() {
        return Comp.num(this.compId);
    }

    this.numInCat = function(cat) {
        return Comp.numInCat(this.compId, cat);
    }

    this.byCat = function(cat) {
        return Comp.byCat(this.compId, cat);
    }

    this.outputs = function() {
        return Comp.outputs(this.compId);
    }

    this.output = function(name) {
        if (this.outputs.byName && this.outputs.byName[name]) {
            return this.outputs.byName[name];
        }
    }

    //-----------------------------------------------------
    // Initialization

    Comp.retrieve(this.compId);
}]);