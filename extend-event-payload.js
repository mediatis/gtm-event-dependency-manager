!function() {
    window.dataLayer = window.dataLayer || [];
    window.dataLayerPush = function(data, index) {
        const EXCLUDED_KEYS = ['event', 'gtm.uniqueEventId', 'gtm.start'];
        setTimeout(function() {
            for (let key in dataLayer[index] || {}) {
                if (dataLayer[index].hasOwnProperty(key) && EXCLUDED_KEYS.indexOf(key) === -1) {
                    data[key] = dataLayer[index][key];
                }
            }
            window.dataLayer.push(data);
        }, 0);
        return true;
    };
}();
