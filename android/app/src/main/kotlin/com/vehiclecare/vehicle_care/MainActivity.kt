package com.vehiclecare.vehicle_care

import android.content.Intent
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /** The Dart call waiting on the location dialog's answer, if one is showing. */
    private var pendingLocationService: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestService" -> requestLocationService(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Asks Google Play services to switch location on in place — the system
     * dialog with an "OK" that turns it on without leaving the app.
     *
     * Answers `true` when location is on (already, or once the driver
     * accepts) and `false` when they decline. An error means this device has
     * no such dialog — no Play services, or a setting it cannot change — and
     * the Dart side falls back to opening the settings screen.
     */
    private fun requestLocationService(result: MethodChannel.Result) {
        if (pendingLocationService != null) {
            result.error("busy", "The location dialog is already showing", null)
            return
        }
        val request = LocationSettingsRequest.Builder()
            .addLocationRequest(
                LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 10_000L)
                    .build(),
            )
            // Offers "OK" rather than also a "never ask" the driver could
            // trip over on the one screen that needs location.
            .setAlwaysShow(true)
            .build()

        try {
            LocationServices.getSettingsClient(this)
                .checkLocationSettings(request)
                .addOnSuccessListener { result.success(true) }
                .addOnFailureListener { error ->
                    if (error !is ResolvableApiException) {
                        result.error("unavailable", error.message, null)
                        return@addOnFailureListener
                    }
                    try {
                        pendingLocationService = result
                        error.startResolutionForResult(this, REQUEST_LOCATION_SERVICE)
                    } catch (e: Exception) {
                        pendingLocationService = null
                        result.error("unavailable", e.message, null)
                    }
                }
        } catch (e: Exception) {
            result.error("unavailable", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_LOCATION_SERVICE) {
            pendingLocationService?.success(resultCode == RESULT_OK)
            pendingLocationService = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val LOCATION_CHANNEL = "vehicle_care/location_service"
        private const val REQUEST_LOCATION_SERVICE = 4711
    }
}
