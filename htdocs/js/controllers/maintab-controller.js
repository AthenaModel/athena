// maintab.js
'use strict';

angular.module('arachne')
.controller('MainTabController', function() {
    this.tab = 'home';
    this.setTab = function(which) {
        this.tab = which;
    };
    this.isSet = function(tab) {
        return this.tab === tab;
    };
});

