# 外置键盘服务 - 业务模块使用指南

## 📋 目录

1. [功能概述](#功能概述)
2. [全局授权机制](#全局授权机制)
3. [业务模块集成](#业务模块集成)
4. [API 参考](#api-参考)
5. [完整示例](#完整示例)
6. [常见问题](#常见问题)

---

## 🎯 功能概述

外置键盘服务（ExternalKeyboardService）提供了**全局键盘授权**和**通用输入监听**功能：

### ✅ 核心特性

- **一次授权，全局有效**：应用启动时自动请求权限，所有页面可直接使用
- **通用输入接口**：业务模块通过简单的API接收键盘输入
- **多监听器支持**：多个模块可同时监听键盘输入
- **自动生命周期管理**：提供注册/注销机制，避免内存泄漏
- **实时状态查询**：随时检查键盘连接和授权状态

---

## 🔐 全局授权机制

### 工作原理

```dart
// 应用启动时自动执行（main.dart）
Future<void> initServices() async {
  // ...
  // 预先初始化外置键盘服务（全局单例，自动授权）
  await Get.putAsync(() => ExternalKeyboardService().init());
}
```

### 授权流程

```
应用启动
   ↓
扫描USB键盘设备
   ↓
自动选择第一个设备
   ↓
请求系统权限（弹窗）
   ↓
用户授权 → 全局生效
   ↓
开启输入监听
   ↓
所有文本框可用 ✅
```

### 优势

- ❌ **旧方式**：每个页面都要 `requestPermission()` → 用户体验差
- ✅ **新方式**：启动时授权一次 → 全局所有页面直接可用

---

## 🔌 业务模块集成

### 基础集成（3步搞定）

#### Step 1: 获取服务实例

```dart
class MyBusinessController extends GetxController {
  late final ExternalKeyboardService _keyboardService;
  
  @override
  void onInit() {
    super.onInit();
    _keyboardService = Get.find<ExternalKeyboardService>();
  }
}
```

#### Step 2: 注册输入监听

```dart
@override
void onInit() {
  super.onInit();
  _keyboardService = Get.find<ExternalKeyboardService>();
  
  // 注册监听器
  _keyboardService.registerInputListener(_onKeyboardInput);
}

// 处理键盘输入
void _onKeyboardInput(String data) {
  print('收到键盘输入: $data');
  // TODO: 处理业务逻辑
}
```

#### Step 3: 注销监听器（重要！）

```dart
@override
void onClose() {
  // 避免内存泄漏
  _keyboardService.unregisterInputListener(_onKeyboardInput);
  super.onClose();
}
```

---

## 📚 API 参考

### 核心方法

#### 1. `registerInputListener(callback)`

注册键盘输入监听器

```dart
void registerInputListener(Function(String) callback)
```

**参数：**
- `callback`: 接收键盘输入数据的回调函数

**示例：**
```dart
_keyboardService.registerInputListener((data) {
  print('收到数据: $data');
});
```

---

#### 2. `unregisterInputListener(callback)`

注销键盘输入监听器

```dart
void unregisterInputListener(Function(String) callback)
```

**参数：**
- `callback`: 要移除的回调函数引用

**示例：**
```dart
@override
void onClose() {
  _keyboardService.unregisterInputListener(_onKeyboardInput);
  super.onClose();
}
```

---

#### 3. `isKeyboardReady`

检查键盘是否就绪（已授权且已连接）

```dart
bool get isKeyboardReady
```

**返回值：** `true` = 键盘可用，`false` = 不可用

**示例：**
```dart
if (_keyboardService.isKeyboardReady) {
  print('键盘已就绪，可以接收输入');
} else {
  print('键盘未连接或未授权');
}
```

---

#### 4. `currentStatus`

获取当前键盘连接状态

```dart
ExternalKeyboardStatus get currentStatus
```

**返回值：** 
- `ExternalKeyboardStatus.notConnected` - 未连接
- `ExternalKeyboardStatus.connected` - 已连接
- `ExternalKeyboardStatus.authorized` - 已授权

**示例：**
```dart
switch (_keyboardService.currentStatus) {
  case ExternalKeyboardStatus.connected:
    print('键盘已连接');
    break;
  case ExternalKeyboardStatus.notConnected:
    print('键盘未连接');
    break;
  default:
    break;
}
```

---

#### 5. `requestAuthorizationIfNeeded()`

手动触发授权（可选，仅在需要时调用）

```dart
Future<bool> requestAuthorizationIfNeeded()
```

**返回值：** `true` = 授权成功，`false` = 授权失败

**使用场景：**
- 应用启动时未检测到键盘
- 用户后来插入键盘设备
- 业务模块需要主动触发授权

**示例：**
```dart
FutureBuilder(
  future: _keyboardService.requestAuthorizationIfNeeded(),
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return Text('键盘已授权');
    }
    return Text('等待授权...');
  },
)
```

---

## 💡 完整示例

### 示例1：订单扫码模块

```dart
import 'package:get/get.dart';
import 'package:ailand_pos/data/services/external_keyboard_service.dart';

class OrderScanController extends GetxController {
  late final ExternalKeyboardService _keyboardService;
  final scannedCode = ''.obs;
  final isProcessing = false.obs;

  @override
  void onInit() {
    super.onInit();
    _keyboardService = Get.find<ExternalKeyboardService>();
    
    // 检查键盘是否就绪
    if (_keyboardService.isKeyboardReady) {
      print('键盘已就绪，开始监听扫码');
      _keyboardService.registerInputListener(_handleScan);
    } else {
      print('键盘未就绪，尝试手动授权');
      _requestKeyboardAccess();
    }
  }

  // 手动请求键盘权限
  Future<void> _requestKeyboardAccess() async {
    final granted = await _keyboardService.requestAuthorizationIfNeeded();
    if (granted) {
      _keyboardService.registerInputListener(_handleScan);
    } else {
      Get.snackbar('提示', '键盘授权失败，请检查设备连接');
    }
  }

  // 处理扫码输入
  void _handleScan(String data) {
    if (isProcessing.value) return;
    
    // 累积输入（处理条码扫描器逐字符输入）
    scannedCode.value += data;
    
    // 检测到换行符 → 扫码完成
    if (data.contains('\n')) {
      _processBarcode(scannedCode.value.trim());
      scannedCode.value = '';
    }
  }

  // 处理条码数据
  void _processBarcode(String code) async {
    if (code.isEmpty) return;
    
    isProcessing.value = true;
    print('处理条码: $code');
    
    try {
      // TODO: 调用订单API
      await Future.delayed(const Duration(seconds: 1));
      Get.snackbar('成功', '订单 $code 已扫描');
    } catch (e) {
      Get.snackbar('错误', '订单处理失败: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  @override
  void onClose() {
    // 注销监听器，避免内存泄漏
    _keyboardService.unregisterInputListener(_handleScan);
    super.onClose();
  }
}
```

---

### 示例2：商品搜索模块

```dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ailand_pos/data/services/external_keyboard_service.dart';

class ProductSearchController extends GetxController {
  late final ExternalKeyboardService _keyboardService;
  final searchQuery = ''.obs;
  final searchResults = <Product>[].obs;
  
  // 防抖定时器
  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    _keyboardService = Get.find<ExternalKeyboardService>();
    _keyboardService.registerInputListener(_onKeyboardInput);
  }

  // 处理键盘输入
  void _onKeyboardInput(String data) {
    // 回车键 → 立即搜索
    if (data.contains('\n')) {
      _performSearch();
      return;
    }
    
    // 退格键 → 删除最后一个字符
    if (data.contains('\b')) {
      if (searchQuery.value.isNotEmpty) {
        searchQuery.value = searchQuery.value.substring(0, searchQuery.value.length - 1);
      }
      return;
    }
    
    // 普通输入 → 累积查询字符串
    searchQuery.value += data;
    
    // 防抖搜索（500ms内无新输入才搜索）
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  // 执行搜索
  Future<void> _performSearch() async {
    if (searchQuery.value.isEmpty) {
      searchResults.clear();
      return;
    }
    
    print('搜索商品: ${searchQuery.value}');
    
    try {
      // TODO: 调用商品搜索API
      await Future.delayed(const Duration(milliseconds: 300));
      // searchResults.value = await productApi.search(searchQuery.value);
    } catch (e) {
      Get.snackbar('错误', '搜索失败: $e');
    }
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _keyboardService.unregisterInputListener(_onKeyboardInput);
    super.onClose();
  }
}
```

---

### 示例3：会员卡刷卡模块

```dart
import 'package:get/get.dart';
import 'package:ailand_pos/data/services/external_keyboard_service.dart';

class MemberCardController extends GetxController {
  late final ExternalKeyboardService _keyboardService;
  final cardNumber = ''.obs;
  final memberInfo = Rxn<MemberInfo>();
  final isReading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _keyboardService = Get.find<ExternalKeyboardService>();
    
    // 仅在键盘就绪时监听
    if (_keyboardService.isKeyboardReady) {
      _keyboardService.registerInputListener(_onCardSwipe);
    }
  }

  // 处理刷卡输入
  void _onCardSwipe(String data) {
    if (isReading.value) return;
    
    // 会员卡格式：;1234567890=? (磁条卡标准格式)
    if (data.startsWith(';') && data.contains('=')) {
      final cardNum = data.substring(1, data.indexOf('='));
      _lookupMember(cardNum);
    } else {
      // 累积输入（处理部分读取）
      cardNumber.value += data;
      
      // 检测到换行或完整格式
      if (data.contains('\n') || (cardNumber.value.startsWith(';') && cardNumber.value.contains('='))) {
        if (cardNumber.value.contains('=')) {
          final cardNum = cardNumber.value.substring(1, cardNumber.value.indexOf('='));
          _lookupMember(cardNum);
        }
        cardNumber.value = '';
      }
    }
  }

  // 查询会员信息
  Future<void> _lookupMember(String cardNum) async {
    isReading.value = true;
    print('查询会员卡: $cardNum');
    
    try {
      // TODO: 调用会员API
      await Future.delayed(const Duration(seconds: 1));
      // memberInfo.value = await memberApi.getByCard(cardNum);
      
      Get.snackbar('成功', '会员 $cardNum 信息已加载', 
        backgroundColor: Colors.green.withOpacity(0.8));
    } catch (e) {
      Get.snackbar('错误', '会员卡读取失败: $e',
        backgroundColor: Colors.red.withOpacity(0.8));
    } finally {
      isReading.value = false;
    }
  }

  @override
  void onClose() {
    _keyboardService.unregisterInputListener(_onCardSwipe);
    super.onClose();
  }
}
```

---

## ❓ 常见问题

### Q1: 应用启动时没有弹出授权窗口？

**A:** 可能原因：
1. 启动时未检测到键盘设备 → 插入键盘后调用 `requestAuthorizationIfNeeded()`
2. 已经授权过了 → 检查 `isGloballyAuthorized.value`
3. 系统权限被拒绝 → 检查 Android 设置 → 应用权限

---

### Q2: 多个模块同时监听会冲突吗？

**A:** 不会！服务支持多监听器模式：
```dart
// 模块A
serviceA.registerInputListener(callbackA);

// 模块B
serviceB.registerInputListener(callbackB);

// 键盘输入 → callbackA 和 callbackB 都会收到
```

---

### Q3: 如何区分不同类型的输入？

**A:** 通过数据格式判断：

```dart
void _onKeyboardInput(String data) {
  // 条码扫描器：通常以换行符结尾
  if (data.contains('\n')) {
    _handleBarcode(data.trim());
  }
  // 磁条卡：以 ; 开头，包含 =
  else if (data.startsWith(';') && data.contains('=')) {
    _handleMagneticCard(data);
  }
  // 普通键盘输入
  else {
    _handleRegularInput(data);
  }
}
```

---

### Q4: 如何在用户输入时禁用键盘监听？

**A:** 使用条件判断：

```dart
final isInputActive = false.obs;

void _onKeyboardInput(String data) {
  // 用户正在手动输入 → 忽略物理键盘
  if (isInputActive.value) return;
  
  // 处理物理键盘输入
  _processInput(data);
}

// TextField 获得焦点时
TextField(
  onTap: () => isInputActive.value = true,
  onSubmitted: (_) => isInputActive.value = false,
)
```

---

### Q5: 监听器会影响性能吗？

**A:** 不会，原因：
1. 事件驱动模式，无输入时不消耗资源
2. 监听器列表查找是 O(n)，但 n 通常很小（< 10）
3. 回调执行异步进行，不阻塞主线程

**最佳实践：**
- 用完立即注销：`onClose()` 中调用 `unregisterInputListener()`
- 避免在回调中执行耗时操作（使用 `async/await`）

---

### Q6: 如何调试键盘输入？

**A:** 查看服务日志：

```dart
// 方式1：观察响应式日志列表
Obx(() {
  final logs = _keyboardService.debugLogs;
  return ListView.builder(
    itemCount: logs.length,
    itemBuilder: (context, index) => Text(logs[index]),
  );
});

// 方式2：打印到控制台
Get.find<ExternalKeyboardService>().debugLogs.listen((logs) {
  print(logs.first);
});
```

---

## 🎯 最佳实践总结

### ✅ DO（推荐做法）

1. **生命周期管理**
   ```dart
   @override
   void onInit() {
     _service.registerInputListener(_callback);
   }
   
   @override
   void onClose() {
     _service.unregisterInputListener(_callback);
   }
   ```

2. **检查键盘状态**
   ```dart
   if (_service.isKeyboardReady) {
     // 执行需要键盘的操作
   }
   ```

3. **错误处理**
   ```dart
   void _callback(String data) {
     try {
       // 处理输入
     } catch (e) {
       print('处理失败: $e');
     }
   }
   ```

### ❌ DON'T（避免做法）

1. **忘记注销监听器**
   ```dart
   // ❌ 错误
   @override
   void onClose() {
     // 忘记注销 → 内存泄漏
     super.onClose();
   }
   ```

2. **在回调中执行耗时操作**
   ```dart
   // ❌ 错误
   void _callback(String data) {
     // 阻塞主线程
     _heavyComputation(data);
   }
   
   // ✅ 正确
   void _callback(String data) async {
     await _heavyComputation(data);
   }
   ```

3. **重复注册同一监听器**
   ```dart
   // ❌ 错误
   void someMethod() {
     _service.registerInputListener(_callback); // 每次调用都注册
   }
   
   // ✅ 正确
   @override
   void onInit() {
     _service.registerInputListener(_callback); // 只注册一次
   }
   ```

---

## 📞 技术支持

如有问题，请联系开发团队或查看：
- 源码：`lib/data/services/external_keyboard_service.dart`
- 配置：`lib/main.dart` (initServices)
- 示例：`lib/modules/settings/views/external_keyboard_view.dart`

---

**最后更新：** 2025-11-20  
**版本：** v1.0.0  
**作者：** AI Development Team
