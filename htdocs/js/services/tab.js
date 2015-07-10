// tab.js -- Tab Manager Service

angular.module('arachne')
.factory('Tab', function() {
    var service = {}
    var tabs = {};

    // get(page) -- Return the tab set for the given page
    service.get = function(page) {
        return tabs[page];
    }

    // set(page,tab) -- Set the tab for the given page.
    service.set = function(page,tab) {
        tabs[page] = tab;
    }

    // isSet(page,tab) -- Return whether the tab is set or not.
    service.isSet = function(page,tab) {
        return tabs[page] && tabs[page] === tab;
    }

    // active(page,tab) -- Returns 'active' if the tab is set.
    service.active = function(page,tab) {
        if (tabs[page] && tabs[page] === tab) {
            return 'active';
        }
    }


    service.tabber = function(page) {
        return {
            get:    function()    { return service.get(page);        },
            set:    function(tab) { service.set(page,tab);           },
            isSet:  function(tab) { return service.isSet(page,tab);  },
            active: function(tab) { return service.active(page,tab); }
        };
    }

    return service;
});