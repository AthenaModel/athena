angular.module("arachne")
.directive("arResult", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-result.html",
        scope: {
            header: "@",
            op:     "@",
            result: "="
        },
        controller: function($scope) {
            $scope.header = $scope.header || "Result";
        }
    };
});