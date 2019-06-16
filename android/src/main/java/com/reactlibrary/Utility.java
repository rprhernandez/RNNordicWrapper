package com.reactlibrary;

import android.bluetooth.BluetoothAdapter;
import android.content.Context;
import android.widget.Toast;

public class Utility {
    public static void showToast(Context context, String msg){
        Toast.makeText(context,""+msg, Toast.LENGTH_SHORT).show();
    }

    public static boolean isBluetoothEnbled(Context context){
        BluetoothAdapter mBluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (mBluetoothAdapter == null) {
            // Device does not support Bluetooth
            showToast(context, "Device does not support Bluetooth");
        } else {
            if (!mBluetoothAdapter.isEnabled()) {
                showToast(context, "Bluetooth is not enabled");
            }else{
                return true;
            }
        }
        return false;
    }
}
