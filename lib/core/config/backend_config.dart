class BackendConfig {
  const BackendConfig({
    required this.workflowRemoteEnabled,
    required this.baseUrl,
  });

  factory BackendConfig.fromEnvironment() {
    return const BackendConfig(
      workflowRemoteEnabled: bool.fromEnvironment(
        'HEX_ENABLE_REMOTE_WORKFLOW',
        defaultValue: false,
      ),
      baseUrl: String.fromEnvironment(
        'HEX_BACKEND_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api',
      ),
    );
  }

  final bool workflowRemoteEnabled;
  final String baseUrl;
}
