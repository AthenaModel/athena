angular.module("arachne")
.directive("arResult", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-result.html",
        scope: {
            header: "@",
            tag:    "@"
        },
        controller: ['$scope', 'Arachne', function($scope, Arachne) {
            $scope.header = $scope.header || "Result";

            this.show = function() {
                return $scope.tag === Arachne.status().tag   &&
                       Arachne.status().data;
            };

            this.code = function() {
                return Arachne.status().code;
            }

            this.status = Arachne.status;
        }],
        controllerAs: 'result'
    };
});