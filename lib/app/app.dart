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
  const HexActivityApp({super.key});

  @override
  State<HexActivityApp> createState() => _HexActivityAppState();
}

class _HexActivityAppState extends State<HexActivityApp> {
  late final AppController _controller = _buildController();

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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
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
          home: _controller.isBootstrapping
              ? const _AppLoadingView()
              : _controller.isAuthenticated
              ? MainShell(controller: _controller)
              : LoginPage(controller: _controller),
        );
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
