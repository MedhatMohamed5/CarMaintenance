package com.vehiclecare.vehicle_care

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACKGROUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    "requestIgnoreBatteryOptimizations" ->
                        result.success(requestIgnoreBatteryOptimizations())
                    "hasAutoStart" -> result.success(firstResolvable(autoStartIntents()) != null)
                    "openAutoStart" -> result.success(startFirst(autoStartIntents()))
                    "hasPowerSaving" -> result.success(firstResolvable(powerSavingIntents()) != null)
                    "openPowerSaving" -> result.success(startFirst(powerSavingIntents()))
                    else -> result.notImplemented()
                }
            }
    }

    // ---- background reliability ------------------------------------------
    //
    // Replaces the disable_battery_optimization package, whose build script
    // still called jcenter() - removed in Gradle 9 - and whose dialogs needed
    // a pre-AndroidX library that kept Jetifier on. The screens below are the
    // ones that package opened, kept as data: Android's own battery
    // optimisation request, which is documented and always works, and the
    // manufacturers' autostart and battery-saver screens, which are not and
    // move between firmware versions - so each is tried in order and the
    // first this device actually has is used. Their packages are declared in
    // the manifest's <queries>, or Android 11+ would hide them.

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(POWER_SERVICE) as? PowerManager ?: return false
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    /** Android's own "allow in the background?" dialog, else its list screen. */
    private fun requestIgnoreBatteryOptimizations(): Boolean = startFirst(
        listOf(
            Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName"),
            ),
            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
        ),
    )

    private fun autoStartIntents(): List<Intent> = listOf(
        // Xiaomi / Redmi / POCO
        component("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        // Oppo / Realme
        component("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        component("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
        component("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
        component("com.color.safecenter", "com.color.safecenter.permission.startup.StartupAppListActivity"),
        component("com.color.safecenter", "com.color.safecenter.startupapp.StartupAppListActivity"),
        // Vivo / iQOO
        component("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"),
        component("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
        component("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        // Huawei / Honor
        component("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        component("com.huawei.systemmanager", "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity"),
        component("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.bootstart.BootStartActivity"),
        Intent("huawei.intent.action.HSM_BOOTAPP_MANAGER"),
        // OnePlus
        component("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
        component("com.oneplus.security", "com.oneplus.security.autorun.AutorunMainActivity"),
        // Samsung (older firmware), Asus, ZTE
        component("com.samsung.memorymanager", "com.samsung.memorymanager.RamActivity"),
        component("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"),
        component("com.zte.heartyservice", "com.zte.heartyservice.autorun.AppAutoRunManager"),
    )

    private fun powerSavingIntents(): List<Intent> = listOf(
        // Xiaomi: the per-app "no restrictions" switch.
        component("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
            .putExtra("package_name", packageName)
            .putExtra("package_label", applicationInfo.loadLabel(packageManager).toString()),
        // Oppo / Realme
        component("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerConsumptionActivity"),
        component("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"),
        component("com.color.oppoguardelf", "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity"),
        // Vivo
        component("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"),
        // Huawei / Honor
        Intent("huawei.intent.action.HSM_PROTECTED_APPS"),
        component("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
        // OnePlus
        component("com.oneplus.security", "com.oneplus.security.highpowerapp.view.HighPowerAppActivity"),
        component("com.oneplus.security", "com.oneplus.security.cleanbackground.view.ManageBackgroundAppListActivity"),
        // Samsung
        Intent("com.samsung.android.sm.ACTION_BATTERY"),
        component("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
        component("com.samsung.android.sm_cn", "com.samsung.android.sm.ui.battery.BatteryActivity"),
        component("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity"),
        // HTC, ZTE
        component("com.htc.pitroad", "com.htc.pitroad.landingpage.activity.LandingPageActivity"),
        component("com.zte.heartyservice", "com.zte.heartyservice.setting.ClearAppSettingsActivity"),
    )

    private fun component(pkg: String, cls: String): Intent =
        Intent().setComponent(ComponentName(pkg, cls))

    private fun firstResolvable(intents: List<Intent>): Intent? =
        intents.firstOrNull { it.resolveActivity(packageManager) != null }

    /**
     * Starts the first of [intents] this device can open. A manufacturer's
     * screen can resolve and still refuse to start - Oppo's want a permission
     * of their own, some are not exported - so a refusal moves on to the next.
     */
    private fun startFirst(intents: List<Intent>): Boolean {
        for (intent in intents) {
            if (intent.resolveActivity(packageManager) == null) continue
            try {
                startActivity(intent)
                return true
            } catch (ignored: Exception) {
                continue
            }
        }
        return false
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
        private const val BACKGROUND_CHANNEL = "vehicle_care/background"
        private const val REQUEST_LOCATION_SERVICE = 4711
    }
}
