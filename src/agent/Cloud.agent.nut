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

// Cloud Service File 

// Manages Cloud Service Communications  
// Dependencies: AzureIoTHub
// Initializes: AzureIoTHub
class Cloud {

    devConnStr = null;
    client     = null;
    _deviceID  = null;

    constructor() {
        _deviceID = imp.configparams.deviceid;
        // Stores this devices connection string in class variable
        _getDeviceConnString();

        if (devConnStr != null) { 
            client = AzureIoTHub.Client(devConnStr, _onConnected.bindenv(this), _onDisconnected.bindenv(this));
            client.connect();
        } else {
            ::error("[Cloud] No Azure IoT Hub credentials for this device. Connection to Azure IoT Hub NOT established");
        }
    }

    function send(data) {
        ::log("[Cloud] In cloud send data: ");
        ::log(http.jsonencode(data));
        ::log("[Cloud] Not sending to cloud while developing!!!");
        return;

        if (devConnStr == null) return;
        // TODO: 
        // Format report data if more that json encoding the report table is needed
        // Check cloud connection state, and resend if not connected 
        local msg = AzureIoTHub.Message(http.jsonencode(data));
        client.sendMessage(msg, _onMsgSent.bindenv(this));
    }

    function _onMsgSent(err, msg) {
        if (err != 0) {
            ::error("[Cloud] IotHub send message failed: " + err);
            // TODO: Implement retry sending
            return;
        }
        ::debug("[Cloud] IoTHub message sent");
    }

    function _onConnected(err) {
        if (err != 0) {
            ::error("[Cloud] IotHub connect failed: " + err);
            return;
        }
        ::debug("[Cloud] IoTHub connected");
    }

    function _onDisconnected(err) {
        if (err != 0) {
            ::error("[Cloud] IoTHub disconnected unexpectedly with code: " + err);
            
            // Reconnect if disconnection is not initiated by application
            client.connect();
        } else {
            ::debug("[Cloud] IoTHub disconnected by application");
        }
    }

    function _getDeviceConnString() {
        // Use hardcoded values stored in imp.config file to get 
        // IoTHub Device Connection string for this device
        switch(_deviceID) {
            case "@{DEV_1_ID}": // Betsy's test device
                devConnStr = "@{DEV_1_IOTHUB_DEV_CONN_STR}";
                break;
            case "@{DEV_2_ID}": // Custom IBC board
                devConnStr = "@{DEV_2_IOTHUB_DEV_CONN_STR}";
                break;
            case "@{DEV_3_ID}": // Breakout board (1)
                devConnStr = "@{DEV_3_IOTHUB_DEV_CONN_STR}";
                break;
            case "@{DEV_4_ID}": // Breakout board (2)
                devConnStr = "@{DEV_4_IOTHUB_DEV_CONN_STR}";
                break;
        }
    }

}