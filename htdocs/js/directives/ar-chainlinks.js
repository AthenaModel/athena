// ar-chainlinks: chain links directive for inclusion in sidebars.

angular.module("arachne")
.directive("arChainlinks", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-chainlinks.html",
        scope: {
            compid: "@",
            siglevel: "@"
        },
        controller: ['$scope', 'Comparison', function($scope, Comparison) {
            var comp = Comparison.wrapper($scope.compid);

            $scope.siglevel = $scope.siglevel || 1.0;

            this.names = function() {
                var outputs = comp.outputs();
                var result = [];

                for (var i = 0; i < outputs.length; i++) {
                    var diff = outputs[i];
                    if (!diff.leaf && diff.score >= $scope.siglevel) {
                        result.push(diff.name)
                    }
                }

                result.sort();

                return result;
            }
        }],
        controllerAs: 'directive'
    };
});