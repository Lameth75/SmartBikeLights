// #include HEADER
using Toybox.WatchUi;
using Toybox.AntPlus;
using Toybox.Math;
using Toybox.System;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Application.Properties as Properties;

(/* #include TARGET */)
const lightModeCharacters = [
    "S", /* High steady beam */
    "M", /* Medium steady beam */
    "s", /* Low steady beam */
    "F", /* High flash */
    "m", /* Medium flash */
    "f"  /* Low flash */
];

(/* #include TARGET */)
const controlModes = [
    "S", /* SMART */
    "N", /* NETWORK */
    "M"  /* MANUAL */
];

(/* #include TARGET */)
const networkModes = [
    "INDV", /* LIGHT_NETWORK_MODE_INDIVIDUAL */
    "AUTO", /* LIGHT_NETWORK_MODE_AUTO */
    "HIVI", /* LIGHT_NETWORK_MODE_HIGH_VIS */
    "TRAIL"
];

(/* #include TARGET */)
class BikeLightsView extends /* #if dataField */ WatchUi.DataField /* #else */ WatchUi.View /* #endif */ {

    // Fonts
    protected var _lightsFont;
    protected var _batteryFont;
    protected var _controlModeFont;

    // Fields related to lights and their network
    protected var _lightNetwork;
    protected var _lightNetworkListener;
    protected var _networkMode;
    protected var _initializedLights = 0;

    // Light data:
    // 0. BikeLight instance
    // 1. Light text (S])
    // 2. Current light mode
    // 3. Force Smart mode (high memory devices only)
    // 4. Current light control mode: 0 SMART, 1 NETWORK, 2 MANUAL
    // 5. Title
    // 6. Fit field
    // 7. Next light mode
    // 8. Next title
    // 9. Compute setMode timeout
    // 10. Current filter group index
    // 11. Current filter group deactivation delay
    // 12. Next filter group index
    // 13. Next filter group activation delay
    // 14. Light modes
    // 15. Serial number
    // 16. Icon color
    // 17. Filters
    var headlightData = new [18];
    var taillightData = new [18];

    protected var _errorCode;

    // Settings
    protected var _separatorWidth;
    protected var _separatorColor;
    protected var _titleFont;
    protected var _invertLights;
// #if highMemory
    protected var _activityColor;
// #endif
// #if touchScreen

    // Light panel settings
    var headlightPanelSettings;
    var taillightPanelSettings;

    // Pre-calculated light panel values
    private var _headlightPanel;
    private var _taillightPanel;
    private var _panelInitialized = false;

  // #if dataField
    // Setting menu
    private var _lastModeTap;
    private var _firstModeTapTime = 0;
    private var _modeTapCount = 0;
    private var _updateSettings = false;

    // Light icon tap behavior
    var headlightIconTapBehavior;
    var taillightIconTapBehavior;
    var defaultLightIconTapBehavior = [[0 /* SMART */, 1 /* NETWORK */, 2 /* MANUAL */], null /* All light modes */];
  // #endif

    // Pre-calculated positions
    protected var _isFullScreen;
    protected var _fieldWidth;
    protected var _batteryWidth = 49;
// #endif
    protected var _batteryY;
    protected var _lightY;
    protected var _titleY;
    protected var _offsetX;

    // Parsed filters
    protected var _globalFilters;

// #if highMemory
    // Settings data
    (:settings) var headlightSettings;
    (:settings) var taillightSettings;
    private var _individualNetwork;
// #endif

    // Fields used to evaluate filters
    protected var _todayMoment;
    protected var _sunsetTime;
    protected var _sunriseTime;
// #if dataField
    private var _lastSpeed;
    private var _acceleration;
    private var _bikeRadar;
  // #if highMemory
    private var _gradientData = [
        0f,    // 0. Altitude last estimate
        0f,    // 1. Altitude kalman gain
        0.1f,  // 2. Altitude process noise
        0.5f,  // 3. Altitude estimation error

        0f,    // 4. Distance last estimate
        0f,    // 5. Distance kalman gain
        0.1f,  // 6. Distance process noise
        0.5f,  // 7. Distance estimation error

        0f,    // 8. Last elapsed distance
        0,     // 9. Last calculation time
        0,     // 10. Last gradient
        false  // 11. Whether gradient should be calculated
    ];
  // #endif
// #endif

// #if highMemory
    // Callbacks (value must be a weak reference)
    public var onLightModeChangeCallback;
    public var onLightControlModeChangeCallback;
// #endif

    private var _lastUpdateTime = 0;
    private var _lastOnShowCallTime = 0;

    // Used as an out parameter for getting the group filter data
    // 0. Filter group title
    // 1. Filter group index
    // 2. Filter group activation time
    // 3. Filter group deactivation time
    private var _filterResult = new [4];

    function initialize() {
// #if dataField
        DataField.initialize();
// #else
        View.initialize();
// #endif
        _lightNetworkListener = new BikeLightNetworkListener(self);

        // In order to avoid calling Gregorian.utcInfo every second, calcualate Unix Timestamp of today
        var now = Time.now();
        var time = Gregorian.utcInfo(now, 0 /* FORMAT_SHORT */);
        _todayMoment = now.value() - ((time.hour * 3600) + (time.min * 60) + time.sec);

        onSettingsChanged();
    }

    // Called from SmartBikeLightsApp.onSettingsChanged()
    function onSettingsChanged() {
        //System.println("onSettingsChanged" + " timer=" + System.getTimer());
        _invertLights = getPropertyValue("IL");
// #if highMemory
        _activityColor = getPropertyValue("AC");
// #endif
        _errorCode = null;
        try {
            var hlData = headlightData;
            var tlData = taillightData;
            // Free memory before parsing to avoid out of memory exception
            _globalFilters = null;
            hlData[17] = null; // Headlight filters
            tlData[17] = null; // Taillight filters
// #if dataField
            _bikeRadar = null;
// #endif
            var configuration = parseConfiguration();
            _globalFilters = configuration[0];
// #if dataField
            var separatorColor = configuration[/* #if highMemory */ 14 /* #else */ 9 /* #endif */];
            _separatorColor = separatorColor == null || separatorColor == 0
                ? /* #if highMemory */ _activityColor /* #else */ 43775 /* Blue */ /* #endif */
                : separatorColor;
// #endif

            // configuration[1];  // Headlight modes
            // configuration[2];  // Headlight serial number
            // configuration[3];  // Headlight color
            // configuration[4];  // Headlight filters
            // configuration[5];  // Taillight modes
            // configuration[6];  // Taillight serial number
            // configuration[7];  // Taillight color
            // configuration[8];  // Taillight filters
            for (var i = 0; i < 8; i++) {
                var lightData = i < 4 ? hlData : tlData;
                lightData[14 + (i % 4)] = configuration[i + 1];
            }

// #if highMemory
            setupLightButtons(configuration);
// #endif
            initializeLights(null);
        } catch (e) {
            _errorCode = 4;
        }
    }

    // Overrides DataField.onLayout
    function onLayout(dc) {
        // Due to getObsurityFlags returning incorrect results here, we have to postpone the calculation to onUpdate method
        _lightY = null; // Force to pre-calculate again
    }

    function onShow() {
        //System.println("onShow=" + _lastUpdateTime  + " timer=" + System.getTimer());
        var timer = System.getTimer();
        _lastOnShowCallTime = timer;
// #if highMemory
        if (_lightNetwork instanceof AntLightNetwork.IndividualLightNetwork) {
            // We don't need to recreate IndividualLightNetwork as the network mode does not change
            return;
        }
// #endif

        // When start button is pressed onShow is called, skip re-initialization in such case. This also prevents
        // a re-initialization when switching between two data screens that both contain this data field.
        if (timer - _lastUpdateTime < 1500) {
            initializeLights(null);
            return;
        }

// #if highMemory
        // In case the user modifies the network mode outside the data field by using the built-in Garmin lights menu,
        // the LightNetwork mode will not be updated (LightNetwork.getNetworkMode). The only way to update it is to
        // create a new LightNetwork.
        recreateLightNetwork();
// #else
        releaseLights();
        _lightNetwork = null; // Release light network
        _lightNetwork = new /* #include ANT_NETWORK */(_lightNetworkListener);
// #endif
    }

// #if highMemory
    function release() {
        releaseLights();
        if (_lightNetwork != null && _lightNetwork has :release) {
            _lightNetwork.release();
        }

        _lightNetwork = null; // Release light network
    }
// #endif

// #if dataField
    // Overrides DataField.compute
    function compute(activityInfo) {
        //System.println("usedMemory=" + System.getSystemStats().usedMemory);
  // #if highMemory || ANT_NETWORK == "TestNetwork.TestLightNetwork"
        // Needed for TestLightNetwork and IndividualLightNetwork
        if (_errorCode == null && _lightNetwork != null && _lightNetwork has :update) {
            _errorCode = _lightNetwork.update();
        }
  // #endif

        var initializedLights = _initializedLights;
        if (initializedLights == 0 || _errorCode != null) {
            return null;
        }

        // Update acceleration
        var lastSpeed = _lastSpeed;
        var currentSpeed = activityInfo.currentSpeed;
        _acceleration = lastSpeed != null && currentSpeed != null && lastSpeed > 0 && currentSpeed > 0
            ? ((currentSpeed / lastSpeed) - 1) * 100
            : null;
  // #if highMemory
        // Update gradient
        var altitude = activityInfo.altitude;
        var elapsedDistance = activityInfo.elapsedDistance;
        var gradientData = _gradientData;
        if (gradientData[11] /* Enabled */ && altitude != null && elapsedDistance != null) {
            var diffDistance = elapsedDistance - gradientData[8] /* Last elapsed distance */;
            if (diffDistance > 0.5f && activityInfo.timerState == 3 /* TIMER_STATE_ON */) {
                var timer = System.getTimer();
                // Reset last estimate in case the GPS signal is lost to prevent abnormal gradients
                if ((timer - gradientData[9]) > 3000) {
                    //System.println("init d=" + elapsedDistance + " init a=" + altitude);
                    gradientData[0] = altitude; // Reset altitude last estimate
                    gradientData[4] = diffDistance; // Reset distance last estimate
                }

                gradientData[8] = elapsedDistance; // Update last elapsed distance
                gradientData[9] = timer; // Update last calculation time
                var lastEstimateAltitude = gradientData[0];
                var currentEstimateAltitude = updateGradientData(altitude, 0); // Update estimated altitude
                gradientData[10] = ((currentEstimateAltitude - lastEstimateAltitude) / updateGradientData(diffDistance, 4) /* Update estimated distance */) * 100; // Calculate gradient
                //System.println("d=" + elapsedDistance + " a=" + altitude + " ca=" + currentEstimateAltitude + " ddiff=" + diffDistance + " cddiff=" + gradientData[4] + " cadiff=" + (currentEstimateAltitude - lastEstimateAltitude) + " grade=" + gradientData[10]);
            } else {
                gradientData[10] = 0f; // Reset last gradient
            }
        }
  // #endif

        if (_sunsetTime == null && activityInfo.currentLocation != null) {
            var position = activityInfo.currentLocation.toDegrees();
            var time = Gregorian.utcInfo(Time.now(), 0 /* FORMAT_SHORT */);
            _sunriseTime = getSunriseSet(true, time, position);
            _sunsetTime = getSunriseSet(false, time, position);
        }

        var globalFilterResult = null;
        var filterResult = _filterResult;
        var globalFilterTitle = null;
        for (var i = 0; i < initializedLights; i++) {
            var lightData = getLightData(initializedLights == 1 ? null : i * 2);
            if (lightData[7] != null) {
                if (lightData[9] <= 0) {
                    lightData[7] = null;
                } else {
                    lightData[9]--; /* Timeout */
                    continue;
                }
            }

            if (lightData[4] != 0 /* SMART */ || lightData[2] < 0 /* Disconnected */) {
                lightData[10] = null; // Reset current filter group index
                lightData[11] = null; // Reset current filter group deactivation delay
                lightData[12] = null; // Reset next filter group index
                continue;
            }

            // Calculate global filters only once and only when one of the lights is in smart mode
            if (globalFilterResult == null) {
                globalFilterResult = checkFilters(activityInfo, _globalFilters, filterResult, null, 0 /* Start index */);
                globalFilterTitle = filterResult[0];
            }

            var lightFilters = lightData[17];
            var lightMode = globalFilterResult == 0
                ? 0 /* OFF */
                : checkFilters(activityInfo, lightFilters, filterResult, lightData, 0 /* Start index */);
            var nextFilterGroupIndex = filterResult[1];
            if (lightData[10] /* Current filter group */ != nextFilterGroupIndex) {
                // If the next filter group is different that the current one, then:
                // - update the deactivation delay for the current filter
                // - update the activation delay for the next filter
                var deactivationTime = lightData[11]; /* Current filter group deactivation delay */
                if (deactivationTime != null && deactivationTime > 0) {
                    lightData[11]--; // Update the deactivation delay
                    continue;
                }

                if (nextFilterGroupIndex != null && lightData[12] /* Next filter group */ == nextFilterGroupIndex) {
                    lightData[13]--; // Next filter group activation delay
                } else {
                    lightData[12] = nextFilterGroupIndex; // Next filter group
                    lightData[13] = filterResult[2]; // Next filter group activation delay
                }

                var activationTime = lightData[13]; /* Next filter group activation delay */
                if (activationTime != null && activationTime > 0) {
                    // If the activation delay has not been reached, find the next active group that has zero activation delay
                    lightMode = checkFilters(activityInfo, lightFilters, filterResult, lightData, nextFilterGroupIndex /* Start index */);
                }
            } else {
                // If the next filter is the same as the current one, reset the next filter group index
                // in order to restart the activation delay timing
                lightData[12] = null;
            }

            var title = filterResult[0] != null ? filterResult[0] : globalFilterTitle;
            lightData[10] = filterResult[1]; // Update current filter group index
            lightData[11] = filterResult[3]; // Reset the deactivation delay in case it became active again before being deactivated
            setLightMode(lightData, lightMode, title, false);
        }

        _lastSpeed = activityInfo.currentSpeed;

        return null;
    }
// #endif

    function onUpdate(dc) {
        var timer = System.getTimer();
// #if dataField
        var lastUpdateTime = _lastUpdateTime;
        // In case the device woke up from a sleep, set the control mode that was used before it went to sleep. When
        // a device goes to sleep, it turns off the lights which triggers onExternalLightModeChange method in case
        // the light are turned on and sets the control mode to manual. In such case, we store the control mode that
        // was used before the external change so that we can restore it when the device wakes up. Idealy we would not
        // change the control mode before a sleep, but as there is no way to detect when the device goes to sleep we
        // cannot do that. We are able to detect only when the device woke up by checking whether onShow method was called
        // prior calling onUpdate method. This will work only if the device went to sleep on the data screen were this
        // data field is displayed, otherwise it will not work as onUpdate will not be called.
        if (lastUpdateTime > 0 && (timer - lastUpdateTime) > 2000 && (timer - _lastOnShowCallTime) > 2000) {
            //System.println("WAKE UP lastOnShowCallTime=" + _lastOnShowCallTime  + " timer=" + System.getTimer());
            for (var i = 0; i < 3; i += 2) {
                var prevControlMode = getLightProperty("PCM", i, null);
                if (prevControlMode != null) {
                    setLightProperty("CM", i, prevControlMode);
                }
            }

            onShow();
        }

  // #if dataField && touchScreen
        if (_updateSettings) {
            _updateSettings = false;
            onSettingsChanged();
        }
  // #endif
// #endif

        _lastUpdateTime = timer;
        var width = dc.getWidth();
        var height = dc.getHeight();
        var bgColor = getBackgroundColor();
        var fgColor = 0x000000; /* COLOR_BLACK */
        if (bgColor == 0x000000 /* COLOR_BLACK */) {
            fgColor = 0xFFFFFF; /* COLOR_WHITE */
        }

        dc.setColor(fgColor, bgColor);
        dc.clear();
        if (_lightY == null) {
            preCalculate(dc, width, height);
        }

// #if dataField && touchScreen
        if (_isFullScreen && DataFieldUi.onUpdate(dc, fgColor, bgColor)) {
            return;
        }
// #endif

        var text = _errorCode != null ? "Error " + _errorCode
            : _initializedLights == 0 ? "No network"
            : null;
        if (text != null) {
            setTextColor(dc, fgColor);
// #if round && dataField
            dc.drawText(width / 2, height / 2, 0, text, 1 /* TEXT_JUSTIFY_CENTER */ | 4 /* TEXT_JUSTIFY_VCENTER */);
// #else
            dc.drawText(width / 2, height / 2, 2, text, 1 /* TEXT_JUSTIFY_CENTER */ | 4 /* TEXT_JUSTIFY_VCENTER */);
// #endif
            return;
        }

// #if touchScreen
        if (_isFullScreen) {
            drawLightPanels(dc, width, height, fgColor, bgColor);
            return;
        }
// #endif

        if (_initializedLights == 1) {
            drawLight(getLightData(null), 2, dc, width, fgColor, bgColor);
            return;
        }

        // Draw separator
        var separatorColor = _separatorColor;
        if (separatorColor != -1 /* No separator */) {
            setTextColor(dc, separatorColor == 1 /* Black/White */ ? fgColor : separatorColor);
            dc.setPenWidth(_separatorWidth);
            dc.drawLine(width / 2 + _offsetX, 0, width / 2 + _offsetX, height);
        }

        drawLight(headlightData, 1, dc, width, fgColor, bgColor);
        drawLight(taillightData, 3, dc, width, fgColor, bgColor);
    }

    function onNetworkStateUpdate(networkState) {
        //System.println("onNetworkStateUpdate=" + networkState  + " timer=" + System.getTimer());
        if (_initializedLights > 0 && networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            // Set the mode to disconnected in order to be recorded in case lights recording is enabled
            updateLightTextAndMode(headlightData, -1);
            updateLightTextAndMode(taillightData, -1);
            // We have to reinitialize in case the light network is dropped after its formation
            releaseLights();
            return;
        }

        if (_initializedLights > 0 || networkState != 2 /* LIGHT_NETWORK_STATE_FORMED */) {
            //System.println("Skip=" + _initializedLights + " networkState=" + networkState +" timer=" + System.getTimer());
            return;
        }

        var networkMode = _lightNetwork.getNetworkMode();
        if (networkMode == null) {
            networkMode = 3; // TRAIL
        }

        // In case the user changes the network mode outside the application, set the default to network control mode
        var newNetworkMode = _networkMode != null && networkMode != _networkMode ? networkMode : null;
        _networkMode = networkMode;

        // Initialize lights
        initializeLights(newNetworkMode);
    }

    function updateLight(light, mode) {
        var lightType = light.type;
        if (_initializedLights == 0 || (lightType != 0 /* LIGHT_TYPE_HEADLIGHT */ && lightType != 2 /* LIGHT_TYPE_TAILLIGHT */)) {
            //System.println("skip updateLight light=" + light.type + " mode=" + mode + " timer=" + System.getTimer());
            return;
        }

        var lightData = getLightData(lightType);
// #if highMemory
        light = tryUpdateMultiBikeLight(lightData, light);
// #endif
        var oldLight = lightData[0];
        if (oldLight == null || oldLight.identifier != light.identifier) {
            return;
        }

        lightData[0] = light;
        var nextMode = lightData[7];
        if (mode == lightData[2] && nextMode == null) {
            //System.println("skip updateLight light=" + light.type + " mode=" + mode + " currMode=" + lightData[2] + " nextMode=" + lightData[7]  + " timer=" + System.getTimer());
            return;
        }

        //System.println("updateLight light=" + light.type + " mode=" + mode + " currMode=" + lightData[2] + " nextMode=" + nextMode + " timer=" + System.getTimer());
        var controlMode = lightData[4];
        if (nextMode == mode) {
            lightData[5] = lightData[8]; // Update title
            lightData[7] = null;
            lightData[8] = null;
        } else if (controlMode != 1 /* NETWORK */) {
            lightData[5] = null;
        }

        if (updateLightTextAndMode(lightData, mode) &&
            nextMode != mode && controlMode != 1 /* NETWORK */ &&
            // In the first few seconds during and after the network formation the lights may automatically switch to different
            // light modes, which can change their control mode to manual. In order to avoid changing the control mode, we
            // ignore initial light mode changes. This mostly helps when a device wakes up after only a few seconds of sleep.
            (System.getTimer() - _lastOnShowCallTime) > 5000) {
            // Change was done outside the data field.
            onExternalLightModeChange(lightData, mode);
        }
    }

// #if highMemory
  // #if dataField
    (:settings)
    function getSettingsView() {
        var menu = null;
        if (_errorCode != null ||
            _initializedLights == 0 ||
            !validateSettingsLightModes(headlightData[0]) ||
            !validateSettingsLightModes(taillightData[0]) ||
            !(WatchUi has :Menu2)) {
            menu = new AppSettings.Menu();
            return [menu, new MenuDelegate(menu)];
        }

        var menuContext = [
            headlightSettings,
            taillightSettings,
            getLightSettings(0 /* LIGHT_TYPE_HEADLIGHT */),
            getLightSettings(2 /* LIGHT_TYPE_TAILLIGHT */)
        ];
        menu = _initializedLights > 1
            ? new LightsSettings.LightsMenu(self, menuContext, true)
            : new LightsSettings.LightMenu(getLightData(null)[0].type, self, menuContext, true);

        return [menu, new MenuDelegate(menu)];
    }
  // #endif

    (:settings)
    function getLightSettings(lightType) {
        var lightData = getLightData(lightType);
        var light = lightData[0];
        if (light == null) {
            return null;
        }

        var lightSettings = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */
            ? headlightSettings
            : taillightSettings;

        return lightSettings == null
            ? getDefaultLightSettings(light)
            : lightSettings;
    }

    (:lightButtons)
    function setLightAndControlMode(lightData, lightType, newMode, newControlMode) {
        if (lightData[0] == null || _errorCode != null) {
            return; // This can happen when in menu the network is dropped or an invalid configuration is set
        }

        var controlMode = lightData[4];
        // In case the previous mode is Network we have to call setMode to override it
        var forceSetMode = controlMode == 1 /* NETWORK */ && newControlMode != null;
        if (newControlMode == 1 /* NETWORK */) {
            setNetworkMode(lightData, _networkMode);
        } else if ((controlMode == 2 /* MANUAL */ && newControlMode == null) || newControlMode == 2 /* MANUAL */) {
            setLightProperty("MM", lightType, newMode);
            setLightMode(lightData, newMode, null, forceSetMode);
        } else if (newControlMode == 0 /* SMART */ && forceSetMode) {
            setLightMode(lightData, lightData[2], null, true);
        }

        if (newControlMode != null) {
            setLightProperty("CM", lightType, newControlMode);
            lightData[4] = newControlMode;
            var callback = onLightControlModeChangeCallback;
            if (callback != null && callback.stillAlive() && callback.get() has :onLightControlModeChange) {
                callback.get().onLightControlModeChange(lightType, newControlMode);
            }
        }
    }
// #endif

// #if touchScreen
    function onTap(location) {
  // #if dataField
        if (DataFieldUi.onTap(location)) {
            if (!DataFieldUi.isMenuOpen()) {
                // Call onSettingsChanged in next onUpdate call. We don't want to call the method here in order to prevent Stack Overflow Error.
                _updateSettings = true;
            }

            return true;
        }
  // #endif

        if (_fieldWidth == null || _initializedLights == 0 || _errorCode != null) {
  // #if dataField
            if (_isFullScreen) {
                DataFieldUi.pushMenu(new AppSettings.Menu());
                return true;
            }
  // #endif

            return false;
        }

        // Find which light was tapped
        var lightData = getLightData(_initializedLights == 1 ? null
          : (_fieldWidth / 2) > location[0] ? (_invertLights ? 2 : 0)
          : (_invertLights ? 0 : 2));
        if (getLightBatteryStatus(lightData) > 5) {
            return false; // Battery is disconnected
        }

        var light = lightData[0];
        var lightType = light.type;
        var controlMode = lightData[4];
        if (_isFullScreen) {
            return onLightPanelTap(location, lightData, lightType, controlMode);
        }

  // #if widget
        return false;
  // #else
        var tapBehavior = lightType == 0 ? headlightIconTapBehavior : taillightIconTapBehavior;
        if (tapBehavior == null) {
            tapBehavior = defaultLightIconTapBehavior;
        }

        var filters = lightData[17];
        var controlModes = tapBehavior[0];
        var controlModesSize = controlModes.size();
        if (controlModesSize == 0 || (controlModesSize == 1 && controlModes.indexOf(0 /* SMART */) == 0 && filters == null)) {
            return false; // Tapping on light icon is disabled
        }

        var newMode = null;
        var newControlMode = null;
        var controlModeIndex = controlModes.indexOf(controlMode);
        var lightModes = getLightModes(light);
        var allowedLightModes = tapBehavior[1] != null ? tapBehavior[1] : lightModes;
        var lightModeIndex = allowedLightModes.indexOf(lightData[2]);
        var newLightModeIndex = lightModeIndex + 1;
        if (controlMode == 2 /* MANUAL */ && controlModeIndex >= 0 && lightModeIndex >= 0 && newLightModeIndex < allowedLightModes.size()) {
            newMode = allowedLightModes[newLightModeIndex];
        } else {
            newControlMode = controlModes[(controlModeIndex + 1) % controlModesSize];
            if (newControlMode == 0 /* SMART */ && filters == null) {
                newControlMode = controlModes[(controlModeIndex + 2) % controlModesSize]; // Skip Smart mode
            }

            if (newControlMode == 2 /* MANUAL */) {
                newMode = allowedLightModes[0];
            } else if (controlMode == newControlMode) {
                return false;
            }
        }

        if (newMode != null && lightModes.indexOf(newMode) < 0) {
            return false; // Invalid light icon configuration
        }

        setLightAndControlMode(lightData, lightType, newMode, newControlMode);
        return true;
  // #endif
    }
// #endif

    function getLightData(lightType) {
        return lightType == null
            ? headlightData[0] != null ? headlightData : taillightData
            : lightType == 0 ? headlightData : taillightData;
    }

// #if highMemory
    function tryUpdateMultiBikeLight(lightData, newLight) {
        var oldLight = lightData[0];
        if (oldLight == null || !(oldLight has :updateLight)) {
            return newLight;
        }

        return oldLight.updateLight(newLight, lightData[7]);
    }

    function combineLights(lightData, light) {
        var currentLight = lightData[0];
        if (currentLight has :addLight) {
            currentLight.addLight(light);
            return currentLight;
        }

        return new MultiBikeLight(currentLight, light);
    }
// #endif

    protected function getPropertyValue(key) {
        return Properties.getValue(key);
    }

// #if widget
    protected function getBackgroundColor() {
    }
// #endif

// #if widget
    protected function preCalculate(dc, width, height) {
// #if touchScreen
        _fieldWidth = width;
        _isFullScreen = true;
// #endif
    }
// #elif rectangle
    protected function preCalculate(dc, width, height) {
        // Free resources
        _lightsFont = null;
        _batteryFont = null;
        _controlModeFont = null;
        var fonts = Rez.Fonts;
        var deviceSettings = System.getDeviceSettings();
        var padding = height - 55 < 0 ? 0 : 3;
        var settings = WatchUi.loadResource(Rez.JsonData.Settings);
        _separatorWidth = settings[0];
        _titleFont = settings[1];
        var titleTopPadding = settings[2];
        _offsetX = settings[3];
  // #if touchScreen
        _fieldWidth = width;
        _isFullScreen = width == deviceSettings.screenWidth && height == deviceSettings.screenHeight;
  // #endif
  // #if highMemory && mediumResolution
        if (_initializedLights == 1 /* #if touchScreen */ && !_isFullScreen /* #endif */) {
            _lightsFont = WatchUi.loadResource(fonts[:lightsLargeFont]);
            _batteryFont = WatchUi.loadResource(fonts[:batteryLargeFont]);
            _controlModeFont = WatchUi.loadResource(fonts[:controlModeLargeFont]);
            _lightY = height - 50 - padding;
            _batteryY = _lightY;
            _titleY = (_lightY - dc.getFontHeight(_titleFont) - titleTopPadding) >= 0 ? titleTopPadding : null;
            return;
        }
  // #endif
        _lightsFont = WatchUi.loadResource(fonts[:lightsFont]);
        _batteryFont = WatchUi.loadResource(fonts[:batteryFont]);
        _controlModeFont = WatchUi.loadResource(fonts[:controlModeFont]);
        _batteryY = height - 19 - padding;
        _lightY = _batteryY - padding - 32 /* Lights font size */;
        _titleY = (_lightY - dc.getFontHeight(_titleFont) - titleTopPadding) >= 0 ? titleTopPadding : null;
    }
// #elif round
    protected function preCalculate(dc, width, height) {
        // Free resources
        _lightsFont = null;
        _batteryFont = null;
        _controlModeFont = null;
        var fonts = Rez.Fonts;
        var flags = getObscurityFlags();
        var settings = WatchUi.loadResource(Rez.JsonData.Settings);
        _separatorWidth = settings[0];
        _titleFont = settings[1];
        var titleTopPadding = settings[2];
        var titleHeight = dc.getFontHeight(_titleFont) + titleTopPadding;
  // #if highResolution
        var excludeBattery = height < 83;
        var lightHeight = excludeBattery ? 53 : 83;
        var includeTitle = height > 120 && width > 200;
  // #else
        var excludeBattery = height < 55;
        var lightHeight = excludeBattery ? 35 : 55;
    // #if highMemory && mediumResolution
        if (_initializedLights == 1 && !excludeBattery) {
            lightHeight = 52;
        }
    // #endif
        var includeTitle = height > 90 && width > 150;
  // #endif
        var totalHeight = includeTitle ? lightHeight + titleHeight : lightHeight;
        var startY = (12800 >> flags) & 0x01 == 1 ? 2 /* From top */
            : (200 >> flags) & 0x01 == 1 ? height - totalHeight /* From bottom */
            : (height - totalHeight) / 2; /* From center */
        _titleY = includeTitle ? startY : null;
        _lightY = includeTitle ? _titleY + titleHeight : startY;
        var offsetDirection = ((1415136409 >> (flags * 2)) & 0x03) - 1;
        _offsetX = settings[3] * offsetDirection;
  // #if highMemory && mediumResolution
        if (_initializedLights == 1 && !excludeBattery) {
            _lightsFont = WatchUi.loadResource(fonts[:lightsLargeFont]);
            _batteryFont = WatchUi.loadResource(fonts[:batteryLargeFont]);
            _controlModeFont = WatchUi.loadResource(fonts[:controlModeLargeFont]);
            _batteryY = _lightY;
            return;
        }
  // #endif
        _lightsFont = WatchUi.loadResource(fonts[:lightsFont]);
        _batteryFont = WatchUi.loadResource(fonts[:batteryFont]);
        _controlModeFont = WatchUi.loadResource(fonts[:controlModeFont]);
  // #if highResolution
        _batteryY = excludeBattery ? null : _lightY + 53;
  // #else
        _batteryY = excludeBattery ? null : _lightY + 35;
  // #endif
    }
// #endif

    protected function initializeLights(newNetworkMode) {
        //System.println("initializeLights=" + newNetworkMode + " timer=" + System.getTimer());
        var errorCode = _errorCode;
        var lightNetwork = _lightNetwork;
        if (lightNetwork == null || (errorCode != null && errorCode > 3)) {
            return;
        }

        errorCode = null;
        var firstTime = _initializedLights == 0;
        releaseLights();
        var lights = lightNetwork.getBikeLights();
        if (lights == null) {
            _errorCode = errorCode;
            return;
        }

        var recordLightModes = getPropertyValue("RL");
        var initializedLights = 0;
        var hasSerialNumber = headlightData[15] != null || taillightData[15] != null;
        for (var i = 0; i < lights.size(); i++) {
            var light = lights[i];
            var lightType = light != null ? light.type : 7;
            if (lightType != 0 && lightType != 2) {
                errorCode = 1;
                break;
            }

            var lightData = getLightData(lightType);
            var serial = lightData[15];
            if ((hasSerialNumber && lightData[14] == null) ||
                (hasSerialNumber && serial != null && serial != lightNetwork.getProductInfo(light.identifier).serial)) {
                continue;
            }

            if (lightData[0] != null) {
// #if highMemory
                light = combineLights(lightData, light);
                initializedLights--;
// #else
                errorCode = 2;
                break;
// #endif
            }

            var filters = lightData[17];
            var capableModes = getLightModes(light);
            // Validate filters light modes
            if (filters != null) {
                var j = 0;
                while (j < filters.size()) {
                    var totalFilters = filters[j + 1];
                    if (capableModes.indexOf(filters[j + 2]) < 0) {
                        errorCode = 3;
                        break;
                    }

                    j = j + 5 + (totalFilters * 3);
                }
            }

            if (newNetworkMode != null) {
                setLightProperty("CM", lightType, 1 /* NETWORK */);
            }

            var controlMode = getLightProperty("CM", lightType, filters != null ? 0 /* SMART */ : 1 /* NETWORK */);
// #if dataField
            var lightMode = controlMode <= 1 /*NETWORK*/ ? light.mode : getLightProperty("MM", light.type, 0 /* LIGHT_MODE_OFF */);
// #else
            var lightMode = light.mode;
// #endif
            var lightModeIndex = capableModes.indexOf(lightMode);
            if (lightModeIndex < 0) {
                lightModeIndex = 0;
                lightMode = 0; /* LIGHT_MODE_OFF */
            }

            if (recordLightModes && lightData[6] == null) {
                lightData[6] = createField(
                    lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? "headlight_mode" : "taillight_mode",
                    lightType, // Id
                    1 /*DATA_TYPE_SINT8 */,
                    {
                        :mesgType=> 20 /* Fit.MESG_TYPE_RECORD */
                    }
                );
            }

            lightData[0] = light;
            lightData[2] = null; // Force to update light text in case light modes were changed
            updateLightTextAndMode(lightData, lightMode);
            var oldControlMode = lightData[4];
            lightData[4] = controlMode;
            // In case of SMART or MANUAL control mode, we have to set the light mode in order to prevent the network mode
            // from changing it.
            if (firstTime || oldControlMode != controlMode) {
// #if dataField
                if (controlMode != 1 /* NETWORK */) {
                    setLightMode(lightData, lightMode, null, true);
                } else {
                    setNetworkMode(lightData, _networkMode);
                }
// #else
                // For the widget we don't want to set any mode
                if (controlMode == 1 /* NETWORK */) {
                    lightData[5] = _networkMode != null && _networkMode < $.networkModes.size()
                        ? $.networkModes[_networkMode]
                        : null;
                }
// #endif
            }

            initializedLights++;
        }

        _errorCode = errorCode;
        _initializedLights = errorCode == null ? initializedLights : 0;
// #if dataField && highMemory && mediumResolution
        _lightY = null; // Force to pre-calculate again to update icon fonts
// #endif
    }

// #if touchScreen
    protected function onLightPanelTap(location, lightData, lightType, controlMode) {
        if (!_panelInitialized) {
            return false;
        }

        var panelData = lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? _headlightPanel : _taillightPanel;
        var totalButtonGroups = panelData[0];
        var tapX = location[0];
        var tapY = location[1];
        var groupIndex = 7;
        while (groupIndex < panelData.size()) {
            var totalButtons = panelData[groupIndex];
            // All buttons in the group have the same y and height, take the first one
            var topY = panelData[groupIndex + 6];
            var height = panelData[groupIndex + 8];
            if (tapY >= topY && tapY < (topY + height)) {
                for (var j = 0; j < totalButtons; j++) {
                    var buttonIndex = groupIndex + 1 + (j * 8);
                    var leftX = panelData[buttonIndex + 4];
                    var width = panelData[buttonIndex + 6];
                    if (tapX >= leftX && tapX < (leftX + width)) {
                        var newMode = panelData[buttonIndex];
                        onLightPanelModeChange(lightData, lightType, newMode, controlMode);
                        return true;
                    }
                }
            }

            groupIndex += 1 + (totalButtons * 8);
        }

        return false;
    }

    protected function onLightPanelModeChange(lightData, lightType, lightMode, controlMode) {
  // #if dataField
        if ((System.getTimer() - _firstModeTapTime) > 5000) {
            _lastModeTap = null;
            _modeTapCount = 0;
            _firstModeTapTime = System.getTimer();
        }

        _modeTapCount = _lastModeTap == 0 && lightMode == 0 ? _modeTapCount + 1 : 1;
        _lastModeTap = lightMode;
        if (_modeTapCount > 2) {
            _lastModeTap = null;
            _modeTapCount = 0;
            DataFieldUi.pushMenu(new AppSettings.Menu());
            return;
        }
  // #endif

        var newControlMode = lightMode < 0 ? controlMode != 0 /* SMART */ && lightData[17] /* Filters */ != null ? 0 : 1 /* NETWORK */
            : controlMode != 2 /* MANUAL */ ? 2
            : null;
        setLightAndControlMode(lightData, lightType, lightMode, newControlMode);
    }
// #endif

    protected function setLightMode(lightData, mode, title, force) {
        if (lightData[2] == mode) {
            lightData[5] = title; // updateLight may not be called when setting the same mode
            if (!force) {
                return;
            }
        }

        //System.println("setLightMode=" + mode + " light=" + lightData[0].type + " force=" + force + " timer=" + System.getTimer());
        lightData[7] = mode; // Next mode
        lightData[8] = title; // Next title
        // Do not set a timeout in case we force setting the same mode, as we won't get a light update
        lightData[9] = lightData[2] == mode ? 0 : 5; // Timeout for compute method
        lightData[0].setMode(mode);
    }

    protected function getLightBatteryStatus(lightData) {
// #if highMemory
        var light = lightData[0];
        var status = light has :getBatteryStatus
            ? light.getBatteryStatus(_lightNetwork)
            : _lightNetwork.getBatteryStatus(light.identifier);
// #else
        var status = _lightNetwork.getBatteryStatus(lightData[0].identifier);
// #endif
        if (status == null) { /* Disconnected */
            updateLightTextAndMode(lightData, -1);
            return 6;
        }

        return status.batteryStatus;
    }

    protected function getLightModes(light) {
        var modes = light.getCapableModes();
        if (modes == null) {
            return [0];
        }

        // LightNetwork supports up to five custom modes, any custom mode beyond the fifth one will be set to NULL.
        // Cycliq lights FLY6 CE and Fly12 CE have the following modes: [0, 1, 2, 3, 6, 7, 63, 62, 61, 60, 59, null]
        // In such case we need to remove the NULL values from the array.
        if (modes.indexOf(null) > -1) {
            modes = modes.slice(0, null);
            modes.removeAll(null);
        }

        return modes;
    }

    protected function setLightProperty(id, lightType, value) {
        Application.Storage.setValue(id + lightType, value);
    }

    (:lightButtons)
    protected function onExternalLightModeChange(lightData, mode) {
        //System.println("onExternalLightModeChange mode=" + mode + " lightType=" + lightData[0].type  + " timer=" + System.getTimer());
        var controlMode = lightData[4];
        if (controlMode == 0 /* SMART */ && lightData[3] == true /* Force smart mode */) {
            return;
        }

        var lightType = lightData[0].type;
        setLightProperty("PCM", lightType, controlMode);
        setLightAndControlMode(lightData, lightType, mode, controlMode != 2 ? 2 /* MANUAL */ : null);
    }

    (:noLightButtons)
    protected function onExternalLightModeChange(lightData, mode) {
        var controlMode = lightData[4];
        lightData[4] = 2; /* MANUAL */
        lightData[5] = null;
        // As onHide is never called, we use the last update time in order to determine whether the data field is currently
        // displayed. In case that the data field is currently not displayed, we assume that the user used either Garmin
        // lights menu or a CIQ application to change the light mode. In such case set the next control mode to manual so
        // that when the data field will be again displayed the manual control mode will be active. In case when the light
        // mode is changed while the data field is displayed (by pressing the button on the light), do not set the next mode
        // so that the user will be able to reset back to smart by moving to a different data screen and then back to the one
        // that contains this data field. In case when the network mode is changed when the data field is not displayed by
        // using Garmin lights menu, network control mode will be active when the data field will be again displayed. As the
        // network mode is not updated when changed until a new instance of the LightNetwork is created, the logic is done in
        // onNetworkStateUpdate method.
        if (System.getTimer() > _lastUpdateTime + 1500) {
            var lightType = lightData[0].type;
            setLightProperty("PCM", lightType, controlMode);
            // Assume that the change was done either by Garmin lights menu or a CIQ application
            setLightProperty("CM", lightType, 2 /* MANUAL */);
            setLightProperty("MM", lightType, mode);
        }
    }

    protected function releaseLights() {
        _initializedLights = 0;
        headlightData[0] = null;
        taillightData[0] = null;
// #if touchScreen
        _panelInitialized = false;
        _headlightPanel = null;
        _taillightPanel = null;
// #endif
    }

// #if widget
    protected function drawLight(lightData, position, dc, width, fgColor, bgColor) {
    }
// #else
    protected function drawLight(lightData, position, dc, width, fgColor, bgColor) {
        var justification = lightData[0].type;
        if (_invertLights) {
            justification = justification == 0 ? 2 : 0;
            position = position == 1 ? 3
              : position == 3 ? 1
              : position;
        }

        var direction = justification == 0 ? 1 : -1;
  // #if rectangle
        var lightX = Math.round(width * 0.25f * position);
  // #else
        var lightX = Math.round(width * 0.25f * position) + _offsetX;
        lightX += _initializedLights == 2 ? (direction * ((width / 4) - /* #if highResolution */36/* #else */25/* #endif */)) : 0;
  // #endif
        var batteryStatus = getLightBatteryStatus(lightData);
        var title = lightData[5];
        var lightXOffset = justification == 0 ? -4 : 2;
        dc.setColor(fgColor, bgColor);

        if (title != null && _titleY != null) {
  // #if rectangle
            dc.drawText(lightX, _titleY, _titleFont, title, 1 /* TEXT_JUSTIFY_CENTER */);
  // #else
            dc.drawText(lightX + (direction * /* #if highResolution */32/* #else */22/* #endif */), _titleY, _titleFont, title, justification);
  // #endif
        }

        var iconColor = lightData[16];
        if (iconColor != null && iconColor != 1 /* Black/White */) {
            setTextColor(dc, iconColor);
        }

  // #if highResolution
        dc.drawText(lightX + (direction * (68 /* _batteryWidth */ / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        dc.drawText(lightX + (direction * 10), _lightY + 16, _controlModeFont, $.controlModes[lightData[4]], 1 /* TEXT_JUSTIFY_CENTER */);
  // #else
    // #if highMemory
        if (position == 2 && _batteryY != null) { // Use larger icons when only one light is paired
            lightX -= 10; // Center by subtracting half of battery width
            dc.drawText(lightX + (direction * (68 /* _batteryWidth */ / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
            dc.drawText(lightX + (direction * 10), _lightY + 16, _controlModeFont, $.controlModes[lightData[4]], 1 /* TEXT_JUSTIFY_CENTER */);
            drawBattery(dc, fgColor, lightX + 60, _batteryY, batteryStatus);
            return;
        }
    // #endif
        dc.drawText(lightX + (direction * (49 /* _batteryWidth */ / 2)) + lightXOffset, _lightY, _lightsFont, lightData[1], justification);
        dc.drawText(lightX + (direction * 8), _lightY + 11, _controlModeFont, $.controlModes[lightData[4]], 1 /* TEXT_JUSTIFY_CENTER */);
  // #endif
        if (_batteryY != null) {
            drawBattery(dc, fgColor, lightX, _batteryY, batteryStatus);
        }
    }
// #endif

    protected function drawBattery(dc, fgColor, x, y, batteryStatus) {
        // Draw the battery shell
        setTextColor(dc, fgColor);
        dc.drawText(x, y, _batteryFont, "B", 1 /* TEXT_JUSTIFY_CENTER */);

        // Do not draw the indicator in case the light is not connected anymore or an invalid status is given
        // The only way to detect whether the light is still connected is to check whether the its battery status is not null
        if (batteryStatus > 5) {
            return;
        }

        // Draw the battery indicator
        var color = batteryStatus == 5 /* BATT_STATUS_CRITICAL */ ? 0xFF0000 /* COLOR_RED */
            : batteryStatus > 2 /* BATT_STATUS_GOOD */ ? 0xFF5500 /* COLOR_ORANGE */
            : 0x00AA00; /* COLOR_DK_GREEN */
        setTextColor(dc, color);
        dc.drawText(x, y, _batteryFont, batteryStatus.toString(), 1 /* TEXT_JUSTIFY_CENTER */);
    }

    protected function getSecondsOfDay(value) {
        value = value.toNumber();
        return value == null ? null : (value < 0 ? value + 86400 : value) % 86400;
    }

// #if highMemory
    (:settings)
    protected function validateSettingsLightModes(light) {
        if (light == null) {
            return true; // In case only one light is connected
        }

        var settings = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */ ? headlightSettings : taillightSettings;
        if (settings == null) {
            return true;
        }

        var capableModes = getLightModes(light);
        for (var i = 2; i < settings.size(); i += 2) {
            if (capableModes.indexOf(settings[i]) < 0) {
                _errorCode = 3;
                return false;
            }
        }

        return true;
    }

    protected function recreateLightNetwork() {
        release();
        _lightNetwork = _individualNetwork != null
            ? new AntLightNetwork.IndividualLightNetwork(_individualNetwork[0], _individualNetwork[1], _lightNetworkListener)
            : new /* #include ANT_NETWORK */(_lightNetworkListener);
    }
// #endif

    // The below source code was ported from: https://www.esrl.noaa.gov/gmd/grad/solcalc/main.js
    // which is used for the NOAA Solar Calculator: https://www.esrl.noaa.gov/gmd/grad/solcalc/
    protected function getSunriseSet(rise, time, position) {
        var month = time.month;
        var year = time.year;
        if (month <= 2) {
            year -= 1;
            month += 12;
        }

        var a = Math.floor(year / 100);
        var b = 2 - a + Math.floor(a / 4);
        var jd = Math.floor(365.25 * (year + 4716)) + Math.floor(30.6001 * (month + 1)) + time.day + b - 1524.5;
        var t = (jd - 2451545.0) / 36525.0;
        var omega = degToRad(125.04 - 1934.136 * t);
        var l1 = 280.46646 + t * (36000.76983 + t * 0.0003032);
        while (l1 > 360.0) {
            l1 -= 360.0;
        }

        while (l1 < 0.0) {
            l1 += 360.0;
        }

        var l0 = degToRad(l1);
        var e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t); // unitless
        var mrad = degToRad(357.52911 + t * (35999.05029 - 0.0001537 * t));
        var ec = degToRad((23.0 + (26.0 + ((21.448 - t * (46.8150 + t * (0.00059 - t * 0.001813))) / 60.0)) / 60.0) + 0.00256 * Math.cos(omega));
        var y = Math.tan(ec/2.0);
        y *= y;
        var sinm = Math.sin(mrad);
        var eqTime = (180.0 * (y * Math.sin(2.0 * l0) - 2.0 * e * sinm + 4.0 * e * y * sinm * Math.cos(2.0 * l0) - 0.5 * y * y * Math.sin(4.0 * l0) - 1.25 * e * e * Math.sin(2.0 * mrad)) / 3.141593) * 4.0; // in minutes of time
        var sunEq = sinm * (1.914602 - t * (0.004817 + 0.000014 * t)) + Math.sin(mrad + mrad) * (0.019993 - 0.000101 * t) + Math.sin(mrad + mrad + mrad) * 0.000289; // in degrees
        var latRad = degToRad(position[0].toFloat() /* latitude */);
        var sdRad  = degToRad(180.0 * (Math.asin(Math.sin(ec) * Math.sin(degToRad((l1 + sunEq) - 0.00569 - 0.00478 * Math.sin(omega))))) / 3.141593);
        var hourAngle = Math.acos((Math.cos(degToRad(90.833)) / (Math.cos(latRad) * Math.cos(sdRad)) - Math.tan(latRad) * Math.tan(sdRad))); // in radians (for sunset, use -HA)
        if (!rise) {
            hourAngle = -hourAngle;
        }

        return getSecondsOfDay((720 - (4.0 * (position[1].toFloat() /* longitude */ + (180.0 * hourAngle / 3.141593))) - eqTime) * 60); // timeUTC in seconds
    }

    private function updateLightTextAndMode(lightData, mode) {
        var light = lightData[0];
        if (light == null || lightData[2] == mode) {
            return false;
        }

        var lightType = light.type;
        var lightModes = lightData[14];
        var lightModeCharacter = "";
        if (mode < 0) {
            lightModeCharacter = "X"; // Disconnected
        } else if (mode > 0) {
            var index = lightModes == null
                ? -1
                : ((lightModes >> (4 * ((mode > 9 ? mode - 49 : mode) - 1))) & 0x0F).toNumber() - 1;
            lightModeCharacter = index < 0 || index >= $.lightModeCharacters.size()
                ? "?" /* Unknown */
                : $.lightModeCharacters[index];
        }

        lightData[1] = lightType == (_invertLights ? 2 /* LIGHT_TYPE_TAILLIGHT */ : 0 /* LIGHT_TYPE_HEADLIGHT */) ? lightModeCharacter + ")" : "(" + lightModeCharacter;
        lightData[2] = mode;
        var fitField = lightData[6];
        if (fitField != null) {
            fitField.setData(mode);
        }

// #if highMemory
        var callback = onLightModeChangeCallback;
        if (callback != null && callback.stillAlive() && callback.get() has :onLightModeChange) {
            callback.get().onLightModeChange(lightType, mode);
        }
// #endif

        return true;
    }

// #if highMemory
    (:settings)
    private function getDefaultLightSettings(light) {
        if (light == null) {
            return null;
        }

        var modes = getLightModes(light);
        var data = new [2 * modes.size() + 1];
        var dataIndex = 1;
        data[0] = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */ ? "Headlight" : "Taillight";
        for (var i = 0; i < modes.size(); i++) {
            var mode = modes[i];
            data[dataIndex] = mode == 0 ? "Off" : mode.toString();
            data[dataIndex + 1] = mode;
            dataIndex += 2;
        }

        return data;
    }

    (:noLightButtons)
    private function setupLightButtons(configuration) {
        setupHighMemoryConfiguration(configuration);
    }

  // #if touchScreen
    private function setupLightButtons(configuration) {
        _panelInitialized = false;
        headlightPanelSettings = configuration[9];
        taillightPanelSettings = configuration[10];
        setupHighMemoryConfiguration(configuration);
    // #if dataField
        var lightsTapBehavior = configuration[13];
        if (lightsTapBehavior != null) {
            headlightIconTapBehavior = lightsTapBehavior[0];
            taillightIconTapBehavior = lightsTapBehavior[1];
        } else {
            headlightIconTapBehavior = null;
            taillightIconTapBehavior = null;
        }
    // #endif
    }
  // #endif

    (:settings)
    private function setupLightButtons(configuration) {
        headlightSettings = configuration[9];
        taillightSettings = configuration[10];
        setupHighMemoryConfiguration(configuration);
    }

    private function setupHighMemoryConfiguration(configuration) {
        _individualNetwork = configuration[11];
        if (_individualNetwork != null /* Is enabled */ || _lightNetwork instanceof AntLightNetwork.IndividualLightNetwork) {
            recreateLightNetwork();
        }

        var forceSmartMode = configuration[12];
        if (forceSmartMode != null) {
            headlightData[3] = forceSmartMode[0] == 1;
            taillightData[3] = forceSmartMode[1] == 1;
        }
    }
// #endif

// #if touchScreen
    private function drawLightPanels(dc, width, height, fgColor, bgColor) {
        if (!_panelInitialized) {
            initializeLightPanels(dc, width, height);
        }

        // In case the initialization was not successful, skip drawing
        if (_errorCode != null) {
            return;
        }

        dc.setPenWidth(2);
        if (_initializedLights == 1) {
            var lightData = getLightData(null);
            drawLightPanel(dc, lightData, lightData[0].type == 0 /* LIGHT_TYPE_HEADLIGHT */ ? _headlightPanel : _taillightPanel, width, height, fgColor, bgColor);
            return;
        }

        drawLightPanel(dc, headlightData, _headlightPanel, width, height, fgColor, bgColor);
        drawLightPanel(dc, taillightData, _taillightPanel, width, height, fgColor, bgColor);
    }

    private function getDefaultLightPanelSettings(lightType, capableModes) {
        var totalButtonGroups = capableModes.size();
        var data = [];
        data.add(totalButtonGroups); // Total buttons
        data.add(totalButtonGroups); // Total button groups
        data.add(lightType == 0 /* LIGHT_TYPE_HEADLIGHT */ ? "Headlight" : "Taillight"); // Light name
        data.add(0 /* Activity color */); // Button color
        for (var i = 0; i < totalButtonGroups; i++) {
            var mode = capableModes[i];
            var totalGroupButtons = mode == 0 /* Off */ ? 2 : 1; // Number of buttons;
            data.add(totalGroupButtons); // Total buttons in the group
            data.add(mode == 0 ? -1 : mode); // Light mode
            data.add(mode == 0 ? null : mode.toString()); // Mode name
            if (mode == 0 /* Off */) {
                data[0]++;
                data.add(mode);
                data.add("Off");
            }
        }

        return data;
    }

    private function initializeLightPanels(dc, width, height) {
        if (_initializedLights == 1) {
            initializeLightPanel(dc, getLightData(null), 2, width, height);
        } else {
            initializeLightPanel(dc, headlightData, _invertLights ? 3 : 1, width, height);
            initializeLightPanel(dc, taillightData, _invertLights ? 1 : 3, width, height);
        }

        _panelInitialized = true;
    }

    private function initializeLightPanel(dc, lightData, position, width, height) {
        var x = position < 3 ? 0 : (width / 2); // Left x
        var y = 0;
        var margin = 2;
        var buttonGroupWidth = (position != 2 ? width / 2 : width);
        var light = lightData[0];
        var capableModes = getLightModes(light);
        var fontTopPaddings = WatchUi.loadResource(Rez.JsonData.FontTopPaddings)[0];
        var panelSettings = light.type == 0 /* LIGHT_TYPE_HEADLIGHT */ ? headlightPanelSettings : taillightPanelSettings;
        if (panelSettings == null) {
            panelSettings = getDefaultLightPanelSettings(light.type, capableModes);
        }

        var i;
        var totalButtonGroups = panelSettings[1];
        // [:TotalButtonGroups:, :LightName:, :ButtonColor:, :LightNameX:, :LightNameY:, :BatteryX:, :BatteryY:, (<ButtonGroup>)+]
        // <ButtonGroup> := [:NumberOfButtons:, :Mode:, :TitleX:, :TitleFont:, (<TitlePart>)+, :ButtonLeftX:, :ButtonTopY:, :ButtonWidth:, :ButtonHeight:){:NumberOfButtons:} ]
        // <TitlePart> := [(:Title:, :TitleY:)+]
        var panelData = new [7 + (8 * panelSettings[0]) + totalButtonGroups];
        panelData[0] = totalButtonGroups;
        var buttonHeight = (height - 20 /* Battery */).toFloat() / totalButtonGroups;
        var fontResult = [0];
        var buttonPadding = margin * 2;
        var textPadding = margin * 4;
        var groupIndex = 7;
        var settingsGroupIndex = 4;
        for (i = 0; i < totalButtonGroups; i++) {
            var totalButtons = panelSettings[settingsGroupIndex];
            var buttonWidth = buttonGroupWidth / totalButtons;
            panelData[groupIndex] = totalButtons; // Buttons in group
            var titleParts = null;
            for (var j = 0; j < totalButtons; j++) {
                var buttonIndex = groupIndex + 1 + (j * 8);
                var modeIndex = settingsGroupIndex + 1 + (j * 2);
                var buttonX = x + (buttonWidth * j);
                var mode = panelSettings[modeIndex];
                if (mode > 0 && capableModes.indexOf(mode) < 0) {
                    _errorCode = 3;
                    return;
                }

                var modeTitle = mode < 0 ? "M" : panelSettings[modeIndex + 1];
                var titleList = StringHelper.trimText(dc, modeTitle, 4, buttonWidth - textPadding, buttonHeight - textPadding, fontTopPaddings, fontResult);
                var titleFont = fontResult[0];
                var titleFontHeight = dc.getFontHeight(titleFont);
                var titleFontTopPadding = StringHelper.getFontTopPadding(titleFont, fontTopPaddings);
                var titleY = y + (buttonHeight - (titleList.size() * titleFontHeight) - titleFontTopPadding) / 2 + margin;
                titleParts = new [2 * titleList.size()];
                for (var k = 0; k < titleList.size(); k++) {
                   var partIndex = k * 2;
                   titleParts[partIndex] = titleList[k];
                   titleParts[partIndex + 1] = titleY;
                   titleY += titleFontHeight;
                }

                // Set data
                panelData[buttonIndex] = mode; // Light mode
                panelData[buttonIndex + 1] = buttonX + (buttonWidth / 2); // Title x
                panelData[buttonIndex + 2] = titleFont; // Title font
                panelData[buttonIndex + 3] = titleParts; // Title parts
                panelData[buttonIndex + 4] = buttonX; // Button left x
                panelData[buttonIndex + 5] = y; // Button top y
                panelData[buttonIndex + 6] = buttonWidth; // Button width
                panelData[buttonIndex + 7] = buttonHeight; // Button height
            }

            groupIndex += 1 + (totalButtons * 8);
            settingsGroupIndex += 1 + (totalButtons * 2);
            y += buttonHeight;
        }

        // Calculate light name and battery positions
        x = Math.round(width * 0.25f * position);
        var lightName = StringHelper.trimTextByWidth(dc, panelSettings[2], 1, buttonGroupWidth - buttonPadding - _batteryWidth);
        var lightNameWidth = lightName != null ? dc.getTextWidthInPixels(lightName, 1) : 0;
        var lightNameHeight = dc.getFontHeight(1);
        var lightNameTopPadding = StringHelper.getFontTopPadding(1, fontTopPaddings);
        panelData[1] = lightName; // Light name
        panelData[2] =  panelSettings[3] == 0 ? _activityColor : panelSettings[3]; // Button color
        panelData[3] = x - (_batteryWidth / 2) - (margin / 2); // Light name x
        panelData[4] = y + ((20 - lightNameHeight - lightNameTopPadding) / 2); // Light name y
        panelData[5] = x + (lightNameWidth / 2) + (margin / 2); // Battery x
        panelData[6] = y - 1; // Battery y

        if (light.type == 0 /* LIGHT_TYPE_HEADLIGHT */) {
            _headlightPanel = panelData;
        } else {
            _taillightPanel = panelData;
        }
    }

    private function drawLightPanel(dc, lightData, panelData, width, height, fgColor, bgColor) {
        var light = lightData[0];
        var controlMode = lightData[4];
        var lightMode = lightData[2];
        var nextLightMode = lightData[7];
        var margin = 2;
        var buttonPadding = margin * 2;
        var batteryStatus = getLightBatteryStatus(lightData);
        if (batteryStatus > 5) {
            return;
        }

        // [:TotalButtonGroups:, :LightName:, :ButtonColor:, :LightNameX:, :LightNameY:, :BatteryX:, :BatteryY:, (<ButtonGroup>)+]
        // <ButtonGroup> := [:NumberOfButtons:, :Mode:, :TitleX:, :TitleFont:, (<TitlePart>)+, :ButtonLeftX:, :ButtonTopY:, :ButtonWidth:, :ButtonHeight:){:NumberOfButtons:} ]
        // <TitlePart> := [(:Title:, :TitleY:)+]
        var totalButtonGroups = panelData[0];
        var groupIndex = 7;
        for (var i = 0; i < totalButtonGroups; i++) {
            var totalButtons = panelData[groupIndex];
            for (var j = 0; j < totalButtons; j++) {
                var buttonIndex = groupIndex + 1 + (j * 8);
                var mode = panelData[buttonIndex];
                var titleX = panelData[buttonIndex + 1];
                var titleFont = panelData[buttonIndex + 2];
                var titleParts = panelData[buttonIndex + 3];
                var buttonX = panelData[buttonIndex + 4] + margin;
                var buttonY = panelData[buttonIndex + 5] + margin;
                var buttonWidth = panelData[buttonIndex + 6] - buttonPadding;
                var buttonHeight = panelData[buttonIndex + 7] - buttonPadding;
                var isSelected = lightMode == mode;
                var isNext = nextLightMode == mode;

                setTextColor(dc, isSelected ? panelData[2] : isNext ? fgColor : bgColor);
                dc.fillRoundedRectangle(buttonX, buttonY, buttonWidth, buttonHeight, 8);
                setTextColor(dc, isNext ? bgColor : fgColor);
                dc.drawRoundedRectangle(buttonX, buttonY, buttonWidth, buttonHeight, 8);
                setTextColor(dc, isSelected ? 0xFFFFFF /* COLOR_WHITE */ : isNext ? bgColor : fgColor);
                if (mode < 0) {
                    dc.drawText(titleX, titleParts[1], titleFont, $.controlModes[controlMode], 1 /* TEXT_JUSTIFY_CENTER */);
                } else {
                    for (var k = 0; k < titleParts.size(); k += 2) {
                        dc.drawText(titleX, titleParts[k + 1], titleFont, titleParts[k], 1 /* TEXT_JUSTIFY_CENTER */);
                    }
                }
            }

            groupIndex += 1 + (totalButtons * 8);
        }

        setTextColor(dc, fgColor);
        if (panelData[1] != null) {
            dc.drawText(panelData[3], panelData[4], 1, panelData[1], 1 /* TEXT_JUSTIFY_CENTER */);
        }

        drawBattery(dc, fgColor, panelData[5], panelData[6], batteryStatus);
    }
// #endif

    (:lightButtons)
    protected function getLightProperty(id, lightType, defaultValue) {
        var key = id + lightType;
        var value = Application.Storage.getValue(key);
        if (value != null && defaultValue == null) {
            Application.Storage.deleteValue(key);
        }

        if (value == null && defaultValue != null) {
            // First application startup
            value = defaultValue;
            Application.Storage.setValue(key, value);
        }

        return value;
    }

    (:noLightButtons)
    protected function getLightProperty(id, lightType, defaultValue) {
        var key = id + lightType;
        var value = Application.Storage.getValue(key);
        if (value != null) {
            Application.Storage.deleteValue(key);
        }

        return value != null ? value : defaultValue;
    }

    (:colorScreen)
    private function setTextColor(dc, color) {
        dc.setColor(color, -1 /* COLOR_TRANSPARENT */);
    }

    (:monochromeScreen)
    private function setTextColor(dc, color) {
        dc.setColor(0x000000, -1 /* COLOR_TRANSPARENT */);
    }

    private function setNetworkMode(lightData, networkMode) {
        lightData[5] = networkMode != null && networkMode < $.networkModes.size()
            ? $.networkModes[networkMode]
            : null;

        //System.println("setNetworkMode=" + networkMode + " light=" + lightData[0].type + " timer=" + System.getTimer());
        if (lightData[0].type == 0 /* LIGHT_TYPE_HEADLIGHT */) {
            _lightNetwork.restoreHeadlightsNetworkModeControl();
        } else {
            _lightNetwork.restoreTaillightsNetworkModeControl();
        }
    }

// #if dataField
    private function checkFilters(activityInfo, filters, filterResult, lightData, i) {
        var nextGroupIndex = null;
        var lightMode = 1;
        var title = null;
        var deactivationTime = null;
        var activationTime = null;
        var hasFilters = filters != null;
        var withZeroActivationTime = i > 0;
        while (hasFilters && i < filters.size()) {
            var data = filters[i];
            if (nextGroupIndex == null) {
                title = data;
                var totalFilters = filters[i + 1];
                if (lightData != null) {
                    lightMode = filters[i + 2];
                    deactivationTime = filters[i + 3];
                    activationTime = filters[i + 4];
                    i += 5;
                } else {
                    i += 2;
                }

                nextGroupIndex = i + (totalFilters * 3);
                continue;
            } else if (i >= nextGroupIndex) { // All group filters condition are met
                // Skip to the next group in case we are searching for a filter group with zero activation time
                if (withZeroActivationTime && activationTime != null && activationTime > 0) {
                    i = nextGroupIndex;
                    nextGroupIndex = null;
                    continue;
                }

                break; // We found a match, break and return the result
            }

            var filterValue = filters[i + 2];
            var isEnabled = data == 'E' ? isWithinTimespan(filters, i, filterValue)
  // #if highMemory
                : data == 'F' ? isInsideAnyPolygon(activityInfo, filterValue)
  // #endif
                : data == 'I' ? isTargetBehind(activityInfo, filters[i + 1], filterValue)
                : data == 'D' ? true
                : checkOperatorValue(
                    filters[i + 1],
                    data == 'A' ? _acceleration
                    : data == 'B' ? lightData != null ? getLightBatteryStatus(lightData) : null
                    : data == 'C' ? activityInfo.currentSpeed
                    : data == 'G' ? (activityInfo.currentLocationAccuracy == null ? 0 : activityInfo.currentLocationAccuracy)
                    : data == 'H' ? activityInfo.timerState
                    : data == 'J' ? activityInfo.startLocation == null ? 0 : 1
                    : data == 'K' && Activity has :getProfileInfo ? Activity.getProfileInfo().name
  // #if highMemory
                    : data == 'L' ? (activityInfo.timerState == 3 /* TIMER_STATE_ON */ ? _gradientData[10] /* Last gradient */ : null)
                    : data == 'M' ? System.getSystemStats() has :solarIntensity ? System.getSystemStats().solarIntensity : null
  // #endif
                    : null,
                    filterValue,
                    false);
            if (isEnabled) {
                i += 3;
            } else {
                i = nextGroupIndex;
                nextGroupIndex = null;
            }
        }

        filterResult[1] = nextGroupIndex; // Filter group index
        if (nextGroupIndex != null) {
            filterResult[0] = title; // Filter group title
            filterResult[2] = activationTime; // Filter group activation time
            filterResult[3] = deactivationTime; // Filter group deactivation time
            return lightMode;
        }

        filterResult[0] = null;
        filterResult[2] = null;
        filterResult[3] = null;
        return hasFilters || lightData != null ? 0 : 1;
    }

    private function isWithinTimespan(filters, index, filterValue) {
        if (filterValue.size() == 4) {
            filterValue = initializeTimeFilter(filterValue);
            if (filterValue == null) {
                return false;
            }

            filters[index + 2] = filterValue;
        }

        var value = (Time.now().value() - _todayMoment) % 86400;
        var from = filterValue[0];
        var to = filterValue[1];
        return from > to /* Whether timespan goes into the next day */
            ? value > from || value < to
            : value > from && value < to;
    }

    private function checkOperatorValue(operator, value, filterValue, isTarget) {
        return value == null ? isTarget ? filterValue < 0 : false // For bike radar target filterValue will be -1 in case not set
            : operator == '<' || operator == '[' ? value < filterValue
            : operator == '>' || operator == ']' ? value > filterValue
            : operator == '{' ? value <= filterValue
            : operator == '}' ? value >= filterValue
            // Use equals method only for string values as it checks also the type. When comparing
            // numeric values we want to ignore the type (e.g. 0 == 0f), so == operator is used instead.
            : operator == '=' ? value instanceof String ? value.equals(filterValue) : value == filterValue
            : false;
    }

  // #if highMemory
    private function updateGradientData(value, index) {
        // Calculate smooth gradient, applying simple kalman filter
        var gradientData = _gradientData;
        var lastEstimate = gradientData[index];
        var errorEstimate = gradientData[index + 3];
        var kalmanGain = errorEstimate / (errorEstimate + 5f /* Measure error */);
        var currentEstimate = lastEstimate + kalmanGain * (value - lastEstimate);
        var diffEstimate = (lastEstimate - currentEstimate).abs();
        gradientData[index + 3] = (1f - kalmanGain) * errorEstimate + diffEstimate * gradientData[index + 2] /* Process noise */; // Update estimation error
        gradientData[index + 1] = kalmanGain; // Update kalman gain
        gradientData[index + 2] = 1f /* Max process noise */ / (1f + diffEstimate * diffEstimate); // Update process noise
        gradientData[index] = currentEstimate; // Update last estimate
        return currentEstimate;
    }

    private function isInsideAnyPolygon(activityInfo, filterValue) {
        if (activityInfo.currentLocation == null) {
            return false;
        }

        var position = activityInfo.currentLocation.toDegrees();
        for (var i = 0; i < filterValue.size(); i += 8) {
            if (isPointInPolygon(position[1] /* Longitude */, position[0] /* Latitude  */, filterValue, i)) {
                return true;
            }
        }

        return false;
    }

    // Code ported from https://stackoverflow.com/a/14998816
    private function isPointInPolygon(x, y, points, index) {
        var result = false;
        var pointX;
        var lastPointX;
        var pointY;
        var lastPointY;
        var to = index + 8;
        var j = to - 2;
        for (var i = index; i < to; i += 2) {
            pointY = points[i];
            pointX = points[i + 1];
            lastPointY = points[j];
            lastPointX = points[j + 1];
            if (pointY < y && lastPointY >= y || lastPointY < y && pointY >= y)
            {
                if ((pointX + (y - pointY) / (lastPointY - pointY) * (lastPointX - pointX)) < x) {
                    result = !result;
                }
            }

            j = i;
        }

        return result;
    }
  // #endif

    private function isTargetBehind(activityInfo, operator, filterValue) {
        if (_bikeRadar == null) {
            return false;
        }

        var targets = _bikeRadar.getRadarInfo();
        if (targets == null) {
            return false;
        }

        var range = filterValue[0];
        var threatOperator = filterValue[1];
        var threat = filterValue[2];
        for (var i = 0; i < targets.size(); i++) {
            var target = targets[i];
            if (checkOperatorValue(threatOperator, target.threat, threat, true) &&
                checkOperatorValue(operator, target.range, range, true)) {
                return true;
            }
        }

        return false;
    }

    private function initializeTimeFilter(filterValue) {
        var result = new [2];
        for (var i = 0; i < 2; i++) {
            var type = filterValue[i*2];
            if (type > 0 /* Sunset or sunrise */ && _sunsetTime == null) {
                return null; // Not able to initialize
            }

            var value = filterValue[i*2 + 1];
            result[i] = getSecondsOfDay(
                type == 2 /* Sunset */ ? _sunsetTime + value
                : type == 1 /* Sunrise */ ? _sunriseTime + value
                : value
            );
        }

        return result;
    }
// #endif

    // <GlobalFilters>#<HeadlightModes>:<HeadlightSerialNumber>#<HeadlightFilters>#<TaillightModes>:<TaillightSerialNumber>#<TaillightFilters>
    private function parseConfiguration() {
// #if highMemory
  // #if dataField
        _gradientData[11] = false; // Reset whether gradient should be calculated
  // #endif
        var currentConfig = getPropertyValue("CC");
        var configKey = currentConfig != null && currentConfig > 1
            ? "LC" + currentConfig
            : "LC";
        var value = getPropertyValue(configKey);
// #else
        var value = getPropertyValue("LC");
// #endif
        if (value == null || value.length() == 0) {
// #if highMemory
            return new [15];
// #else
            return new [10];
// #endif
        }

        var filterResult = [0 /* next index */, 0 /* operator type */];
        var chars = value.toCharArray();
        return [
            parseFilters(chars, 0, false, filterResult),       // Global filter
            parseLightInfo(chars, 0, filterResult),            // Headlight light modes
            parseLightInfo(chars, 1, filterResult),            // Headlight serial number
            parseLightInfo(chars, 2, filterResult),            // Headlight icon color
            parseFilters(chars, null, true, filterResult),     // Headlight filters
            parseLightInfo(chars, 0, filterResult),            // Taillight light modes
            parseLightInfo(chars, 1, filterResult),            // Taillight serial number
            parseLightInfo(chars, 2, filterResult),            // Taillight icon color
            parseFilters(chars, null, true, filterResult),     // Taillight filters
// #if highMemory
            parseLightButtons(chars, null, filterResult),      // Headlight panel/settings buttons
            parseLightButtons(chars, null, filterResult),      // Taillight panel/settings buttons
            parseIndividualNetwork(chars, null, filterResult), // Individual network settings
            parseForceSmartMode(chars, null, filterResult),    // Force smart mode
  // #if touchScreen && dataField
            parseLightsTapBehavior(chars, null, filterResult), // Light icons tap behavior
  // #else
            null,
  // #endif
// #endif
// #if dataField
            parse(1 /* NUMBER */, chars, null, filterResult)   // Separator color
// #endif
        ];
    }

// #if highMemory
    private function parseIndividualNetwork(chars, i, filterResult) {
        var enabled = parse(1 /* NUMBER */, chars, i, filterResult);
        if (enabled == null) { // Old configuration
            filterResult[0] = filterResult[0] - 1; // Avoid parseForceSmartMode from parsing the next value
            return null;
        } else if (enabled != 1) { // 0::
            filterResult[0] = filterResult[0] + 2;
            return null;
        }

        return [
            parse(1 /* NUMBER */, chars, null, filterResult), // Headlight device number
            parse(1 /* NUMBER */, chars, null, filterResult)  // Taillight device number
        ];
    }

    private function parseForceSmartMode(chars, i, filterResult) {
        var headlightForceSmartMode = parse(1 /* NUMBER */, chars, i, filterResult);
        if (headlightForceSmartMode == null) {
            filterResult[0] = filterResult[0] - 1; // Avoid parseLightsTapBehavior from parsing the next value
            return null;
        }

        return [
            headlightForceSmartMode, // Headlight force smart mode
            parse(1 /* NUMBER */, chars, null, filterResult)  // Taillight force smart mode
        ];
    }

    (:noLightButtons)
    private function parseLightButtons(chars, i, filterResult) {
        filterResult[0] = filterResult[0] + 1;
        return null;
    }

    // <TotalButtons>:<LightName>|[<Button>| ...]
    // <Button> := <ModeTitle>:<LightMode>
    // Example: 6:Ion Pro RT|Off:0|High:1|Medium:2|Low:5|Night Flash:62|Day Flash:63
    (:settings)
    private function parseLightButtons(chars, i, filterResult) {
        var totalButtons = parse(1 /* NUMBER */, chars, i, filterResult);
        if (totalButtons == null || totalButtons > 10) {
            return null;
        }

        // Check whether the configuration string is valid
        i = filterResult[0];
        if (i >= chars.size() || chars[i] != ':') {
            throw new Lang.Exception();
        }

        var data = new [1 + (2 * totalButtons)];
        data[0] = parse(0 /* STRING */, chars, null, filterResult);
        i = filterResult[0];
        var dataIndex = 1;

        for (var j = 0; j < totalButtons; j++) {
            data[dataIndex] = parse(0 /* STRING */, chars, null, filterResult);
            data[dataIndex + 1] = parse(1 /* NUMBER */, chars, null, filterResult);
            dataIndex += 2;
        }

        return data;
    }
// #endif

// #if touchScreen
    // <TotalButtons>,<TotalButtonGroups>:<LightName>:<ButtonColor>|[<ButtonGroup>| ...]
    // <ButtonGroup> := <ButtonsNumber>,[<Button>, ...]
    // <Button> := <ModeTitle>:<LightMode>
    // Example: 7,6:Ion Pro RT|2,:-1,Off:0|1,High:1|1,Medium:2|1,Low:5|1,Night Flash:62|1,Day Flash:63
    private function parseLightButtons(chars, i, filterResult) {
        var totalButtons = parse(1 /* NUMBER */, chars, i, filterResult);
        if (totalButtons == null) {
            return null;
        }

        var totalButtonGroups = parse(1 /* NUMBER */, chars, null, filterResult);
        // [:TotalButtons:, :TotalButtonGroups:, :LightName:, :ButtonColor:, (<ButtonGroup>)+]
        // <ButtonGroup> = :NumberOfButtons:, (<Button>){:NumberOfButtons:})
        // <Button> = :Mode:, :Title:
        var data = new [4 + (2 * totalButtons) + totalButtonGroups];
        data[0] = totalButtons;
        data[1] = totalButtonGroups;
        data[2] = parse(0 /* STRING */, chars, null, filterResult);
        data[3] = chars[filterResult[0]] == ':'
            ? parse(1 /* NUMBER */, chars, null, filterResult)
            : 0 /* Activity color */; // Old configuration
        i = filterResult[0];
        var dataIndex = 4;

        while (i < chars.size()) {
            var char = chars[i];
            if (char == '#') {
                break;
            }

            if (char == '|' || char == '!') {
                var numberOfButtons = parse(1 /* NUMBER */, chars, null, filterResult); // Number of buttons in the group
                data[dataIndex] = numberOfButtons;
                dataIndex++;
                for (var j = 0; j < numberOfButtons; j++) {
                    data[dataIndex + 1] = parse(0 /* STRING */, chars, null, filterResult);
                    data[dataIndex] = parse(1 /* NUMBER */, chars, null, filterResult);
                    dataIndex += 2;
                }

                i = filterResult[0];
            } else {
                return null;
            }
        }

        return data;
    }

  // #if dataField
    private function parseLightsTapBehavior(chars, i, filterResult) {
        var headlightBehavior = parseLightTapBehavior(chars, i, filterResult);
        if (headlightBehavior == null) {
            filterResult[0] = filterResult[0] - 1; // Avoid separatorColor from parsing the next value
            return null;
        }

        return [
            headlightBehavior,
            parseLightTapBehavior(chars, i, filterResult)
        ];
    }

    private function parseLightTapBehavior(chars, i, filterResult) {
        // HL all modes, TL two modes: 231!:123!0,1
        // Disabled: 0!:0!
        var value = parse(1 /* NUMBER */, chars, i, filterResult);
        if (value == null) {
            return null; // Old configuration or widget
        }

        var controlModes = [];
        var manualModes = [];
        var controlModeChars = value.toString().toCharArray();
        // Parse control modes
        for (var j = 0; j < controlModeChars.size(); j++) {
            var controlMode = controlModeChars[j].toString().toNumber();
            if (controlMode != null && controlMode > 0 && controlMode < 4) {
                controlModes.add(controlMode - 1);
            }
        }

        // Parse manual light modes
        do {
            value = parse(1 /* NUMBER */, chars, null, filterResult);
            if (value != null) {
                manualModes.add(value);
            }

            i = filterResult[0];
        } while (value != null && i < chars.size() && chars[i] == ',');

        return [
            controlModes,
            manualModes.size() == 0 ? null : manualModes
        ];
    }
  // #endif
// #endif

// #if widget
    private function parseFilters(chars, i, lightMode, filterResult) {
        filterResult[0] = i == null ? filterResult[0] + 1 : i;
        return null;
    }
// #endif

// #if dataField
    // <TotalFilters>,<TotalGroups>|[<FilterGroup>| ...]
    // <FilterGroup> := <GroupName>:<FiltersNumber>(?:<LightMode>)(?:<DeactivationTime>)(?:<ActivationTime>)[<Filter>, ...]
    // <Filter> := <FilterType><FilterOperator><FilterValue>
    private function parseFilters(chars, i, lightMode, filterResult) {
        var totalFilters = parse(1 /* NUMBER */, chars, i, filterResult);
        if (totalFilters == null) {
            return null;
        }

        var data = [];
        var groups = 0;
        var filters = 0;
        var totalGroups = parse(1 /* NUMBER */, chars, null, filterResult);
        i = filterResult[0];

        while (i < chars.size()) {
            var charNumber = chars[i].toNumber();
            if (charNumber == 35 /* # */) {
                break;
            }

            if (charNumber == 124 /* | */ || charNumber == 33 /* ! */) {
                groups++;
                data.add(parse(0 /* STRING */, chars, null, filterResult)); // Group title
                data.add(parse(1 /* NUMBER */, chars, null, filterResult)); // Number of filters in the group
                if (lightMode) {
                    data.add(parse(1 /* NUMBER */, chars, null /* Skip : */, filterResult)); // The light mode id
                    // Parse filter group deactivation and activation delay
                    for (var j = 0; j < 2; j++) {
                        data.add(chars[filterResult[0]] == ':' // For back compatibility
	                        ? parse(1 /* NUMBER */, chars, null /* Skip : */, filterResult)
	                        : 0);
                    }
                }

                i = filterResult[0];
            } else if (charNumber >= 65 /* A */ && charNumber <= 90 /* Z */) {
                filters++;
                var filterType = chars[i];
                i++;
                filterResult[1] = chars[i]; // Filter operator
                var filterValue = charNumber == 69 /* E */ ? parseTimespan(chars, i, filterResult)
  // #if highMemory
                    : charNumber == 70 /* F */? parsePolygons(chars, i, filterResult)
  // #endif
                    : charNumber == 73 /* I */ ? parseBikeRadar(chars, i, filterResult)
                    // In case of a string value, the last character will be a : character in order to know where the next filter starts.
                    // The : character will be automatically skipped by the parseFilters method, so we do not have to increment the
                    // filterResult index here.
                    : parse(charNumber == 75 /* Profile name */ ? 0 /* STRING */ : 1 /* NUMBER */, chars, i + 1, filterResult);
  // #if highMemory
                _gradientData[11] |= charNumber == 76 /* L */;
  // #endif
                data.add(filterType); // Filter type
                data.add(filterResult[1]); // Filter operator
                data.add(filterValue); // Filter value
                i = filterResult[0];
            } else {
                // Skip any extra characters (e.g. character : for a string generic filter)
                i++;
                filterResult[0] = i;
            }
        }

        if (totalGroups != groups || totalFilters != filters) {
            throw new Lang.Exception();
        }

        return data;
    }

    // E<?FromType><FromValue>,<?ToType><ToValue> (Es45,r-45 E35645,8212)
    private function parseTimespan(chars, index, filterResult) {
        var data = new [4];
        filterResult[1] = null; /* Filter operator */
        for (var i = 0; i < 2; i++) {
            var char = chars[index];
            var type = char == 's' ? 2 /* Sunset */
                : char == 'r' ? 1 /* Sunrise */
                : 0; /* Total minutes of the day */
            if (type != 0) {
                index++;
            }

            data[i*2] = type;
            data[i*2 + 1] = parse(1 /* NUMBER */, chars, index, filterResult);
            index = filterResult[0] + 1; /* Skip , */
        }

        return data;
    }

    // I<300>0
    private function parseBikeRadar(chars, index, filterResult) {
        filterResult[1] = chars[index]; // Filter operator
        _bikeRadar = Toybox.AntPlus has :BikeRadar ? new AntPlus.BikeRadar(null) : null;

        return [
            parse(1 /* NUMBER */, chars, index + 1, filterResult), // Range
            chars[filterResult[0]], // Threat operator
            parse(1 /* NUMBER */, chars, null, filterResult) // Threat
        ];
    }

   // #if highMemory
    private function parsePolygons(chars, index, filterResult) {
        filterResult[1] = null; /* Filter operator */
        // The first value represents the total number of polygons
        var data = new [parse(1 /* NUMBER */, chars, index, filterResult) * 8];
        var dataIndex = 0;
        index = filterResult[0] + 1;
        while (dataIndex < data.size()) {
            data[dataIndex] = parse(1 /* NUMBER */, chars, index, filterResult);
            dataIndex++;
            index = filterResult[0] + 1;
        }

        return data;
    }
  // #endif
// #endif

    // <LightModes>(:<LightSerialNumber>)*(:<LightIconColor>)*
    private function parseLightInfo(chars, dataType, resultIndex) {
        var index = resultIndex[0];
        if (dataType > 0 && (index >= chars.size() || chars[index] == '#')) {
            return null;
        }

        var left = parse(1 /* NUMBER */, chars, null, resultIndex);
        if (left == null || dataType == 2 /* Icon color */) {
            return left;
        }

        var serial = dataType == 1;
        var result = (left.toLong() << (serial ? 31 : 32)) | parse(1 /* NUMBER */, chars, null, resultIndex); // TODO: Change this to 31 when making a major version change
        return serial
            ? result.toNumber()
            : result;
    }

    private function parse(type, chars, index, resultIndex) {
        index = index == null ? resultIndex[0] + 1 : index;
        var stringValue = null;
        var i;
        var isFloat = false;
        for (i = index; i < chars.size(); i++) {
            var char = chars[i];
            if (stringValue == null && char == ' ') {
                continue; // Trim leading spaces
            }

            if (char == '.') {
                isFloat = true;
            }

            if (char == ':' || char == '|' || char == '!' || (type == 1 /* NUMBER */ && (char == '/' || char > 57 /* 9 */ || char < 45 /* - */))) {
                break;
            }

            stringValue = stringValue == null ? char.toString() : stringValue + char;
        }

        resultIndex[0] = i;
        return stringValue == null || type == 0 ? stringValue
            : isFloat ? stringValue.toFloat()
            : stringValue.toNumber();
    }

    private function degToRad(angleDeg) {
        return 3.141593 * angleDeg / 180.0;
    }
}