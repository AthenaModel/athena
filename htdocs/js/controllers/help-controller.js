// help-controller.js -- Controller for #/help
'use strict';

angular.module('arachne')
.controller('HelpController', ['Arachne', function(Arachne) {
    var controller = this;   // For use in callbacks

    // Template URL
    this.template = function(suffix) {
        return '/templates/pages/help' + suffix;
    }

    this.name = "HelpController";
}]);

