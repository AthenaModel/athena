angular.module("arachne")
.directive("arVarbox", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-varbox.html",
        scope: {
            vardiff:  "=vardiff"
        },
        controller: ['$scope', function($scope) {
            // TBD
        }],
        controllerAs: 'directive'
    };
});