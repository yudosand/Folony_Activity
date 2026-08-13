import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/network/human_readable_error.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  AppRole _selectedRole = AppRole.areaManager;
  bool _showPassword = false;
  bool _showDemoMode = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backendConfig = BackendConfig.fromEnvironment();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 28),
                  Text(
                    'Folony Activity',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: const [
                        TextSpan(text: 'Bangun aktivitas kerja yang '),
                        TextSpan(
                          text:
                              'jujur, disiplin, mandiri, dan penuh tanggung jawab.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (!backendConfig.isProduction) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFD166)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            backendConfig.environmentLabel.toUpperCase(),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: const Color(0xFF7A4B00),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            backendConfig.baseUrl,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7A4B00),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 30),
                  Text('Login', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kode Karyawan / Nomor HP / Email',
                      hintText: 'Contoh: EMP-001',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimal 6 karakter',
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Sembunyikan password'
                            : 'Tampilkan password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Password wajib diisi';
                      }
                      if (value.trim().length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed:
                        widget.controller.isAuthenticating ? null : _login,
                    child: Text(
                      widget.controller.isAuthenticating
                          ? 'Memproses...'
                          : 'Masuk',
                    ),
                  ),
                  if (widget.controller.isDemoModeEnabled) ...[
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showDemoMode = !_showDemoMode),
                      child: Text(_showDemoMode
                          ? 'Sembunyikan mode demo'
                          : 'Mode demo/dev'),
                    ),
                  ],
                  if (_showDemoMode && widget.controller.isDemoModeEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Role simulasi',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Role simulasi hanya dipakai saat mode backend belum aktif.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Akun tester lintas role: username `allrole`, password `123456`.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...AppRole.values.asMap().entries.map((entry) {
                      final index = entry.key;
                      final role = entry.value;
                      return Column(
                        children: [
                          _RoleRow(
                            role: role,
                            selected: _selectedRole == role,
                            onTap: () => setState(() => _selectedRole = role),
                          ),
                          if (index != AppRole.values.length - 1)
                            const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await widget.controller.signIn(
        identifier: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        fallbackRole: _selectedRole,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login gagal: ${humanReadableError(error, action: 'login')}',
          ),
        ),
      );
    }
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    role.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
