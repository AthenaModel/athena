// ar-page.js: page directive
// Standard formatting for a page with a sidebar.
angular.module("arachne")
.directive("arPage", function() {
    return {
        restrict: "E",
        templateUrl: "templates/directives/ar-page.html",
        transclude: true,
        scope: {
            page:    "=",  // The including page's controller
            sidebar: "@"   // The sidebar template's URL
        },
        controller: ['$scope', function($scope) {
            $scope.sidebar = $scope.sidebar || $scope.page.template('/sidebar.html');
        }],
        controllerAs: 'directive'
    };
});