package com.folony.activity.folony_activity

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val deviceLocationChannel = "folony_activity/device_location"
    private val locationLogTag = "FolonyLocation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceLocationChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "lastKnownLocation" -> resolveDeviceLocation(result)
                else -> result.notImplemented()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun resolveDeviceLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            Log.i(locationLogTag, "lastKnownLocation denied: no location permission")
            result.success(null)
            return
        }

        readLastKnownLocation()?.let {
            Log.i(locationLogTag, "lastKnownLocation cache hit: $it")
            result.success(it)
            return
        }

        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.NETWORK_PROVIDER,
            "fused",
            LocationManager.GPS_PROVIDER,
            LocationManager.PASSIVE_PROVIDER
        ).plus(manager.getProviders(true)).distinct().filter { provider ->
            try {
                manager.isProviderEnabled(provider)
            } catch (_: IllegalArgumentException) {
                false
            }
        }

        if (providers.isEmpty()) {
            Log.i(locationLogTag, "lastKnownLocation no enabled providers")
            result.success(null)
            return
        }

        Log.i(locationLogTag, "lastKnownLocation requesting providers=$providers")
        val handler = Handler(Looper.getMainLooper())
        var completed = false
        val listeners = mutableListOf<LocationListener>()

        fun finish(location: Location?) {
            if (completed) {
                return
            }
            completed = true
            listeners.forEach { listener ->
                try {
                    manager.removeUpdates(listener)
                } catch (_: SecurityException) {
                } catch (_: IllegalArgumentException) {
                }
            }
            result.success(location?.toPayload())
        }

        val timeout = Runnable {
            Log.i(locationLogTag, "lastKnownLocation timeout")
            finish(null)
        }
        handler.postDelayed(timeout, 5000L)

        providers.forEach { provider ->
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    Log.i(locationLogTag, "lastKnownLocation callback ${location.toPayload()}")
                    handler.removeCallbacks(timeout)
                    finish(location)
                }
            }
            listeners.add(listener)
            try {
                manager.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())
            } catch (_: SecurityException) {
                Log.i(locationLogTag, "lastKnownLocation security exception provider=$provider")
            } catch (_: IllegalArgumentException) {
                Log.i(locationLogTag, "lastKnownLocation illegal provider=$provider")
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun readLastKnownLocation(): Map<String, Any?>? {
        if (!hasLocationPermission()) {
            return null
        }

        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
            "fused"
        ).plus(manager.getProviders(true)).distinct()

        val best = providers
            .mapNotNull { provider ->
                try {
                    manager.getLastKnownLocation(provider)
                } catch (_: IllegalArgumentException) {
                    null
                } catch (_: SecurityException) {
                    null
                }
            }
            .maxWithOrNull(::compareLocationFreshness)
            ?: return null

        return best.toPayload()
    }

    private fun Location.toPayload(): Map<String, Any?> {
        return mapOf(
            "latitude" to latitude,
            "longitude" to longitude,
            "accuracy" to if (hasAccuracy()) accuracy.toDouble() else null,
            "age_ms" to maxOf(0L, System.currentTimeMillis() - time),
            "time" to time,
            "provider" to provider
        )
    }

    private fun compareLocationFreshness(left: Location, right: Location): Int {
        val timeCompare = left.time.compareTo(right.time)
        if (timeCompare != 0) {
            return timeCompare
        }

        val leftAccuracy = if (left.hasAccuracy()) left.accuracy else Float.MAX_VALUE
        val rightAccuracy = if (right.hasAccuracy()) right.accuracy else Float.MAX_VALUE
        return rightAccuracy.compareTo(leftAccuracy)
    }

    private fun hasLocationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }
}
