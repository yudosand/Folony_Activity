class BackendConfig {
  const BackendConfig({
    required this.workflowRemoteEnabled,
    required this.baseUrl,
    required this.demoModeEnabled,
    required this.environmentLabel,
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
      environmentLabel: String.fromEnvironment(
        'HEX_APP_ENV_LABEL',
        defaultValue: 'PRODUCTION',
      ),
    );
  }

  final bool workflowRemoteEnabled;
  final String baseUrl;
  final bool demoModeEnabled;
  final String environmentLabel;

  bool get isProduction =>
      environmentLabel.trim().toUpperCase() == 'PRODUCTION';
}
