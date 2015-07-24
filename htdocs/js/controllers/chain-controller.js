// chain-controller.js
'use strict';

angular.module('arachne')
.controller('ChainController', 
['$routeParams', '$scope', 'Comparison',
function($routeParams, $scope, Comparison) {
	var controller = this;

    //-----------------------------------------------------
    // Route Parameters

    this.caseId1 = $routeParams.caseId1;
    this.caseId2 = $routeParams.caseId2;
    this.varname = $routeParams.varname;
    this.compId = Comparison.compId(this.caseId1, this.caseId2);

    //-----------------------------------------------------
    // Delegated Methods

    this.chain  = Comparison.chainWrapper(this.compId, this.varname);

    //-----------------------------------------------------
    // Significance levels

    // Significance level
    this.siglevel = 20;

    this.levels = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 
                    50, 45, 40, 35, 30, 25, 20, 15, 10,  5, 0];
    

    //------------------------------------------------------
    // Chain Data

    this.var = function() {
        return this.chain.output(this.varname);
    }
    
    this.casename = function() {
        if (this.chain.meta()) {
            return this.chain.meta().longname;
        }
    }
    this.items = this.chain.items;

    // Given an ID, is the item with that ID visible?
    this.visible = function(id) {
        var item = this.items()[id];

        if (item.score < this.siglevel) {
            return false;
        }

        if (item.parent === null) {
            return true;
        } else {
            return this.visible(item.parent)
        }

    }

    this.visibleItems = function() {
        var items = this.items();
        var result = [];

        for (var i = 0; i < items.length; i++) {
            if (this.visible(i)) {
                result.push(items[i]);
            }
        }

        return result;
    }

    this.size = function() {
        return this.items().length;
    }

    this.visibleSize = function() {
        return this.visibleItems().length;
    }

    //-----------------------------------------------------
    // Initialization
    Comparison.requestChain(this.compId, this.varname);
}]);