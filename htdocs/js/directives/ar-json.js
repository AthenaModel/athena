angular.module("arachne")
.directive("arJson", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-json.html",
        scope: {
            controller: "=",
            op: "@"
        },
        controller: function($scope) {
            $scope.visible = $scope.controller.gotData($scope.op);
            $scope.jsonData = $scope.controller.jsonData;
        }
    }
});