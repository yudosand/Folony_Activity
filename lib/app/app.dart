import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/backend_config.dart';
import '../core/network/simple_api_client.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/heat_map_repository.dart';
import '../core/repositories/hybrid/fallback_approval_repository.dart';
import '../core/repositories/hybrid/fallback_attendance_repository.dart';
import '../core/repositories/hybrid/fallback_heat_map_repository.dart';
import '../core/repositories/hybrid/fallback_leave_repository.dart';
import '../core/repositories/hybrid/fallback_network_repository.dart';
import '../core/repositories/hybrid/fallback_wfa_repository.dart';
import '../core/repositories/hybrid/workflow_repository_mode.dart';
import '../core/repositories/mock/mock_approval_repository.dart';
import '../core/repositories/mock/mock_attendance_repository.dart';
import '../core/repositories/mock/mock_heat_map_repository.dart';
import '../core/repositories/mock/mock_leave_repository.dart';
import '../core/repositories/mock/mock_network_repository.dart';
import '../core/repositories/mock/mock_upload_repository.dart';
import '../core/repositories/mock/mock_wfa_repository.dart';
import '../core/repositories/remote/remote_attendance_repository.dart';
import '../core/repositories/remote/remote_auth_repository.dart';
import '../core/repositories/remote/remote_approval_repository.dart';
import '../core/repositories/remote/remote_heat_map_repository.dart';
import '../core/repositories/remote/remote_leave_repository.dart';
import '../core/repositories/remote/remote_network_repository.dart';
import '../core/repositories/remote/remote_upload_repository.dart';
import '../core/repositories/remote/remote_wfa_repository.dart';
import '../core/repositories/hybrid/fallback_upload_repository.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/shell/presentation/main_shell.dart';
import 'app_controller.dart';

class HexActivityApp extends StatefulWidget {
  const HexActivityApp({
    super.key,
    AppController? controller,
  }) : _controller = controller;

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final AppController? _controller;

  @override
  State<HexActivityApp> createState() => _HexActivityAppState();
}

class _HexActivityAppState extends State<HexActivityApp> {
  late final bool _ownsController = widget._controller == null;
  late final AppController _controller = widget._controller ?? _buildController();

  AppController _buildController() {
    final backendConfig = BackendConfig.fromEnvironment();
    final apiClient = SimpleApiClient(baseUrl: backendConfig.baseUrl);
    final AuthRepository authRepository = RemoteAuthRepository(client: apiClient);
    final workflowMode = backendConfig.workflowRemoteEnabled
        ? WorkflowRepositoryMode.remotePreferred
        : WorkflowRepositoryMode.mockOnly;
    final HeatMapRepository heatMapRepository = FallbackHeatMapRepository(
      mode: workflowMode,
      remote: RemoteHeatMapRepository(client: apiClient),
      local: const MockHeatMapRepository(),
    );

    return AppController(
      authRepository: authRepository,
      useRemoteAuth: backendConfig.workflowRemoteEnabled,
      useCanonicalWorkflowIds: backendConfig.workflowRemoteEnabled,
      networkRepository: FallbackNetworkRepository(
        mode: workflowMode,
        remote: RemoteNetworkRepository(client: apiClient),
        local: MockNetworkRepository(),
      ),
      attendanceRepository: FallbackAttendanceRepository(
        mode: workflowMode,
        remote: RemoteAttendanceRepository(client: apiClient),
        local: MockAttendanceRepository(),
      ),
      leaveRepository: FallbackLeaveRepository(
        mode: workflowMode,
        remote: RemoteLeaveRepository(client: apiClient),
        local: MockLeaveRepository(),
      ),
      wfaRepository: FallbackWfaRepository(
        mode: workflowMode,
        remote: RemoteWfaRepository(client: apiClient),
        local: MockWfaRepository(),
      ),
      approvalRepository: FallbackApprovalRepository(
        mode: workflowMode,
        remote: RemoteApprovalRepository(client: apiClient),
        local: MockApprovalRepository(),
      ),
      heatMapRepository: heatMapRepository,
      uploadRepository: FallbackUploadRepository(
        mode: workflowMode,
        remote: RemoteUploadRepository(client: apiClient),
        local: const MockUploadRepository(),
      ),
      seedWorkflowDemoData: !backendConfig.workflowRemoteEnabled,
    );
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: HexActivityApp.navigatorKey,
      title: 'HEX Activity',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('id'),
        Locale('en', 'US'),
        Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: _AppHome(controller: _controller),
    );
  }
}

class _AppHome extends StatelessWidget {
  const _AppHome({
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isBootstrapping) {
          return const _AppLoadingView();
        }
        if (controller.isAuthenticated) {
          return MainShell(controller: controller);
        }
        return LoginPage(controller: controller);
      },
    );
  }
}

class _AppLoadingView extends StatelessWidget {
  const _AppLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
