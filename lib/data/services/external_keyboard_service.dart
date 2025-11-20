import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/external_keyboard_model.dart';

/// 外置键盘服务
/// 管理外置USB键盘设备的连接、授权和输入监听
class ExternalKeyboardService extends GetxService {
  static const MethodChannel _channel = MethodChannel(
    'com.holox.ailand_pos/external_keyboard',
  );

  // 已检测到的外置键盘列表
  final detectedKeyboards = <ExternalKeyboardDevice>[].obs;

  // 当前选中的键盘
  final Rx<ExternalKeyboardDevice?> selectedKeyboard =
      Rx<ExternalKeyboardDevice?>(null);

  // 键盘状态
  final Rx<ExternalKeyboardStatus> keyboardStatus =
      ExternalKeyboardStatus.notConnected.obs;

  // 是否正在扫描设备
  final isScanning = false.obs;

  // 键盘输入测试数据
  final keyboardInputData = ''.obs;

  // 测试输出数据（用于显示测试结果）
  final testOutputData = ''.obs;

  // 是否正在测试输出
  final isTesting = false.obs;

  // 测试是否成功（用于显示动画）
  final testSuccess = false.obs;

  // 最后一次错误信息
  final Rx<String?> lastError = Rx<String?>(null);

  // 调试日志
  final debugLogs = <String>[].obs;

  // 调试日志面板是否展开
  final debugLogExpanded = false.obs;

  // 最新接入的设备ID（用于高亮显示）
  final Rx<String?> latestDeviceId = Rx<String?>(null);

  // 全局授权状态（应用级别，一次授权全局有效）
  final isGloballyAuthorized = false.obs;

  // 键盘输入回调列表（供业务模块注册）
  final List<Function(String)> _inputCallbacks = [];

  /// 初始化服务
  Future<ExternalKeyboardService> init() async {
    _addLog('========== 初始化外置键盘服务 ==========');

    if (kIsWeb) {
      _addLog('Web平台：跳过外置键盘初始化');
      return this;
    }

    try {
      // 设置USB设备连接/断开监听
      _channel.setMethodCallHandler(_handleNativeCallback);
      _addLog('✓ 已设置USB设备监听');

      // 初始扫描一次USB设备
      await scanUsbKeyboards();

      // 执行全局授权（应用启动时自动授权）
      await initGlobalAuthorization();

      _addLog('========== 初始化完成 ==========');
      return this;
    } catch (e, stackTrace) {
      _addLog('✗ 初始化失败: $e');
      _addLog('堆栈: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      return this;
    }
  }

  /// 全局授权初始化（应用启动时执行）
  /// 一次授权，全局有效，所有文本框都能使用物理键盘
  Future<void> initGlobalAuthorization() async {
    if (isGloballyAuthorized.value) {
      _addLog('⚠ 已完成全局授权，跳过');
      return;
    }

    _addLog('开始全局键盘授权...');

    try {
      // 扫描可用设备
      await scanUsbKeyboards();

      if (detectedKeyboards.isEmpty) {
        _addLog('⚠ 未检测到键盘设备，授权延迟');
        return;
      }

      // 选择第一个设备进行授权
      final firstDevice = detectedKeyboards.first;
      selectedKeyboard.value = firstDevice;
      _addLog('选择设备: ${firstDevice.productName}');

      // 请求权限
      final result = await _channel.invokeMethod('requestPermission', {
        'deviceId': firstDevice.deviceId,
      });

      if (result == true) {
        isGloballyAuthorized.value = true;
        keyboardStatus.value = ExternalKeyboardStatus.connected;
        _addLog('✓ 全局授权成功！所有文本框可使用物理键盘');

        // 启动全局输入监听
        await startListening();
      } else {
        _addLog('✗ 用户拒绝授权');
        lastError.value = '用户拒绝键盘授权';
      }
    } catch (e) {
      _addLog('✗ 全局授权失败: $e');
      lastError.value = '授权失败: $e';
    }
  }

  /// 处理来自原生端的回调
  Future<dynamic> _handleNativeCallback(MethodCall call) async {
    _addLog('收到原生回调: ${call.method}');

    switch (call.method) {
      case 'onUsbDeviceAttached':
        _addLog('USB设备已连接');
        await scanUsbKeyboards();
        break;

      case 'onUsbDeviceDetached':
        _addLog('USB设备已断开');
        await scanUsbKeyboards();
        break;

      case 'onKeyboardInput':
        final input = call.arguments as String?;
        if (input != null) {
          _handleKeyboardInput(input);
        }
        break;

      default:
        _addLog('未知回调方法: ${call.method}');
    }
  }

  /// 扫描USB键盘设备
  Future<void> scanUsbKeyboards() async {
    if (isScanning.value) {
      _addLog('正在扫描中，跳过重复扫描');
      return;
    }

    isScanning.value = true;
    lastError.value = null;
    _addLog('开始扫描USB键盘设备...');

    try {
      final result = await _channel.invokeMethod('scanUsbKeyboards');
      _addLog('扫描结果: $result');

      if (result is List) {
        final List<ExternalKeyboardDevice> newDevices = result
            .map((device) => ExternalKeyboardDevice.fromJson(
                  Map<String, dynamic>.from(device),
                ))
            .toList();

        _addLog('发现 ${newDevices.length} 个键盘设备');

        // 检测新接入的设备
        final oldDeviceIds =
            detectedKeyboards.map((d) => d.deviceId).toSet();
        final newDeviceIds = newDevices.map((d) => d.deviceId).toSet();
        final addedDeviceIds = newDeviceIds.difference(oldDeviceIds);

        if (addedDeviceIds.isNotEmpty) {
          latestDeviceId.value = addedDeviceIds.first;
          _addLog('新设备: ${addedDeviceIds.first}');
        }

        detectedKeyboards.value = newDevices;

        // 自动选择第一个已连接的设备
        if (selectedKeyboard.value == null && newDevices.isNotEmpty) {
          final connectedDevice =
              newDevices.firstWhereOrNull((d) => d.isConnected);
          if (connectedDevice != null) {
            selectedKeyboard.value = connectedDevice;
            keyboardStatus.value = ExternalKeyboardStatus.connected;
            _addLog('自动选择设备: ${connectedDevice.deviceName}');
          }
        }

        // 更新选中设备的状态
        if (selectedKeyboard.value != null) {
          final currentDevice = newDevices.firstWhereOrNull(
            (d) => d.deviceId == selectedKeyboard.value!.deviceId,
          );
          if (currentDevice != null) {
            selectedKeyboard.value = currentDevice;
            keyboardStatus.value = currentDevice.isConnected
                ? ExternalKeyboardStatus.connected
                : ExternalKeyboardStatus.notConnected;
          } else {
            // 设备已断开
            selectedKeyboard.value = null;
            keyboardStatus.value = ExternalKeyboardStatus.notConnected;
            _addLog('选中的设备已断开');
          }
        }
      } else {
        _addLog('✗ 扫描结果格式错误');
      }
    } catch (e, stackTrace) {
      _addLog('✗ 扫描失败: $e');
      _addLog('堆栈: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      lastError.value = '扫描失败: $e';
    } finally {
      isScanning.value = false;
    }
  }

  /// 请求设备授权
  Future<bool> requestPermission(ExternalKeyboardDevice device) async {
    _addLog('请求设备授权: ${device.deviceName}');
    lastError.value = null;

    try {
      final result = await _channel.invokeMethod(
        'requestPermission',
        {'deviceId': device.deviceId},
      );

      if (result == true) {
        _addLog('✓ 授权成功');
        keyboardStatus.value = ExternalKeyboardStatus.authorized;
        await scanUsbKeyboards(); // 刷新设备列表
        return true;
      } else {
        _addLog('✗ 授权被拒绝');
        lastError.value = '用户拒绝授权';
        return false;
      }
    } catch (e, stackTrace) {
      _addLog('✗ 授权失败: $e');
      _addLog('堆栈: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      lastError.value = '授权失败: $e';
      return false;
    }
  }

  /// 开始监听键盘输入
  void startListening() {
    if (selectedKeyboard.value == null) {
      _addLog('未选择键盘设备');
      return;
    }

    _addLog('开始监听键盘输入...');
    keyboardStatus.value = ExternalKeyboardStatus.testing;
    keyboardInputData.value = '';
  }

  /// 停止监听键盘输入
  void stopListening() {
    _addLog('停止监听键盘输入');
    keyboardStatus.value = ExternalKeyboardStatus.connected;
  }

  /// 处理键盘输入
  void _handleKeyboardInput(String input) {
    _addLog('收到键盘输入: $input');
    keyboardInputData.value += input;
    
    // 通知所有已注册的业务模块监听器
    _notifyInputListeners(input);
  }

  /// 清除输入数据
  void clearInputData() {
    keyboardInputData.value = '';
    _addLog('清除输入数据');
  }

  /// 添加调试日志
  void _addLog(String message) {
    final timestamp = DateTime.now();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
    debugLogs.insert(0, '[$timeStr] $message');

    // 限制日志数量
    if (debugLogs.length > 100) {
      debugLogs.removeRange(100, debugLogs.length);
    }

    if (kDebugMode) {
      print('[ExternalKeyboardService] $message');
    }
  }

  /// 清空日志
  void clearLogs() {
    debugLogs.clear();
    _addLog('日志已清空');
  }

  /// 开始测试输出
  void startTestOutput() {
    if (selectedKeyboard.value == null) {
      lastError.value = '请先选择一个键盘设备';
      _addLog('❌ 测试失败：未选择设备');
      return;
    }

    isTesting.value = true;
    testOutputData.value = '';
    testSuccess.value = false;
    _addLog('✓ 开始测试输出');

    // 监听键盘输入数据变化
    ever(keyboardInputData, (value) {
      if (isTesting.value && value.isNotEmpty) {
        testOutputData.value = value;
        testSuccess.value = true;
        _addLog('✓ 接收到数据: $value');
        
        // 3秒后自动隐藏成功动画
        Future.delayed(const Duration(seconds: 3), () {
          if (testSuccess.value) {
            testSuccess.value = false;
          }
        });
      }
    });
  }

  /// 停止测试输出
  void stopTestOutput() {
    isTesting.value = false;
    testSuccess.value = false;
    _addLog('⚠ 停止测试输出');
  }

  // ==================== 通用键盘输入API（供业务模块使用） ====================

  /// 注册键盘输入监听器
  /// 业务模块调用此方法注册回调函数，接收键盘输入数据
  /// 
  /// 使用示例：
  /// ```dart
  /// final service = Get.find<ExternalKeyboardService>();
  /// service.registerInputListener((data) {
  ///   print('收到键盘输入: $data');
  ///   // 处理业务逻辑
  /// });
  /// ```
  void registerInputListener(Function(String) callback) {
    if (!_inputCallbacks.contains(callback)) {
      _inputCallbacks.add(callback);
      _addLog('✓ 注册输入监听器（当前: ${_inputCallbacks.length}个）');
    }
  }

  /// 注销键盘输入监听器
  /// 业务模块在dispose时调用，避免内存泄漏
  /// 
  /// 使用示例：
  /// ```dart
  /// @override
  /// void dispose() {
  ///   service.unregisterInputListener(myCallback);
  ///   super.dispose();
  /// }
  /// ```
  void unregisterInputListener(Function(String) callback) {
    _inputCallbacks.remove(callback);
    _addLog('✓ 注销输入监听器（剩余: ${_inputCallbacks.length}个）');
  }

  /// 触发所有注册的输入回调
  /// 当接收到键盘输入时，自动调用所有已注册的回调函数
  void _notifyInputListeners(String data) {
    if (_inputCallbacks.isEmpty) return;
    
    _addLog('通知 ${_inputCallbacks.length} 个监听器: $data');
    for (final callback in _inputCallbacks) {
      try {
        callback(data);
      } catch (e) {
        _addLog('✗ 回调执行失败: $e');
      }
    }
  }

  /// 检查是否已完成全局授权
  /// 业务模块可以通过此方法判断键盘是否可用
  bool get isKeyboardReady => isGloballyAuthorized.value && 
                              keyboardStatus.value == ExternalKeyboardStatus.connected;

  /// 获取当前键盘连接状态（供业务模块查询）
  ExternalKeyboardStatus get currentStatus => keyboardStatus.value;

  /// 手动触发授权（供业务模块在需要时调用）
  /// 如果应用启动时未检测到设备，业务模块可以手动触发授权
  Future<bool> requestAuthorizationIfNeeded() async {
    if (isGloballyAuthorized.value) {
      _addLog('⚠ 已完成授权，无需重复请求');
      return true;
    }

    await initGlobalAuthorization();
    return isGloballyAuthorized.value;
  }

  @override
  void onClose() {
    _inputSubscription?.cancel();
    super.onClose();
  }
}
