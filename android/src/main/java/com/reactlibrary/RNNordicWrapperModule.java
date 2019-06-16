
package com.reactlibrary;

import android.Manifest;
import android.bluetooth.BluetoothDevice;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.ParcelUuid;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.reactlibrary.profile.LoggableBleManager;
import com.reactlibrary.proximity.ProximityManager;
import com.reactlibrary.proximity.ProximityManagerCallbacks;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.UUID;

import no.nordicsemi.android.ble.BleManager;
import no.nordicsemi.android.ble.BleManagerCallbacks;
import no.nordicsemi.android.support.v18.scanner.BluetoothLeScannerCompat;
import no.nordicsemi.android.support.v18.scanner.ScanCallback;
import no.nordicsemi.android.support.v18.scanner.ScanFilter;
import no.nordicsemi.android.support.v18.scanner.ScanResult;
import no.nordicsemi.android.support.v18.scanner.ScanSettings;

public class RNNordicWrapperModule extends ReactContextBaseJavaModule implements ProximityManagerCallbacks {
    public static final String ON_DEVICE_ADDED = "ON_DEVICE_ADDED";
    public static final String ON_DEVICE_CONNECTION_ERROR = "ON_DEVICE_CONNECTION_ERROR";
    public static final String ON_RSSI_VALUE_CHANGED = "ON_RSSI_VALUE_CHANGED";
    public static final String ON_BATTERY_LEVEL_CHANGED = "ON_BATTERY_LEVEL_CHANGED";
    public static final String ON_DEVICE_CONNECTED = "ON_DEVICE_CONNECTED";
    public static final String ON_DEVICE_CONNECTING = "ON_DEVICE_CONNECTING";
    public static final String ON_DEVICE_DISCONNECTING = "ON_DEVICE_DISCONNECTING";
    public static final String ON_DEVICE_DISCONNECTED = "ON_DEVICE_DISCONNECTED";
    public static final String ON_DEVICE_OUT_OF_RANGE = "ON_DEVICE_OUT_OF_RANGE";
    public static final String ON_BEEP_CHANGED = "ON_BEEP_CHANGED";
    public static final String ON_CHANGE_IN_DEVICE = "ON_CHANGE_IN_DEVICE";
    public static final String ON_SET_UDID = "ON_SET_UDID";
    public static final String TAG = RNNordicWrapperModule.class.getName();
    final static UUID LINK_LOSS_SERVICE_UUID = UUID.fromString("00001803-0000-1000-8000-00805f9b34fb");
    private final static long SCAN_DURATION = 5000;
    private final ReactApplicationContext reactContext;
    private final List<ScanResult> mDevices = new ArrayList<>();
    private boolean mIsScanning = false;
    private Gson gson;
    private LoggableBleManager<? extends BleManagerCallbacks> mBleManager;
    private List<BluetoothDevice> mManagedDevices = new ArrayList<>();
    private HashMap<BluetoothDevice, BleManager> mBleManagers;


    private ScanCallback scanCallback = new ScanCallback() {
        @Override
        public void onScanResult(final int callbackType, final ScanResult result) {
            Log.d(TAG, "onScanResult");
        }

        @Override
        public void onBatchScanResults(final List<ScanResult> results) {
            final int size = mDevices.size();
            for (final ScanResult result : results) {
                String deviceStr = gson.toJson(result);
                if (!isAlreadyAdded(result)) {
                    mDevices.add(result);
                    sendInfoToRN(ON_DEVICE_ADDED, result.getDevice().getAddress(), deviceStr);
                    sendInfoToRN(ON_SET_UDID, result.getDevice().getAddress(), "" + LINK_LOSS_SERVICE_UUID);
                } else {
                    sendInfoToRN(ON_RSSI_VALUE_CHANGED, result.getDevice().getAddress(), "" + result.getRssi());
                }
            }
        }

        @Override
        public void onScanFailed(final int errorCode) {
            Log.d(TAG, "onScanFailed");
        }
    };

    public RNNordicWrapperModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        gson = new GsonBuilder().create();
        mBleManagers = new HashMap<>();
        mManagedDevices = new ArrayList<>();
    }

    boolean isAlreadyAdded(ScanResult result) {
        for (int i = 0; i < mDevices.size(); i++) {
            ScanResult scanResult = mDevices.get(i);
            if (scanResult.getDevice().getAddress().equalsIgnoreCase(result.getDevice().getAddress())) {
                mDevices.set(i, result);
                return true;
            }
        }
        return false;
    }

    @Override
    public String getName() {
        return "RNNordicWrapper";
    }

    @ReactMethod
    public void startScan(Callback callback) {
        // Since Android 6.0 we need to obtain either Manifest.permission.ACCESS_COARSE_LOCATION or Manifest.permission.ACCESS_FINE_LOCATION to be able to scan for
        // Bluetooth LE devices. This is related to beacons as proximity devices.
        // On API older than Marshmallow the following code does nothing.
        if (!Utility.isBluetoothEnbled(reactContext)) {
            callback.invoke(false);
            return;
        }

        if (ContextCompat.checkSelfPermission(reactContext, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            //When user pressed Deny and still wants to use this functionality, show the rationale
            if (ActivityCompat.shouldShowRequestPermissionRationale(getCurrentActivity(), Manifest.permission.ACCESS_COARSE_LOCATION)) {
                callback.invoke(false);
                Utility.showToast(reactContext, "Please enable permissions");
                return;
            }
            callback.invoke(false);
            getCurrentActivity().requestPermissions(new String[]{Manifest.permission.ACCESS_COARSE_LOCATION}, 100);
            return;
        }
        stopScan();

        // Hide the rationale message, we don't need it anymore.
     /*   if (mPermissionRationale != null)
            mPermissionRationale.setVisibility(View.GONE);

        mAdapter.clearDevices();
        mScanButton.setText(R.string.scanner_action_cancel);*/
        final BluetoothLeScannerCompat scanner = BluetoothLeScannerCompat.getScanner();
        final ScanSettings settings = new ScanSettings.Builder()
                .setLegacy(false)
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).setReportDelay(1000).setUseHardwareBatchingIfSupported(false).build();
        final List<ScanFilter> filters = new ArrayList<>();
        filters.add(new ScanFilter.Builder().setServiceUuid(new ParcelUuid(LINK_LOSS_SERVICE_UUID)).build());
        scanner.startScan(filters, settings, scanCallback);
        mIsScanning = true;
        new Handler().postDelayed(() -> {
            if (mIsScanning) {
                //   stopScan();
            }
        }, SCAN_DURATION);
        callback.invoke(true);
    }


    void sendDevicesToRN(List<ScanResult> results) {
        JsonArray resultsArray = gson.toJsonTree(results).getAsJsonArray();
        String resultString = resultsArray.toString();
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit("EVENT_TAG", resultString);
    }

    /**
     * Stop scan if user tap Cancel button
     */
    @ReactMethod
    public void stopScan() {
        if (mIsScanning) {
            try {
                final BluetoothLeScannerCompat scanner = BluetoothLeScannerCompat.getScanner();
                scanner.stopScan(scanCallback);
                mManagedDevices.clear();
                mIsScanning = false;
            } catch (Exception e) {

            }
        }
    }

    @ReactMethod
    public void showToast(Callback successCallBack) {
        try {
            Utility.showToast(reactContext, "Test callback");
        } catch (Exception e) {

        }
    }

    @ReactMethod
    public void connectDevice(final String deviceMacAddress) {
        BluetoothDevice bluetoothDevice = mDevices.get(0).getDevice();
        //mBleManager.setLogger(mLogSession);
        mBleManager.connect(bluetoothDevice)
                .useAutoConnect(false)
                .retry(3, 100)
                .enqueue();
    }

    @ReactMethod
    public void connectDevices(String macAddress) {
        final BluetoothDevice device = getDeviceFromMacAddress(macAddress);
        if (device == null) {
            Utility.showToast(reactContext, "Device not found");
            return;
        }
        if (mManagedDevices.contains(device))
            return;
        mManagedDevices.add(device);

        BleManager manager = mBleManagers.get(device);
        if (manager != null) {
          /*  if (session != null)
                manager.setLogger(session);*/
            manager.connect(device).enqueue();
        } else {
            mBleManagers.put(device, manager = initializeManager());
            manager.setGattCallbacks(this);
            //  manager.setLogger(session);
            manager.connect(device)
                    .fail((d, status) -> {
                        mManagedDevices.remove(device);
                        mBleManagers.remove(device);
                    })
                    .enqueue(10000);
        }
    }


    private BleManager initializeManager() {
        return new ProximityManager(reactContext);
    }

    @Override
    public void onDeviceConnecting(@NonNull BluetoothDevice device) {
        String deviceStr = gson.toJson(device);
        sendInfoToRN(ON_DEVICE_CONNECTING, device.getAddress(), deviceStr);
    }

    @Override
    public void onDeviceConnected(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "Device Connected");
        sendInfoToRN(ON_DEVICE_CONNECTED, device.getAddress(), null);
    }

    @Override
    public void onDeviceDisconnecting(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onDeviceDisconnecting");
        sendInfoToRN(ON_DEVICE_DISCONNECTING, device.getAddress(), null);
    }

    @Override
    public void onDeviceDisconnected(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onDeviceDisconnected");
        sendInfoToRN(ON_DEVICE_DISCONNECTED, device.getAddress(), null);
    }

    @Override
    public void onLinkLossOccurred(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onLinkLossOccurred");
        sendInfoToRN(ON_DEVICE_OUT_OF_RANGE, device.getAddress(), null);
    }

    @Override
    public void onServicesDiscovered(@NonNull BluetoothDevice device, boolean optionalServicesFound) {
        Utility.showToast(reactContext, "onServicesDiscovered");
    }

    @Override
    public void onDeviceReady(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onDeviceReady");
    }

    @Override
    public void onBondingRequired(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onBondingRequired");
    }

    @Override
    public void onBonded(@NonNull BluetoothDevice bluetoothDevice) {
        Utility.showToast(reactContext, "onBonded");
    }

    @Override
    public void onBondingFailed(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onBondingFailed");
    }

    @Override
    public void onError(@NonNull BluetoothDevice device, @NonNull String message, int errorCode) {
        Utility.showToast(reactContext, "onError: " + message);
    }

    @Override
    public void onDeviceNotSupported(@NonNull BluetoothDevice device) {
        Utility.showToast(reactContext, "onDeviceNotSupported");
    }


    @Override
    public void onBatteryLevelChanged(@NonNull BluetoothDevice device, int range) {
        // Utility.showToast(reactContext, "onBatteryLevelChanged");
        sendInfoToRN(ON_BATTERY_LEVEL_CHANGED, device.getAddress(), "" + range);
    }

    @Override
    public void onRemoteAlarmSwitched(@NonNull BluetoothDevice device, boolean on) {
        Utility.showToast(reactContext, "onRemoteAlarmSwitched: " + on);
    }


    private BluetoothDevice getDeviceFromMacAddress(String mAddress) {
        BluetoothDevice bluetoothDevice = null;
        if (null != mDevices && mDevices.size() > 0) {
            for (ScanResult deviceItem :
                    mDevices) {
                if (deviceItem.getDevice().getAddress().equalsIgnoreCase(mAddress)) {
                    return deviceItem.getDevice();
                }
            }
        }
        return bluetoothDevice;
    }

    @ReactMethod
    public void beep(String mAddress) {
        BluetoothDevice bluetoothDevice = getDeviceFromMacAddress(mAddress);
        if (null == bluetoothDevice) {
            Utility.showToast(reactContext, "Device not found");
            return;
        }
        BleManager manager = mBleManagers.get(bluetoothDevice);
        ProximityManager proximityManager = (ProximityManager) manager;
        proximityManager.toggleImmediateAlert();
    }

    @ReactMethod
    public void disconnectDevice(String mAddress) {
        BluetoothDevice bluetoothDevice = getDeviceFromMacAddress(mAddress);
        if (null == bluetoothDevice) {
            Utility.showToast(reactContext, "Device not found");
            return;
        }
        final BleManager<BleManagerCallbacks> manager = mBleManagers.get(bluetoothDevice);
        if (manager != null && manager.isConnected()) {
            manager.disconnect().enqueue();
            mManagedDevices.remove(bluetoothDevice);
            //sendDevicesToRN(mManagedDevices);
        }
        mManagedDevices.remove(bluetoothDevice);
    }


    @ReactMethod
    public void isConnected(String mAddress, Callback callback) {
        BluetoothDevice bluetoothDevice = getDeviceFromMacAddress(mAddress);
        if (null == bluetoothDevice) {
            callback.invoke(false);
            return;
        }
        final BleManager<BleManagerCallbacks> manager = mBleManagers.get(bluetoothDevice);
        if (manager != null) {
            callback.invoke(manager.isConnected());
            return;
        }
        callback.invoke(false);
    }

    @ReactMethod
    public void getBatteryLevel(String mAddress, Callback callback) {
        BluetoothDevice bluetoothDevice = getDeviceFromMacAddress(mAddress);
        if (null == bluetoothDevice) {
            Utility.showToast(reactContext, "Device not found");
            return;
        }
        BleManager manager = mBleManagers.get(bluetoothDevice);
        if (manager != null) {
            ProximityManager proximityManager = (ProximityManager) manager;
            Utility.showToast(reactContext, "Battery level: " + proximityManager.getBatteryLevel());
        } else {
            Utility.showToast(reactContext, "Battery level not found ");
        }
    }

    public void sendInfoToRN(final String type, String mAddress, String param) {
        WritableMap params = Arguments.createMap();
        params.putString("mAddress", mAddress);
        params.putString("param", param);
        params.putString("type", type);
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(ON_CHANGE_IN_DEVICE, params);
    }
}