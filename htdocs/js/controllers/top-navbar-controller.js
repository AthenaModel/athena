// top-navbar-controller.js
'use strict';

angular.module('arachne')
.controller('TopNavbarController', ['Arachne', function(Arachne) {
    this.version = Arachne.version;
}]);

