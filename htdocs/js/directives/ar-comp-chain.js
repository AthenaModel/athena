angular.module("arachne")
.directive("arCompChain", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-comp-chain.html",
        scope: {
            page:     "=page",
            header:   "@",
            compid:   "@"
        },
        controller: ['$scope', 'Comparison', function($scope, Comparison) {
            // Significance level
            this.siglevel = 20;

            this.levels = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 
                            50, 45, 40, 35, 30, 25, 20, 15, 10,  5, 0];
            
            $scope.header = $scope.header || "Chain: " + $scope.page.chain;


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
        }],
        controllerAs: 'comp'
    };
});