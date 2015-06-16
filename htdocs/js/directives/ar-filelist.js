angular.module("arachne")
.directive("arFilelist", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-filelist.html",
        scope: {
            files:  "=",  // List of file records
        }
    };
});