// MIT License

// Copyright 2019 Electric Imp

// SPDX-License-Identifier: MIT

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

// Agent Main Application File

// Libraries 
#require "MessageManager.lib.nut:2.4.0"
#require "UBloxAssistNow.agent.lib.nut:1.0.0"

// Supporting files
@include __PATH__ + "/../shared/Logger.shared.nut"
@include __PATH__ + "/../shared/Constants.shared.nut"
@include __PATH__ + "/Location.agent.nut"


// Main Application
// -----------------------------------------------------------------------

class MainController {
    
    loc   = null;
    mm    = null;
    cloud = null;

    constructor() {
        // Initialize Logger 
        Logger.init(LOG_LEVEL.DEBUG);

        ::debug("Agent started...");

        // Initialize Assist Now Location Helper
        loc = Location();

        // Initialize Message Manager
        mm = MessageManager();

        // Open listeners for messages from device
        mm.on(MM_REPORT, processReport.bindenv(this));
        mm.on(MM_ASSIST, getAssist.bindenv(this));

        // Initialize Cloud Service (Azure IoT Hub)
        // cloud = Cloud();
    }

    function processReport(msg, reply) {
        local report = msg.data;

        ::debug("Recieved status update from devcie: ");
        ::debug(http.jsonencode(report));
        // Report Structure (movement, fix and battStatus only included if data was collected)
            // { 
            //     "fix" : {                            // Only included if fix was obtained
            //         "accuracy": 9.3620005,           // fix accuracy
            //         "secToFix": 36.978001,           // sec from boot til accurate fix 
            //         "lat": "37.3957215",             // latitude
            //         "numSats": 10,                   // number of satellites used in fix
            //         "lon": "-122.1022552",           // longitude
            //         "fixType": 3,                    // type of fix
            //         "secTo1stFix": 9.1499996,        // ms from boot til first fix (not accurate)
            //         "time": "2019-03-01T19:10:32Z"   // time from GPS message
            //     }, 
            //     "battStatus": {                      // Only included if info returned from fuel gauge
            //         "percent": 85.53125, 
            //         "capacity": 2064 
            //     }, 
            //     "ts": 1551467430,                    // Always included, timestamp when report sent
            //     "secSinceBoot": 35126,               // Always included
            //     "movement" : true                    // Only included if movement event occured
            // }

        // TODO: Send device data to cloud service
        // cloud.send(report);
    }

    function getAssist(msg, reply) {
        ::debug("Requesting online assist messages from u-blox webservice");
        loc.getOnlineAssist(function(assistMsgs) {
            ::debug("Received online assist messages from u-blox webservice");
            if (assistMsgs != null) {
                ::debug("Sending device online assist messages");
                reply(assistMsgs);
            }
        }.bindenv(this))
    }

    function getFixDescription(fixType) {
        switch(fixType) {
            case 0:
                return "no fix";
            case 1:
                return "dead reckoning only";
            case 2:
                return "2D fix";
            case 3:
                return "3D fix";
            case 4:
                return "GNSS plus dead reckoning combined";
            case 5:
                return "time-only fix";
            default: 
                return "unknown";
        }
    }

}

// Runtime
// -----------------------------------------------------------------------

// Start controller
MainController();
