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

// Location Assistance File 

// Token is stored in /settings/imp.config file
const UBLOX_ASSISTNOW_TOKEN    = "@{UBLOX_ASSISTNOW_TOKEN}";
const GOOGLE_MAPS_API_KEY      = "@{GOOGLE_MAPS_API_KEY}";
const GOOGLE_MAPS_LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";
const CELL_UTIL_MCC_MNC_URL    = "https://raw.githubusercontent.com/musalbas/mcc-mnc-table/master/mcc-mnc-table.csv";


// Manages u-blox Assist Now Logic
// Dependencies: UBloxAssistNow(agent) Library, GoogleMaps Rest API
// Initializes: UBloxAssistNow(agent) Library
class Location {
    
    assist = null;

    constructor() {
        assist = UBloxAssistNow(UBLOX_ASSISTNOW_TOKEN);
    }

    function getOnlineAssist(onResp) {
        local assistOnlineParams = {
            "gnss"     : ["gps", "glo"],
            "datatype" : ["eph", "alm", "aux"]
        };

        assist.requestOnline(assistOnlineParams, function(err, resp) {
            local assistData = null;
            if (err != null) {
                ::error("Online req error: " + err);
            } else {
                ::debug("Received AssistNow Online. Data length: " + resp.body.len());
                assistData = resp.body;
            }
            onResp(assistData);
        }.bindenv(this));
    }

    function getLocCellInfo(cellStatus, cb) {
        ::debug("[Location] Cell Status: " + http.jsonencode(cellStatus));

        
        local cell = {
            "cellId"            : _hexStringToInteger(cellStatus.cellid),
            "locationAreaCode"  : _hexStringToInteger(cellStatus.tac),
            "mobileCountryCode" : cellStatus.mcc,
            "mobileNetworkCode" : cellStatus.mnc
        };
        
        // Build request
        local url = format("%s%s", GOOGLE_MAPS_LOCATION_URL, GOOGLE_MAPS_API_KEY);
        local headers = { "Content-Type" : "application/json" };
        local body = {
            "considerIp" : "false",
            "radioType"  : "lte",
            "cellTowers" : [cell]
        };
        
        ::debug("[Location] Requesting Location from GoogleMaps API using Cell info...");
        local req = http.post(url, headers, http.jsonencode(body));
        req.sendasync(function(resp) {
            local parsed   = null;
            local location = null;
            try {
                ::debug("[Location] Google Maps Location response: " + resp.body);
                parsed = http.jsondecode(resp.body);
            } catch(e) {
                ::error("[Location] Geolocation parsing error: " + e);
            }
            
            if (resp.statuscode == 200) {
                local l = parsed.location;
                location = {
                    "lat" : l.lat,
                    "lon" : l.lng
                }
            } else {
                ::error("[Location] Geolocation unexpected reponse: " + resp.statuscode);
            }
            
            cb(location);
        }.bindenv(this))
    }

    // Returns cellStatus table
    function parseCellInfo(cellInfo) {
        local status = {
            "time" : time(),
            "raw"  : cellInfo
        };
            
        try {
            local str = split(cellInfo, ",");

            switch(str[0]) {
                case "4G" :
                    status.type    <- "LTE";
                    status.earfcn  <-str[1];
                    status.band    <- str[2];
                    status.dlbw    <- str[3];
                    status.ulbw    <- str[4];
                    status.mode    <- str[5];
                    status.mcc     <- str[6];
                    status.mnc     <- str[7];
                    status.tac     <- str[8];
                    status.cellid  <- str[9];
                    status.physid  <- str[10];
                    status.srxlev  <- str[11];
                    status.rsrp    <- str[12];
                    status.rsrq    <- str[13];
                    status.state   <- str[14];
                    break;
                case "3G" : 
                    status.type    <- "HSPA";
                    status.earfcn  <- str[1];
                    status.band    <- "na";
                    status.dlbw    <- "na";
                    status.ulbw    <- "na";
                    status.mode    <- "na";
                    status.mcc     <- str[5];
                    status.mnc     <- str[6];
                    status.tac     <- str[7];
                    status.cellid  <- str[8];
                    status.physid  <- "na";
                    status.srxlev  <- str[10];
                    status.rsrp    <- str[4];
                    status.rsrq    <- "na";
                    status.state   <- "na";
                    break;
                default : 
                    throw "Unrecognized type " + str[0];
            }    
        } catch(e) {
            ::error("[Location] Parsing error: " + e);
            // If there was a parsing error return null, so we know not to get location with status table
            status = null;
        }
        
        return status;
    }

    function getCarrierInfo(cellStatus, cb) {
        local req = http.get(CELL_UTIL_MCC_MNC_URL);
        req.sendasync(function(resp) {
            local carrierInfo = {};
            local body        = resp.body;
            
            if (resp.statuscode == 200) {
                local expr = regexp(cellStatus.mcc + ",.+," + cellStatus.mnc + ",.+\\n");
                local result = expr.search(body);
                if (result != null) {
                    // Get the entry and break it into substrings to get country and carrier
                    local entry = body.slice(result.begin, result.end)
                    local expr2 = regexp(@"(.+,)(.+,)(.+,)(.+,)(.+,)(.+,)(.+,)(.+)");
                    local results = expr2.capture(entry);
                    if (results) {
                        foreach (idx, value in results) {
                            local subString = entry.slice(value.begin, value.end-1)
                            if (idx == 6) { carrierInfo.country <- subString };
                            if (idx == 8) { carrierInfo.carrier <- subString };
                        }
                        carrierInfo.networkString <- "Cellular: " + carrierInfo.country + ", " + carrierInfo.carrier;
                    }
                } else {
                    ::error("[Location] Carrier info not found");
                }
            } else {
                ::error("[Location] Carrier info http request: " + resp.statuscode);
            }
            
            cb(carrierInfo);
        }.bindenv(this))
    }

    function _hexStringToInteger(hs) {
        hs = hs.tolower();
        if (hs.slice(0, 2) == "0x") hs = hs.slice(2);
        local i = 0;
        foreach (c in hs) {
            local n = c - '0';
            if (n > 9) n = ((n & 0x1F) - 7);
            i = (i << 4) + n;
        }
        return i;
    }

}
