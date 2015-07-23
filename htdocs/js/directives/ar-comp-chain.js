angular.module("arachne")
.directive("arCompChain", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-comp-chain.html",
        scope: {
            page:     "=page",
            compid:   "@"
        },
        controller: ['$scope', 'Comparison', function($scope, Comparison) {
            var expanded = [];

            // Significance level
            this.siglevel = 20;

            this.levels = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 
                            50, 45, 40, 35, 30, 25, 20, 15, 10,  5, 0];
            
            // Chain Data
            this.items = function() {
                return Comparison.chain($scope.compid, $scope.page.chain);
            }

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

            this.output = function() {
                if ($scope.page.chain) {
                    if (saved === null || $scope.page.chain !== saved.name) {
                        saved = Comparison.output($scope.compid, $scope.page.chain);
                    }
                } else {
                    saved = null;
                }

                return saved;
            }

            //--------------------------------------------
            // Expanding items

            this.isExpanded = function(item) {
                return expanded.indexOf(item) !== -1;
            }

            this.toggleClass = function(item) {
                if (this.isExpanded(item)) {
                    return "glyphicon-triangle-bottom"
                } else {
                    return "glyphicon-triangle-right"
                }
            }


            this.toggle = function(item) {
                var ndx = expanded.indexOf(item);

                if (ndx === -1) {
                    expanded.push(item);
                } else {
                    expanded.splice(ndx,1);
                }
            }

        }],
        controllerAs: 'comp'
    };
});