angular.module("arachne")
.directive("arVarbox", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-varbox.html",
        scope: {
            vardiff:  "=vardiff"
        },
        controller: ['$scope', function($scope) {
            this.expanded = false;

            this.toggle = function() {
                this.expanded = !this.expanded;
            }

            this.glyph = function() {
                if (this.expanded) {
                    return "glyphicon-triangle-bottom"
                } else {
                    return "glyphicon-triangle-right"
                }                
            }
        }],
        controllerAs: 'directive'
    };
});