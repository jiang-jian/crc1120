import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../data/services/external_keyboard_service.dart';
import '../../../data/models/external_keyboard_model.dart';
import '../../../app/theme/app_theme.dart';

class ExternalKeyboardView extends StatelessWidget {
  const ExternalKeyboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取全局单例服务（由 main.dart 初始化）
    final service = Get.find<ExternalKeyboardService>();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Obx(() {
        final selectedDevice = service.selectedKeyboard.value;
        final keyboardStatus = service.keyboardStatus.value;

        return _buildTwoColumnLayout(service, keyboardStatus, selectedDevice);
      }),
    );
  }

  Widget _buildTwoColumnLayout(
    ExternalKeyboardService service,
    ExternalKeyboardStatus keyboardStatus,
    ExternalKeyboardDevice? selectedDevice,
  ) {
    return Stack(
      children: [
        Row(
          children: [
            // 左列：设备基础信息和状态 (50%)
            Expanded(
              flex: 50,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 40.h),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundGrey,
                  border: Border(
                    right: BorderSide(color: AppTheme.borderColor, width: 1.w),
                  ),
                ),
                child: _buildDeviceInfoSection(service, selectedDevice, keyboardStatus),
              ),
            ),

            // 右列：键盘输入测试区域 (50%)
            Expanded(
              flex: 50,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 40.h),
                color: Colors.white,
                child: SingleChildScrollView(
                  child: _buildKeyboardTestSection(service, keyboardStatus),
                ),
              ),
            ),
          ],
        ),

        // 调试日志面板（浮动在右下角）
        _buildDebugLogPanel(service),
      ],
    );
  }

  /// 左侧：设备基础信息和状态区域
  Widget _buildDeviceInfoSection(
    ExternalKeyboardService service,
    ExternalKeyboardDevice? device,
    ExternalKeyboardStatus status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          '设备信息',
          style: TextStyle(
            fontSize: 26.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),

        SizedBox(height: 40.h),

        // 扫描按钮
        _buildScanButton(service),

        SizedBox(height: 40.h),

        // 设备列表或状态显示
        Expanded(
          child: service.isScanning.value
              ? _buildScanningState()
              : service.detectedKeyboards.isEmpty
                  ? _buildNoDeviceState()
                  : _buildDevicesList(service),
        ),

        // 底部状态信息
        if (device != null) ..[
          SizedBox(height: 20.h),
          _buildDeviceStatusCard(device, status),
        ],
      ],
    );
  }

  Widget _buildScanButton(ExternalKeyboardService service) {
    return Obx(
      () => SizedBox(
        height: 56.h,
        child: ElevatedButton.icon(
          onPressed: service.isScanning.value
              ? null
              : () => service.scanUsbKeyboards(),
          icon: service.isScanning.value
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.refresh, size: 22.sp),
          label: Text(
            service.isScanning.value ? '扫描中...' : '扫描USB设备',
            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50.w,
            height: 50.h,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5B544)),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            '扫描中...',
            style: TextStyle(fontSize: 16.sp, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDeviceState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.keyboard_outlined,
            size: 60.sp,
            color: const Color(0xFFBDC3C7),
          ),
          SizedBox(height: 16.h),
          Text(
            '未检测到外置键盘',
            style: TextStyle(fontSize: 16.sp, color: AppTheme.textTertiary),
          ),
          SizedBox(height: 8.h),
          Text(
            '请连接USB键盘设备',
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFFBDC3C7)),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList(ExternalKeyboardService service) {
    return Obx(() {
      final devices = service.detectedKeyboards;
      final selectedDevice = service.selectedKeyboard.value;
      final latestDeviceId = service.latestDeviceId.value;

      return ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          final isSelected = selectedDevice?.deviceId == device.deviceId;
          final isHighlighted = latestDeviceId == device.deviceId;

          return _buildDeviceListItem(
            device: device,
            isSelected: isSelected,
            isHighlighted: isHighlighted,
            onTap: () {
              if (device.isConnected) {
                service.selectedKeyboard.value = device;
                service.latestDeviceId.value = null;
              }
            },
          );
        },
      );
    });
  }

  Widget _buildDeviceListItem({
    required ExternalKeyboardDevice device,
    required bool isSelected,
    required bool isHighlighted,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: device.isConnected ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : isHighlighted
                        ? const Color(0xFFE5B544)
                        : AppTheme.borderColor,
                width: isSelected || isHighlighted ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            child: Row(
              children: [
                // 键盘图标
                Container(
                  width: 48.w,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: device.isConnected
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
                  ),
                  child: Icon(
                    Icons.keyboard,
                    size: 24.sp,
                    color: device.isConnected
                        ? AppTheme.primaryColor
                        : Colors.grey,
                  ),
                ),

                SizedBox(width: 16.w),

                // 设备信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'VID: ${device.vendorId} / PID: ${device.productId}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: 12.w),

                // 连接状态
                _buildConnectionBadge(device.isConnected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionBadge(bool isConnected) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isConnected
            ? AppTheme.successColor.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
      ),
      child: Text(
        isConnected ? '已连接' : '未连接',
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: isConnected ? AppTheme.successColor : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDeviceStatusCard(
    ExternalKeyboardDevice device,
    ExternalKeyboardStatus status,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case ExternalKeyboardStatus.notConnected:
        statusColor = Colors.grey;
        statusText = '未连接';
        statusIcon = Icons.link_off;
        break;
      case ExternalKeyboardStatus.connected:
        statusColor = AppTheme.successColor;
        statusText = '已连接';
        statusIcon = Icons.check_circle;
        break;
      case ExternalKeyboardStatus.testing:
        statusColor = AppTheme.infoColor;
        statusText = '测试中';
        statusIcon = Icons.edit;
        break;
      case ExternalKeyboardStatus.authorized:
        statusColor = AppTheme.successColor;
        statusText = '已授权';
        statusIcon = Icons.verified;
        break;
      case ExternalKeyboardStatus.error:
        statusColor = AppTheme.errorColor;
        statusText = '错误';
        statusIcon = Icons.error;
        break;
    }

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 24.sp, color: statusColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设备状态',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textTertiary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 右侧：键盘输入测试区域
  Widget _buildKeyboardTestSection(
    ExternalKeyboardService service,
    ExternalKeyboardStatus status,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            Text(
              '键盘测试',
              style: TextStyle(
                fontSize: 26.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            if (service.keyboardInputData.value.isNotEmpty)
              TextButton.icon(
                onPressed: () => service.clearInputData(),
                icon: Icon(Icons.clear, size: 18.sp),
                label: Text('清空', style: TextStyle(fontSize: 14.sp)),
              ),
          ],
        ),

        SizedBox(height: 20.h),

        // 提示文本
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.infoColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusDefault),
            border: Border.all(
              color: AppTheme.infoColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 20.sp,
                color: AppTheme.infoColor,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  '点击下方输入框，然后使用外置键盘输入内容以测试按键功能',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.infoColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 30.h),

        // 键盘输入框和测试按钮
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _KeyboardInputField(service: service),
            ),
            SizedBox(width: 16.w),
            Obx(() => ElevatedButton.icon(
              onPressed: service.isTesting.value
                  ? service.stopTestOutput
                  : service.startTestOutput,
              icon: Icon(
                service.isTesting.value ? Icons.stop : Icons.play_arrow,
                size: 20.sp,
              ),
              label: Text(
                service.isTesting.value ? '停止测试' : '测试输出',
                style: TextStyle(fontSize: 14.sp),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: service.isTesting.value
                    ? Colors.red
                    : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                  vertical: 16.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            )),
          ],
        ),

        SizedBox(height: 20.h),

        // 测试输出展示区
        Obx(() => service.isTesting.value
            ? _buildTestOutputArea(service)
            : const SizedBox.shrink()),

        SizedBox(height: 20.h),
      ],
    );
  }

  /// 测试输出展示区
  Widget _buildTestOutputArea(ExternalKeyboardService service) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.output,
                size: 20.sp,
                color: AppTheme.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                '测试输出',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // 成功动画
              Obx(() => AnimatedScale(
                scale: service.testSuccess.value ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: service.testSuccess.value ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                ),
              )),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: Obx(() {
              final output = service.testOutputData.value;
              return Text(
                output.isEmpty ? '等待键盘输入...' : output,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: output.isEmpty
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                  fontFamily: 'monospace',
                  height: 1.5,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

/// 键盘输入框组件（使用 StatefulWidget 管理生命周期）
class _KeyboardInputField extends StatefulWidget {
  final ExternalKeyboardService service;

  const _KeyboardInputField({required this.service});

  @override
  State<_KeyboardInputField> createState() => _KeyboardInputFieldState();
}

class _KeyboardInputFieldState extends State<_KeyboardInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Worker? _dataWorker;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();

    // 使用 ever 监听数据变化，并在 dispose 时取消
    _dataWorker = ever(widget.service.keyboardInputData, (value) {
      if (_controller.text != value) {
        _controller.text = value;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _dataWorker?.dispose(); // 取消监听，防止内存泄漏
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.borderColor, width: 2),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true, // 自动聚焦
        maxLines: 10,
        minLines: 10,
        style: TextStyle(
          fontSize: 16.sp,
          color: AppTheme.textPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: '点击此处，然后使用外置键盘输入内容...',
          hintStyle: TextStyle(
            fontSize: 16.sp,
            color: AppTheme.textTertiary,
          ),
          contentPadding: EdgeInsets.all(24.w),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          // 当用户直接在输入框中输入时，同步到 service
          widget.service.keyboardInputData.value = value;
        },
        onTap: () {
          // 点击输入框时，确保焦点在输入框上
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
          widget.service.startListening();
        },
      ),
    );
  }
}

/// 扩展：添加调试日志面板
extension on _ExternalKeyboardViewState {
  Widget _buildDebugLogPanel(ExternalKeyboardService service) {
    return Positioned(
      right: 0,
      top: 80.h,
      bottom: 100.h,
      child: Obx(() {
        if (!service.debugLogExpanded.value) {
          // 收起状态：只显示展开按钮
          return GestureDetector(
            onTap: () => service.debugLogExpanded.value = true,
            child: Container(
              width: 40.w,
              padding: EdgeInsets.symmetric(vertical: 20.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                  bottomLeft: Radius.circular(AppTheme.borderRadiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.chevron_left,
                  color: const Color(0xFF4EC9B0),
                  size: 20.sp,
                ),
              ),
            ),
          );
        }

        // 展开状态：显示完整日志面板
        return Container(
          width: 380.w,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppTheme.borderRadiusLarge),
              bottomLeft: Radius.circular(AppTheme.borderRadiusLarge),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              // 标题栏
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.terminal,
                      size: 18.sp,
                      color: const Color(0xFF4EC9B0),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '键盘调试日志',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // 收起按钮
                    InkWell(
                      onTap: () => service.debugLogExpanded.value = false,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E3E3E),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          size: 18.sp,
                          color: const Color(0xFFCCCCCC),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    // 清空按钮
                    InkWell(
                      onTap: () => service.clearLogs(),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E3E3E),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.clear_all,
                              size: 14.sp,
                              color: const Color(0xFFCCCCCC),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '清空',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFFCCCCCC),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 日志内容
              Expanded(
                child: Obx(() {
                  final logs = service.debugLogs;

                  if (logs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48.sp,
                            color: const Color(0xFF555555),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            '暂无日志',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF888888),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            '插入USB键盘查看日志',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(12.w),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isError = log.contains('✗') ||
                          log.contains('错误') ||
                          log.contains('失败');
                      final isSuccess =
                          log.contains('✓') || log.contains('成功');
                      final isSeparator = log.contains('=====');

                      Color textColor = const Color(0xFFCCCCCC);
                      if (isError) {
                        textColor = const Color(0xFFF48771);
                      } else if (isSuccess) {
                        textColor = const Color(0xFF4EC9B0);
                      } else if (isSeparator) {
                        textColor = const Color(0xFF569CD6);
                      }

                      return Padding(
                        padding: EdgeInsets.only(bottom: 4.h),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontFamily: 'monospace',
                            color: textColor,
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      }),
    );
  }
}
