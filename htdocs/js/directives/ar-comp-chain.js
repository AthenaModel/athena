angular.module("arachne")
.directive("arCompChain", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-comp-chain.html",
        scope: {
            header:   "@",
            compid:   "@",
            varname:  "@"
        },
        controller: ['$scope', 'Comparison', function($scope, Comparison) {
            // Significance level
            this.siglevel = 20;

            this.levels = [100, 95, 90, 85, 80, 75, 70, 65, 60, 55, 
                            50, 45, 40, 35, 30, 25, 20, 15, 10,  5, 0];
            
            $scope.header = $scope.header || "Chain: " + $scope.varname;

            Comparison.requestChain($scope.compid, $scope.varname);

            // Significant outputs
            this.varnames = function() {
                return Comparison.outputNames($scope.compid);                
            }

            this.varname = $scope.varname || this.varnames()[0];

            // Chain Data

            this.items = function() {
                return Comparison.chain($scope.compid, $scope.varname);
            }

            this.sigItems = function() {
                return this.items();
            }

            this.size = function() {
                return this.items().length;
            }

            this.sigSize = function() {
                return this.sigItems().length;
            }
        }],
        controllerAs: 'comp'
    };
});