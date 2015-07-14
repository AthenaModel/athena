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
            if ($scope.category === 'all') {
                $scope.header = $scope.header || 'All Outputs';
            } else {
                $scope.header = $scope.header || 
                    Comp.catname($scope.category) + ' Outputs';
            }

            $scope.sortby = $scope.sortby || 'name';
            $scope.reverse = $scope.reverse || false;

            this.catname = function(category) {
                category = category || $scope.category;

                if (category === 'all') {
                    return '';
                } else {
                    return Comp.catname(category);
                }
            }

            this.outputs = function() {
                if ($scope.category === 'all') {
                    return Comp.outputs($scope.compid);
                } else {
                    return Comp.byCat($scope.compid, $scope.category);
                }
            }

            this.size = function() {
                if ($scope.category === 'all') {
                    return Comp.size($scope.compid);
                } else {
                    return Comp.catSize($scope.compid, $scope.category);
                }
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