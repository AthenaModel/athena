angular.module("arachne")
.directive("arExample", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-example.html",
        scope: {
            header: "@",
            content: "@"
        }
    };
});