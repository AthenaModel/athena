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
        controller: ['$scope', 'Comparison', function($scope, Comparison) {
            var expanded = [];

            if ($scope.category === 'all') {
                $scope.header = $scope.header || 'All Outputs';
            } else {
                $scope.header = $scope.header || 
                    Comparison.catName($scope.category) + ' Outputs';
            }

            $scope.sortby = $scope.sortby || 'name';
            $scope.reverse = $scope.reverse || false;

            this.catName = function(category) {
                category = category || $scope.category;

                if (category === 'all') {
                    return '';
                } else {
                    return Comparison.catName(category);
                }
            }

            this.outputs = function() {
                if ($scope.category === 'all') {
                    return Comparison.outputs($scope.compid);
                } else {
                    return Comparison.byCat($scope.compid, $scope.category);
                }
            }

            this.size = function() {
                if ($scope.category === 'all') {
                    return Comparison.size($scope.compid);
                } else {
                    return Comparison.catSize($scope.compid, $scope.category);
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