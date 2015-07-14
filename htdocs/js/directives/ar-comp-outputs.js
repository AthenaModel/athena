angular.module("arachne")
.directive("arCompOutputs", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-comp-outputs.html",
        scope: {
            header:   "@",
            compid:   "@",
            category: "@",
            sortby:   "@",
            reverse:  "@"
        },
        controller: ['$scope', 'Comp', function($scope, Comp) {
            $scope.header = $scope.header || 
                            Comp.catname($scope.category) + ' Outputs';

            $scope.sortby = $scope.sortby || 'name';
            $scope.reverse = $scope.reverse || false;

            this.catname = function() {
                return Comp.catname($scope.category);
            }

            this.outputs = function() {
                return Comp.outputs($scope.compid);
            }

            this.size = function() {
                return Comp.catSize($scope.compid, $scope.category);
            }

            this.sortby = function(column,reverse) {
                $scope.sortby = column;

                if (reverse) {
                    $scope.reverse = true;
                } else {
                    $scope.reverse = false;
                }
            }
        }],
        controllerAs: 'comp'
    };
});