// routes.js
'use strict';

angular.module('arachne')
.config(function($routeProvider) {
    $routeProvider.when('/home', {
        templateUrl: 'templates/pages/home/index.html',
        controller:   'HomeController',
        controllerAs: 'page'
    })

    .when('/', {
        templateUrl:  'templates/pages/home/index.html',
        controller:   'HomeController',
        controllerAs: 'page'
    })

    .when('/cases', {
        templateUrl: 'templates/pages/cases/index.html',
        controller:   'CasesController',
        controllerAs: 'page'
    })

    .when('/chain/:caseId1/:varname', {
        templateUrl:  'templates/pages/chain/index.html',
        controller:   'ChainController',
        controllerAs: 'page'
    })

    .when('/chain/:caseId1/:caseId2/:varname', {
        templateUrl:  'templates/pages/chain/index.html',
        controller:   'ChainController',
        controllerAs: 'page'
    })

    .when('/comparisons', {
        templateUrl: 'templates/pages/comparisons/index.html',
        controller:   'ComparisonsController',
        controllerAs: 'page'    
    })

    .when('/comparison/:caseId1', {
        templateUrl: 'templates/pages/comparison/index.html',
        controller: 'ComparisonController',
        controllerAs: 'page'
    })

    .when('/comparison/:caseId1/:caseId2', {
        templateUrl: 'templates/pages/comparison/index.html',
        controller: 'ComparisonController',
        controllerAs: 'page'
    })

    .when('/debug', {
        templateUrl: 'templates/pages/debug/index.html',
        controller: 'DebugController',
        controllerAs: 'page'
    })

    .when('/help', {
        templateUrl: 'templates/pages/help/index.html',
        controller: 'HelpController',
        controllerAs: 'page'
    })

    // TBD: Should be /case, not /scenarios
    .when('/scenarios/:caseId', {
        templateUrl: 'templates/pages/case/index.html',
        controller: 'CaseController',
        controllerAs: 'page'
    })

    .when('/scenarios/:caseId/history.html', {
        templateUrl: 'templates/pages/case/history.html',
        controller: 'HistController',
        controllerAs: 'page'
    })

    // TBD: Should be /case, not /scenarios
    .when('/scenario/:caseId/:objectType/:objectId', {
        templateUrl: 'templates/pages/case/object.html',
        controller: 'ObjectController',
        controllerAs: 'page'
    })

    .otherwise( { redirectTo: '/' });
});
