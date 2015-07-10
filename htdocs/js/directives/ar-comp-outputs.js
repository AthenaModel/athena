angular.module("arachne")
.directive("arCompOutputs", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-comp-outputs.html",
        scope: {
            header:   "@",
            compid:   "@",
            category: "@"
        },
        controller: ['$scope', 'Comp', function($scope, Comp) {
            $scope.header = $scope.header || 
                            Comp.catname($scope.category) + ' Outputs';

            this.size = function() {
                return Comp.catSize($scope.compid, $scope.category);
            }

            this.outputs = function() {
                return Comp.byCat($scope.compid, $scope.category);
            }
        }],
        controllerAs: 'comp'
    };
});