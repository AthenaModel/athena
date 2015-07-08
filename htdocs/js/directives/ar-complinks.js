// ar-complinks: comp links directive for inclusion in sidebars.

angular.module("arachne")
.directive("arComplinks", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-complinks.html",
        controller: ['Arachne', function(Arachne) {
            this.comps = Arachne.comps;
        }],
        scope: {},
        controllerAs: 'arachne'
    };
});