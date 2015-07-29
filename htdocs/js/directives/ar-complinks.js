// ar-complinks: comp links directive for inclusion in sidebars.

angular.module("arachne")
.directive("arComplinks", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-complinks.html",
        controller: ['Comparison', function(Comparison) {
            this.all = Comparison.all;
        }],
        scope: {},
        controllerAs: 'comparison'
    };
});