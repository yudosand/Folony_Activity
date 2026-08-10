class BackendConfig {
  const BackendConfig({
    required this.workflowRemoteEnabled,
    required this.baseUrl,
    required this.demoModeEnabled,
  });

  factory BackendConfig.fromEnvironment() {
    return const BackendConfig(
      workflowRemoteEnabled: bool.fromEnvironment(
        'HEX_ENABLE_REMOTE_WORKFLOW',
        defaultValue: true,
      ),
      baseUrl: String.fromEnvironment(
        'HEX_BACKEND_BASE_URL',
        defaultValue: 'https://absent.folony.co.id/api',
      ),
      demoModeEnabled: bool.fromEnvironment(
        'HEX_ENABLE_DEMO_MODE',
        defaultValue: false,
      ),
    );
  }

  final bool workflowRemoteEnabled;
  final String baseUrl;
  final bool demoModeEnabled;
}
