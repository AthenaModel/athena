// debug-index.controller.js
'use strict';

angular.module('arachne')
.controller('DebugIndexController', ['$http', function($http) {
    var controller = this;

    //-------------------------------------------
    // Tab Management

    var tab = 'code';

    this.setTab = function(which) {
        tab = which;
    };
    this.active = function(which) {
        return tab === which;
    };
    this.tab = function() {
        return tab;
    }

    //--------------------------------------------
    // Mods

    this.mods = [];     // List of loaded mods

    this.retrieveMods = function (reloadFlag) {
        var url = '/debug/mods.json';

        if (reloadFlag) {
            url += '?op=reload';
        }

        $http.get(url).success(function(data) {
            controller.mods = data;
        });
    };

    //--------------------------------------------
    // URL Schemas

    this.schema = 'scenario';
    this.schemas = {
        comparison: [],
        debug:      [],
        help:       [],
        scenario:   []
    };

    this.retrieveSchema = function (name) {
        var url = '/' + name + '/urlschema.json';

        this.schemas[name] = [];

        $http.get(url).success(function(data) {
            controller.schemas[name] = data;
        });
    };

    this.setDomain = function(schema) {
        console.log("setDomain: " + schema);
        this.schema = schema;
        this.setTab('schemas');
    };

    //--------------------------------------------
    // Code Search

    this.cmdline = '';
    this.found = {
        cmdline: '',
        code:    ''
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

    //--------------------------------------------
    // Logs

    this.logArea  = '';     // Log Area displayed in logs tab
    this.logFile  = '';     // Log File displayed in logs tab
    this.logs = {};         // Dictionary of Log Files by Log Area
    this.logEntries = [];   // Array of log entries for the selected log

    this.logRetrieve = function() {
        // FIRST, get the available areas
        $http.get('/debug/logs.json').success(function(data) {
            var areas = Object.keys(data);
            controller.logs = data;
            console.log(data);

            // NEXT, if no area yet, set to last
            if (!controller.gotArea(controller.logArea)) {
                controller.setArea(areas[areas.length-1])
            }

            // NEXT, if no log file yet, set to last in area and display
            if (!controller.gotFile(controller.logFile)) {
                var logfiles = controller.logs[controller.logArea];
                controller.logFile = logfiles[logfiles.length-1];
                controller.showLog();
            }
        })
    }

    this.logAreas = function() {
        return Object.keys(this.logs);
    }

    this.logFiles = function() {
        return this.logs[this.logArea];
    }

    this.gotArea = function(area) {
        var areas = Object.keys(this.logs);
        return areas.indexOf(area) !== -1;
    }

    this.gotFile = function(file) {
        if (!this.logArea) {
            return false;
        }

        return this.logs[this.logArea].indexOf(file) !== -1;
    }

    this.setArea = function(area) {
        console.log("setArea: " + area);
        if (area === this.logArea) {
            return;
        }

        this.logArea = area;
        this.logFile = this.logs[area][this.logs[area].length - 1];
        this.setTab('logs');
        controller.logEntries = [];
        this.showLog();
    };

    this.setFile = function(file) {
        console.log("setFile: " + file);

        if (file === this.logFile) {
            return;
        }

        this.logFile = file;
        this.setTab('logs');
        controller.logEntries = [];
        this.showLog();
    };

    this.showLog = function() {
        var url = '/debug/log/index.json?logarea=' + this.logArea;
        if (this.logFile) {
            url = url + '&logfile=' + this.logFile;
        }

        $http.get(url).success(function(data) {
            controller.logEntries = data;
            console.log(data);
        })       
    };

    //--------------------------------------------
    // Initialization

    this.retrieveMods();
    this.retrieveSchema('comparison');
    this.retrieveSchema('debug');
    this.retrieveSchema('help');
    this.retrieveSchema('scenario');
    this.logRetrieve();
}]);
