package com.holox.ailand_pos

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Bundle
import android.view.WindowManager
import android.view.KeyEvent
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var barcodeScannerPlugin: BarcodeScannerPlugin? = null
    private var externalKeyboardPlugin: ExternalKeyboardPlugin? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 设置窗口为全屏模式（隐藏状态栏和导航栏）
        window.setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 注册 Sunmi Customer API Plugin（内置打印机）
        flutterEngine.plugins.add(SunmiCustomerApiPlugin())
        
        // 注册 External Printer Plugin（外接USB打印机）
        flutterEngine.plugins.add(ExternalPrinterPlugin())
        
        // 注册 External Card Reader Plugin（外接USB读卡器）
        flutterEngine.plugins.add(ExternalCardReaderPlugin())
        
        // 注册 Barcode Scanner Plugin（USB条码扫描器）
        barcodeScannerPlugin = BarcodeScannerPlugin()
        flutterEngine.plugins.add(barcodeScannerPlugin!!)
        
        // 注册 External Keyboard Plugin（外接USB键盘）
        externalKeyboardPlugin = ExternalKeyboardPlugin()
        flutterEngine.plugins.add(externalKeyboardPlugin!!)
    }
    
    /**
     * 拦截系统键盘事件，转发给对应插件
     * 优先级：外置键盘 > 条码扫描器 > 系统处理
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        // 优先让外置键盘插件处理（测试模式时拦截）
        externalKeyboardPlugin?.let { plugin ->
            if (plugin.handleKeyEventDirect(event)) {
                return true  // 事件已被键盘处理，拦截
            }
        }
        
        // 然后尝试让条码扫描器插件处理
        barcodeScannerPlugin?.let { plugin ->
            if (plugin.handleKeyEventDirect(event)) {
                return true  // 事件已被扫描器处理，拦截
            }
        }
        
        // 否则让系统正常处理
        return super.dispatchKeyEvent(event)
    }
}
