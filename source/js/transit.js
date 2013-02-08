/*global Document Element */

(function(globalName){
    var transit = {
        retained:{},
        lastRetainId: 0
    };

    var PREFIX_MAGIC_FUNCTION = "__TRANSIT_JS_FUNCTION_";
    var PREFIX_MAGIC_NATIVE_FUNCTION = "__TRANSIT_NATIVE_FUNCTION_";
    var PREFIX_MAGIC_OBJECT = "__TRANSIT_OBJECT_PROXY_";

    var GLOBAL_OBJECT = window;

    transit.doInvokeNative = function(invocationDescription){
        throw "must be replaced by native runtime " + invocationDescription;
    };

    transit.nativeFunction = function(nativeId){
        var f = function(){
            transit.invokeNative(nativeId, this, arguments);
        };
        f.transitNativeId = PREFIX_MAGIC_NATIVE_FUNCTION + nativeId;
        return f;
    };

    transit.recursivelyProxifyMissingFunctionProperties = function(missing, existing) {
        for(var key in existing) {
            if(existing.hasOwnProperty(key)) {
                var existingValue = existing[key];

                if(typeof existingValue === "function") {
                    missing[key] = transit.proxify(existingValue);
                }
                if(typeof existingValue === "object" && typeof missing[key] === "object" && missing[key] !== null) {
                    transit.recursivelyProxifyMissingFunctionProperties(missing[key], existingValue);
                }
            }
        }
    };

    transit.proxify = function(elem) {
        if(typeof elem === "function") {
            if(typeof elem.transitNativeId !== "undefined") {
                return elem.transitNativeId;
            } else {
                return transit.retainElement(elem);
            }
        }

        if(typeof elem === "object") {
            if(elem instanceof Document || elem instanceof Element) {
                return transit.retainElement(elem);
            }

            var copy;
            try {
                copy = JSON.parse(JSON.stringify(elem));
            } catch (e) {
                return transit.retainElement(elem);
            }
            transit.recursivelyProxifyMissingFunctionProperties(copy, elem);
            return copy;
        }

        return elem;
    };

    transit.invokeNative = function(nativeId, thisArg, args) {
        var invocationDescription = {
            nativeId: nativeId,
            thisArg: (thisArg === GLOBAL_OBJECT) ? null : transit.proxify(thisArg),
            args: []
        };

        for(var i = 0;i<args.length; i++) {
            invocationDescription.args.push(transit.proxify(args[i]));
        }

        return transit.doInvokeNative(invocationDescription);
    };

    transit.retainElement = function(element){
        transit.lastRetainId++;
        var id = "" + transit.lastRetainId;
        if(typeof element === "object") {
            id = PREFIX_MAGIC_OBJECT + id;
        }
        if(typeof element === "function") {
            id = PREFIX_MAGIC_FUNCTION + id;
        }

        transit.retained[id] = element;
        return id;
    };

    transit.releaseElementWithId = function(retainId) {
        if(typeof transit.retained[retainId] === "undefined") {
            throw "no retained element with Id " + retainId;
        }

        delete transit.retained[retainId];
    };

    window[globalName] = transit;

})(
  // TRANSIT_GLOBAL_NAME
    "transit"
  // TRANSIT_GLOBAL_NAME
);