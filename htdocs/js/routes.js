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

    .when('/help', {
        templateUrl: 'templates/pages/help/index.html'
    })

    .otherwise( { redirectTo: '/' });
});
