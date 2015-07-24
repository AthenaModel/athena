// home-controller.js -- Controller for #/home
'use strict';

angular.module('arachne')
.controller('HomeController', ['Arachne', function(Arachne) {
    // Template URL
    this.template = function(suffix) {
        return '/templates/pages/home' + suffix;
    }

    // Expose Arachne query data
    this.startTime = Arachne.startTime;
    this.connected = Arachne.connected;
    this.version   = Arachne.version;
}]);

