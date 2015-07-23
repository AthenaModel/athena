// routes.js
'use strict';

angular.module('arachne')
.config(function($routeProvider) {
    $routeProvider.when('/home', {
        templateUrl: 'templates/pages/home/index.html'
    })

    .when('/', {
        templateUrl:  'templates/pages/home/index.html'
    })

    .when('/cases', {
        templateUrl: 'templates/pages/cases/index.html'
    })

    .when('/chain/:caseId1/:varname', {
        templateUrl: 'templates/pages/chain/index.html'
    })

    .when('/chain/:caseId1/:caseId2/:varname', {
        templateUrl: 'templates/pages/chain/index.html'
    })

    .when('/comparisons', {
        templateUrl: 'templates/pages/comparisons/index.html'
    })

    .when('/comparison/:caseId1', {
        templateUrl: 'templates/pages/comparison/index.html'
    })

    .when('/comparison/:caseId1/:caseId2', {
        templateUrl: 'templates/pages/comparison/index.html'
    })

    .when('/debug', {
        templateUrl: 'templates/pages/debug/index.html',
        controller: 'DebugController',
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
