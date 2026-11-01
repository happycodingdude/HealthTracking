import 'package:api_contract/api_contract.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/strings_vi.dart';
import '../../../core/error_mapping.dart';
import '../../../core/widgets/link_text.dart';
import '../../../core/widgets/phone_input_formatter.dart';
import '../../../data/api/api_client.dart';
import '../../../ui/components/components.dart';
import '../../../ui/theme.dart';
import '../application/auth_controller.dart';
import 'auth_scaffold.dart';
import 'forgot_password_sheet.dart';
import 'member_card.dart';
import 'password_field.dart';

/// S-01b — Đăng nhập (04 Bản 4 v1.7 §6.7): tấm thẻ chỉ có dòng số điện thoại
/// đang gõ (chưa biết tên). Sai thì luôn báo câu chung, không nói ô nào sai.
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
    if (phone != null) _phone.text = phone;
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
        card: ValueListenableBuilder(
          valueListenable: _phone,
          builder: (_, value, _) => MemberCard(phone: value.text),
        ),
        fields: [
          IronlyTextField(
            name: 'phone',
            hint: S.fieldPhone,
            controller: _phone,
            style: IronlyText.authField,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [PhoneInputFormatter()],
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => _clear(),
          ),
          const SizedBox(height: TokenSpace.s3),
          PasswordField(
            name: 'password',
            label: S.fieldPassword,
            controller: _password,
            error: _error,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => _clear(),
            onSubmitted: (_) => _submit(),
          ),
          // Dưới hai ô, căn phải, cách 4: chữ cam 14 / 600 → S-01c.
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: S.forgotPassword,
              child: ExcludeSemantics(
                child: GestureDetector(
                  key: const ValueKey('forgot-password'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showForgotPasswordSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TokenSpace.s5,
                      TokenSpace.s1,
                      TokenSpace.s1,
                      TokenSpace.s3,
                    ),
                    child: Text(S.forgotPassword, style: IronlyText.authLink),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: [
          if (_notice != null) FormNotice(_notice!),
          IronlyButton.primary(
            key: const ValueKey('login-submit'),
            label: S.login,
            large: true,
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: TokenSpace.s1),
          LinkText(
            prefix: S.noCardQuestion,
            link: S.createCard,
            onTap: () => context.go('/welcome/register'),
          ),
        ],
      ),
    );
  }
}
