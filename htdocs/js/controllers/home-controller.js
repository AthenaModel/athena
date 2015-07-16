// home-controller.js -- Controller for #/home
'use strict';

angular.module('arachne')
.controller('HomeController', ['Arachne', function(Arachne) {
    // Expose Arachne query data
    this.startTime = Arachne.startTime;
    this.connected = Arachne.connected;
    this.version   = Arachne.version;
}]);

