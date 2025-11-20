package com.holox.ailand_pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * 外置USB键盘插件
 * 支持USB HID键盘设备的实时输入监听
 * 原理：监听系统键盘事件，实时发送字符到Flutter层
 */
class ExternalKeyboardPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var usbManager: UsbManager? = null
    
    // 是否正在监听键盘输入
    private var isListening = false
    
    companion object {
        private const val TAG = "ExternalKeyboard"
        private const val CHANNEL_NAME = "com.holox.ailand_pos/external_keyboard"
        private const val ACTION_USB_PERMISSION = "com.holox.ailand_pos.USB_KEYBOARD_PERMISSION"
        
        // USB HID设备类代码
        private const val USB_CLASS_HID = 3  // Human Interface Device
        private const val USB_SUBCLASS_BOOT = 1  // Boot Interface Subclass
        private const val USB_PROTOCOL_KEYBOARD = 1  // Keyboard Protocol
        
        /**
         * 常见USB键盘厂商ID列表
         */
        private val KNOWN_KEYBOARD_VENDORS = listOf(
            0x046d,  // Logitech (罗技)
            0x045e,  // Microsoft (微软)
            0x04f2,  // Chicony Electronics (群光)
            0x413c,  // Dell
            0x04d9,  // Holtek Semiconductor (合泰半导体)
            0x1c4f,  // SiGma Micro (矽微半导体)
            0x258a,  // SINO WEALTH (中颖电子)
            0x05ac,  // Apple
            0x04ca,  // Lite-On Technology (建兴)
            0x1a2c,  // China Resource Semico (华润矽威)
            0x062a,  // MosArt Semiconductor (部分键盘)
            0x24ae,  // Shenzhen Rapoo Technology (雷柏)
            0x0c45,  // Microdia (部分键盘)
        )
    }
    
    // USB权限接收器
    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    synchronized(this) {
                        val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                        }
                        
                        if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                            device?.let {
                                Log.d(TAG, "USB permission granted for device: ${it.deviceName}")
                                channel.invokeMethod("onPermissionGranted", mapOf(
                                    "deviceId" to it.deviceName,
                                    "deviceName" to (it.productName ?: it.deviceName)
                                ))
                            }
                        } else {
                            Log.d(TAG, "USB permission denied for device: ${device?.deviceName}")
                            channel.invokeMethod("onPermissionDenied", mapOf(
                                "deviceId" to device?.deviceName
                            ))
                        }
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    Log.d(TAG, "USB device attached: ${device?.deviceName}")
                    channel.invokeMethod("onDeviceAttached", null)
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    Log.d(TAG, "USB device detached: ${device?.deviceName}")
                    channel.invokeMethod("onDeviceDetached", null)
                }
            }
        }
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        usbManager = context?.getSystemService(Context.USB_SERVICE) as? UsbManager
        
        // 注册USB广播接收器
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context?.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context?.registerReceiver(usbReceiver, filter)
        }
        
        Log.d(TAG, "ExternalKeyboardPlugin attached")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        try {
            context?.unregisterReceiver(usbReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        
        context = null
        usbManager = null
        Log.d(TAG, "ExternalKeyboardPlugin detached")
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "scanUsbKeyboards" -> scanUsbKeyboards(result)
            "requestPermission" -> requestPermission(call, result)
            "startListening" -> startListening(result)
            "stopListening" -> stopListening(result)
            else -> result.notImplemented()
        }
    }
    
    /**
     * 扫描USB键盘设备
     */
    private fun scanUsbKeyboards(result: Result) {
        try {
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val keyboardDevices = mutableListOf<Map<String, Any>>()
            
            Log.d(TAG, "Scanning USB devices, found ${deviceList.size} total devices")
            
            for (device in deviceList.values) {
                Log.d(TAG, "Checking device: ${device.deviceName} (VID: 0x${Integer.toHexString(device.vendorId)}, PID: 0x${Integer.toHexString(device.productId)})")
                
                // 检查设备是否为HID键盘
                if (isKeyboardDevice(device)) {
                    val hasPermission = usbManager?.hasPermission(device) ?: false
                    
                    val deviceInfo = hashMapOf<String, Any>(
                        "deviceId" to device.deviceName,
                        "deviceName" to (device.productName ?: "USB Keyboard"),
                        "vendorId" to device.vendorId,
                        "productId" to device.productId,
                        "isConnected" to hasPermission,
                        "manufacturerName" to (device.manufacturerName ?: "Unknown"),
                        "serialNumber" to (device.serialNumber ?: "N/A")
                    )
                    
                    keyboardDevices.add(deviceInfo)
                    Log.d(TAG, "Found keyboard device: ${deviceInfo["deviceName"]} (Permission: $hasPermission)")
                }
            }
            
            Log.d(TAG, "Scan complete, found ${keyboardDevices.size} keyboard devices")
            result.success(keyboardDevices)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error scanning keyboards: ${e.message}", e)
            result.error("SCAN_ERROR", "Failed to scan USB keyboards: ${e.message}", null)
        }
    }
    
    /**
     * 检查设备是否为键盘
     */
    private fun isKeyboardDevice(device: UsbDevice): Boolean {
        // 方法1：检查USB类型
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            if (usbInterface.interfaceClass == USB_CLASS_HID) {
                // HID设备，进一步检查协议
                if (usbInterface.interfaceSubclass == USB_SUBCLASS_BOOT && 
                    usbInterface.interfaceProtocol == USB_PROTOCOL_KEYBOARD) {
                    Log.d(TAG, "Device ${device.deviceName} matched by HID protocol")
                    return true
                }
                // 有些键盘不严格遵循Boot协议，只要是HID就认为可能是键盘
                Log.d(TAG, "Device ${device.deviceName} is HID device (subclass: ${usbInterface.interfaceSubclass}, protocol: ${usbInterface.interfaceProtocol})")
            }
        }
        
        // 方法2：检查厂商ID
        if (device.vendorId in KNOWN_KEYBOARD_VENDORS) {
            Log.d(TAG, "Device ${device.deviceName} matched by known vendor ID")
            return true
        }
        
        // 方法3：检查产品名称
        val productName = device.productName?.lowercase() ?: ""
        if (productName.contains("keyboard") || productName.contains("kbd")) {
            Log.d(TAG, "Device ${device.deviceName} matched by product name")
            return true
        }
        
        return false
    }
    
    /**
     * 请求USB权限
     */
    private fun requestPermission(call: MethodCall, result: Result) {
        try {
            val deviceId = call.argument<String>("deviceId")
            if (deviceId == null) {
                result.error("INVALID_ARGUMENT", "Device ID is required", null)
                return
            }
            
            val device = findDeviceById(deviceId)
            if (device == null) {
                result.error("DEVICE_NOT_FOUND", "Device not found: $deviceId", null)
                return
            }
            
            val permissionIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(ACTION_USB_PERMISSION),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    PendingIntent.FLAG_MUTABLE
                } else {
                    0
                }
            )
            
            usbManager?.requestPermission(device, permissionIntent)
            Log.d(TAG, "Requesting permission for device: ${device.deviceName}")
            result.success(true)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permission: ${e.message}", e)
            result.error("PERMISSION_ERROR", "Failed to request permission: ${e.message}", null)
        }
    }
    
    /**
     * 开始监听键盘输入
     */
    private fun startListening(result: Result) {
        isListening = true
        Log.d(TAG, "Keyboard listening started")
        result.success(true)
    }
    
    /**
     * 停止监听键盘输入
     */
    private fun stopListening(result: Result) {
        isListening = false
        Log.d(TAG, "Keyboard listening stopped")
        result.success(true)
    }
    
    /**
     * 直接处理键盘事件（从MainActivity调用）
     * 返回true表示事件已处理，false表示需要系统继续处理
     */
    fun handleKeyEventDirect(event: KeyEvent): Boolean {
        // 只处理按键按下事件
        if (event.action != KeyEvent.ACTION_DOWN) {
            return false
        }
        
        // 如果未在监听状态，不拦截事件
        if (!isListening) {
            return false
        }
        
        // 获取字符
        val char = getCharFromKeyEvent(event)
        if (char != null) {
            // 实时发送字符到Flutter层
            channel.invokeMethod("onKeyboardInput", char.toString())
            Log.d(TAG, "Key captured: ${event.keyCode} -> '$char'")
            return true  // 拦截该按键
        }
        
        // 处理特殊按键（回车、退格等）
        when (event.keyCode) {
            KeyEvent.KEYCODE_ENTER -> {
                channel.invokeMethod("onKeyboardInput", "\n")
                Log.d(TAG, "Enter key captured")
                return true
            }
            KeyEvent.KEYCODE_DEL -> {
                channel.invokeMethod("onKeyboardInput", "\b")  // 退格符
                Log.d(TAG, "Backspace key captured")
                return true
            }
        }
        
        // 未识别的按键，让系统继续处理
        return false
    }
    
    /**
     * 从KeyEvent获取字符（支持Shift修饰键）
     */
    private fun getCharFromKeyEvent(event: KeyEvent): Char? {
        val keyCode = event.keyCode
        val metaState = event.metaState
        val isShiftPressed = (metaState and KeyEvent.META_SHIFT_ON) != 0
        
        return when (keyCode) {
            // 数字键
            in KeyEvent.KEYCODE_0..KeyEvent.KEYCODE_9 -> {
                if (isShiftPressed) {
                    // Shift + 数字 = 符号
                    when (keyCode) {
                        KeyEvent.KEYCODE_1 -> '!'
                        KeyEvent.KEYCODE_2 -> '@'
                        KeyEvent.KEYCODE_3 -> '#'
                        KeyEvent.KEYCODE_4 -> '$'
                        KeyEvent.KEYCODE_5 -> '%'
                        KeyEvent.KEYCODE_6 -> '^'
                        KeyEvent.KEYCODE_7 -> '&'
                        KeyEvent.KEYCODE_8 -> '*'
                        KeyEvent.KEYCODE_9 -> '('
                        KeyEvent.KEYCODE_0 -> ')'
                        else -> null
                    }
                } else {
                    ('0'.code + (keyCode - KeyEvent.KEYCODE_0)).toChar()
                }
            }
            // 字母键
            in KeyEvent.KEYCODE_A..KeyEvent.KEYCODE_Z -> {
                val baseChar = 'a'.code + (keyCode - KeyEvent.KEYCODE_A)
                if (isShiftPressed) {
                    baseChar.toChar().uppercaseChar()
                } else {
                    baseChar.toChar()
                }
            }
            // 空格
            KeyEvent.KEYCODE_SPACE -> ' '
            // 标点符号
            KeyEvent.KEYCODE_MINUS -> if (isShiftPressed) '_' else '-'
            KeyEvent.KEYCODE_EQUALS -> if (isShiftPressed) '+' else '='
            KeyEvent.KEYCODE_LEFT_BRACKET -> if (isShiftPressed) '{' else '['
            KeyEvent.KEYCODE_RIGHT_BRACKET -> if (isShiftPressed) '}' else ']'
            KeyEvent.KEYCODE_BACKSLASH -> if (isShiftPressed) '|' else '\\'
            KeyEvent.KEYCODE_SEMICOLON -> if (isShiftPressed) ':' else ';'
            KeyEvent.KEYCODE_APOSTROPHE -> if (isShiftPressed) '"' else '\''
            KeyEvent.KEYCODE_COMMA -> if (isShiftPressed) '<' else ','
            KeyEvent.KEYCODE_PERIOD -> if (isShiftPressed) '>' else '.'
            KeyEvent.KEYCODE_SLASH -> if (isShiftPressed) '?' else '/'
            KeyEvent.KEYCODE_GRAVE -> if (isShiftPressed) '~' else '`'
            else -> null
        }
    }
    
    /**
     * 根据设备ID查找设备
     */
    private fun findDeviceById(deviceId: String): UsbDevice? {
        val deviceList = usbManager?.deviceList ?: return null
        return deviceList.values.find { it.deviceName == deviceId }
    }
}
