// debug-index.controller.js
'use strict';

angular.module('arachne')
.controller('DebugIndexController', ['$scope', function($scope) {
    var tab = 'code';
    $scope.setTab = function(which) {
        tab = which;
    };
    $scope.active = function(which) {
        return tab === which;
    };
}]);
