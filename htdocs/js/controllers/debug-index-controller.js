// debug-index.controller.js
'use strict';

angular.module('arachne')
.controller('DebugIndexController', ['$http', function($http) {
    var controller = this;
    var tab = 'code';

    this.cmdline = '';
    this.found = {
        cmdline: '',
        code:    ''
    };

    this.setTab = function(which) {
        tab = which;
    };
    this.active = function(which) {
        return tab === which;
    };

    this.codeSearch = function() {
        this.found.cmdline = this.cmdline;
        this.cmdline = '';
        $http.get('/debug/code.json', {
            params: {cmdline: this.found.cmdline}
        }).success(function(data) {
            if (data[1] !== '') {
                controller.found.code = data[1];
            } else {
                controller.found.code = "No matching code found."
            }
        }).error(function(data) {
            controller.found.code = '';
        });
    };
}]);
