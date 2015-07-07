// ar-caselinks: case links directive for inclusion in sidebars.

angular.module("arachne")
.directive("arCaselinks", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-caselinks.html",
        controller: ['Arachne', function(Arachne) {
            this.cases = Arachne.cases;
        }],
        scope: {},
        controllerAs: 'arachne'
    };
});