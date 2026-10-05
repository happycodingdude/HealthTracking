import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/error_mapping.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/link_text.dart';
import '../../../core/widgets/phone_input_formatter.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/api/api_client.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'forgot_password_sheet.dart';
import 'password_field.dart';

/// S-01b — Đăng nhập. Sai thì luôn báo câu chung, không nói ô nào sai.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _notice;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Phiên hết hạn: điền sẵn số của tài khoản trên máy (05 §6.6.6).
    final phone = ref.read(authControllerProvider).phone;
    if (phone != null) _phone.text = PhoneInputFormatter.format(phone);
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clear() {
    if (_error != null || _notice != null) {
      setState(() {
        _error = null;
        _notice = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _notice = null;
    });
    if (!AccountValidators.isValidPhone(_phone.text) ||
        _password.text.isEmpty) {
      setState(() => _error = S.errorInvalidCredentials);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(phone: _phone.text, password: _password.text);
    } on ServerFailure catch (e) {
      setState(() {
        if (e.error.code == ErrorCode.invalidCredentials ||
            e.error.code == ErrorCode.tooManyAttempts) {
          _error = S.errorInvalidCredentials;
        } else {
          _notice = errorMessage(e.error, ErrorScreen.login);
        }
      });
    } on ApiFailure {
      setState(() => _notice = S.offlineLogin);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: AuthScaffold(
        title: S.login,
        fields: [
          LabeledField(
            label: S.fieldPhone,
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [PhoneInputFormatter()],
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => _clear(),
          ),
          const SizedBox(height: 20),
          PasswordField(
            label: S.fieldPassword,
            controller: _password,
            error: _error,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => _clear(),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showForgotPasswordSheet(context),
              child: const Text(S.forgotPassword),
            ),
          ),
        ],
        bottom: [
          if (_notice != null) FormNotice(_notice!),
          LinkText(
            prefix: S.noAccount,
            link: S.register,
            onTap: () => context.go('/welcome/register'),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: S.login,
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
