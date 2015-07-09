// ar-tbdlist.js: main page directive
// Standard formatting for a TBD list.
angular.module("arachne")
.directive("arTbdList", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-tbd-list.html",
        transclude: true,
        scope: {}
    };
});