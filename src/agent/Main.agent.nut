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
#require "AzureIoTHub.agent.lib.nut:5.0.0"

// Supporting files
@include __PATH__ + "/../shared/Logger.shared.nut"
@include __PATH__ + "/../shared/Constants.shared.nut"
@include __PATH__ + "/Location.agent.nut"
@include __PATH__ + "/Cloud.agent.nut"


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
        cloud = Cloud();
    }

    function processReport(msg, reply) {
        local report = msg.data;

        ::debug("Recieved status update from devcie: ");
        ::debug(http.jsonencode(report));
        // Report Structure (movement, fix and battStatus only included if data was collected)
            // { 
            //   "movement"         : false,                                                            // Always included
            //   "ts"               : 1569974900,                                                       // Always included
            //   "secSinceBoot"     : 31.018999,                                                        // Always included
            //   "vbat"             : 3.352,                                                            // Always included
            //   "temperature"      : 22.598141,                                                        // Only included if temp/humid reading successful
            //   "humidity"         : 35.03088,                                                         // Only included if temp/humid reading successful
            //   "containerUpright" : false,                                                            // Only included if Accel reading successful
            //   "battStatus"       : {                                                                 // Only included if rechargable battery status reading is successful
            //                          "percent"  : 13.085938, 
            //                          "capacity" : 261.5 
            //                        },
            //   "cellInfo"         : "4G,2175,4,10,10,FDD,310,410,8B3F,A211A16,347,58,-104,-8.5,CONN"  // Only included if accurate fix was NOT obtained
            //   "fix"              : {                                                                 // Only included if fix was obtained
            //                          "secToFix"    : 31.018, 
            //                          "fixType"     : 3, 
            //                          "lat"         : "37.3953878", 
            //                          "numSats"     : 13, 
            //                          "lon"         : "-122.1023261", 
            //                          "accuracy"    : 4.9060001, 
            //                          "time"        : "2019-10-02T00:08:21Z", 
            //                          "secTo1stFix" : 3.375 
            //                        }   
            // }
            
        // Get location from API if GPS was not able to get fix
        if (!("fix" in report) && "cellInfo" in report) {
            ::debug("[Main] Cell Info: " + report.cellInfo);
            local cellInfo = loc.parseCellInfo(report.cellInfo);

            if (cellInfo != null) {
                // Get location data from cell info and Google Maps API
                loc.getLocCellInfo(cellInfo, function(location) {
                    if ("lat" in location && "lon" in location) {
                        report.locType <- "gmapsAPI";
                        report.location <- location;
                    }
                    cloud.send(report);
                }.bindenv(this));
                return;
            }
        }
        
        if ("fix" in report) report.locType <- "gps";
        cloud.send(report);
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
