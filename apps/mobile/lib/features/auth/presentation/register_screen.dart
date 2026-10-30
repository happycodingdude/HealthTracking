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
import 'password_field.dart';

/// S-01a — Đăng ký (D-23, D-24). Nút "Đăng ký" luôn bấm được; lỗi hiện ngay
/// dưới ô tương ứng và cuộn tới ô lỗi đầu tiên (P4).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _focus = {for (final f in AccountField.values) f: FocusNode()};
  final _keys = {for (final f in AccountField.values) f: GlobalKey()};

  final _errors = <AccountField, String>{};
  bool _phoneTaken = false;
  String? _notice;
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _password, _confirm]) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  static String _message(AccountField field) => switch (field) {
    AccountField.displayName => S.invalidDisplayName,
    AccountField.phone => S.invalidPhone,
    AccountField.password => S.invalidPassword,
    AccountField.passwordConfirm => S.invalidPasswordConfirm,
  };

  /// Lỗi biến mất khi Bạn sửa ô đó (04 §6.13.5).
  void _clear(AccountField field) {
    if (_errors.containsKey(field) ||
        (field == AccountField.phone && _phoneTaken) ||
        _notice != null) {
      setState(() {
        _errors.remove(field);
        if (field == AccountField.phone) _phoneTaken = false;
        _notice = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final invalid = AccountValidators.validateRegistration(
      displayName: _name.text,
      phone: _phone.text,
      password: _password.text,
      passwordConfirm: _confirm.text,
    );
    setState(() {
      _errors
        ..clear()
        ..addAll({for (final f in invalid) f: _message(f)});
      _phoneTaken = false;
      _notice = null;
    });
    if (invalid.isNotEmpty) {
      _showField(invalid.first);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            displayName: _name.text,
            phone: _phone.text,
            password: _password.text,
          );
      // Điều hướng do router xử lý theo trạng thái đăng nhập (VS01-T10).
    } on ServerFailure catch (e) {
      _showServerError(e.error);
    } on ApiFailure {
      setState(() => _notice = S.offlineRegister);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showServerError(ApiError error) {
    setState(() {
      switch (error.code) {
        case ErrorCode.phoneTaken:
          _phoneTaken = true;
          _showField(AccountField.phone);
        case ErrorCode.validationFailed when fieldMessage(error.field) != null:
          final field = AccountField.values.byName(error.field!);
          _errors[field] = fieldMessage(error.field)!;
          _showField(field);
        default:
          _notice = errorMessage(error, ErrorScreen.register);
      }
    });
  }

  void _showField(AccountField field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[field]!.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          alignment: 0.2,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      // 04 Bản 4 S-01a: ô nhập dạng thẻ, gợi ý trong ô là tên trường; không
      // câu phụ dưới tiêu đề (FR4-04).
      child: AuthScaffold(
        title: S.register,
        fields: [
          IronlyTextField(
            key: _keys[AccountField.displayName],
            name: 'display-name',
            hint: S.fieldDisplayName,
            controller: _name,
            focusNode: _focus[AccountField.displayName],
            error: _errors[AccountField.displayName],
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            onChanged: (_) => _clear(AccountField.displayName),
          ),
          const SizedBox(height: TokenSpace.s3),
          IronlyTextField(
            key: _keys[AccountField.phone],
            name: 'phone',
            hint: S.fieldPhone,
            controller: _phone,
            focusNode: _focus[AccountField.phone],
            error: _phoneTaken
                ? S.errorPhoneTaken
                : _errors[AccountField.phone],
            errorAction: _phoneTaken
                ? ErrorAction(S.login, () => context.go('/welcome/login'))
                : null,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [PhoneInputFormatter()],
            autofillHints: const [AutofillHints.telephoneNumber],
            onChanged: (_) => _clear(AccountField.phone),
          ),
          const SizedBox(height: TokenSpace.s3),
          PasswordField(
            key: _keys[AccountField.password],
            name: 'password',
            label: S.fieldPassword,
            controller: _password,
            focusNode: _focus[AccountField.password],
            error: _errors[AccountField.password],
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _clear(AccountField.password),
          ),
          const SizedBox(height: TokenSpace.s3),
          PasswordField(
            key: _keys[AccountField.passwordConfirm],
            name: 'password-confirm',
            label: S.fieldPasswordConfirm,
            controller: _confirm,
            focusNode: _focus[AccountField.passwordConfirm],
            error: _errors[AccountField.passwordConfirm],
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: (_) => _clear(AccountField.passwordConfirm),
            onSubmitted: (_) => _submit(),
          ),
        ],
        bottom: [
          if (_notice != null) FormNotice(_notice!),
          IronlyButton.primary(
            key: const ValueKey('register-submit'),
            label: S.register,
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: TokenSpace.s1),
          // 04 Bản 4 S-01a (mock): chữ cam dưới nút.
          LinkText(
            prefix: S.haveAccount,
            link: S.login,
            onTap: () => context.go('/welcome/login'),
          ),
        ],
      ),
    );
  }
}
