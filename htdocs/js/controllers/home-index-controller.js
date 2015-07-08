// home-index-controller.js
'use strict';

angular.module('arachne')
.controller('HomeIndexController', ['Arachne', function(Arachne) {
    // Expose Arachne query data
    this.startTime = Arachne.startTime;
    this.connected = Arachne.connected;
    this.version   = Arachne.version;
}]);

