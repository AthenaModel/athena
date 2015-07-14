// routes.js
'use strict';

angular.module('arachne')
.config(function($routeProvider) {
    $routeProvider.when('/home', {
        templateUrl: 'templates/pages/home/index.html'
    })

    .when('/', {
        templateUrl: 'templates/pages/home/index.html'
    })

    .when('/scenarios', {
        templateUrl: 'templates/pages/scenarios/index.html'
    })

    .when('/comparisons', {
        templateUrl: 'templates/pages/comparisons/index.html'
    })

    .when('/comparisons/:compId', {
        templateUrl: 'templates/pages/comp/index.html'
    })

    .when('/debug', {
        templateUrl: 'templates/pages/debug/index.html',
        controller: 'DebugIndexController',
        controllerAs: 'page'
    })

    .when('/help', {
        templateUrl: 'templates/pages/help/index.html'
    })

    .when('/scenarios/:caseId', {
        templateUrl: 'templates/pages/case/index.html',
        controller: 'CaseController',
        controllerAs: 'page'
    })

    .when('/scenario/:caseId/:objectType/:objectId', {
        templateUrl: 'templates/pages/case/object.html',
        controller: 'ObjectController',
        controllerAs: 'page'
    })

    .otherwise( { redirectTo: '/' });
});
