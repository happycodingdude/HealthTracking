import 'package:domain/domain.dart';
import 'package:domain/testing.dart';
import 'package:test/test.dart';

void main() {
  group('UA-21: tên hiển thị 1–30 ký tự', () {
    test('hợp lệ: 1 ký tự, 30 ký tự có dấu', () {
      expect(AccountValidators.isValidDisplayName('M'), isTrue);
      expect(AccountValidators.isValidDisplayName('Minh'), isTrue);
      expect(
        AccountValidators.isValidDisplayName('Nguyễn Thị Ánh Dương Phượng Vy'),
        isTrue,
      );
      expect('Nguyễn Thị Ánh Dương Phượng Vy'.runes.length, 30);
    });

    test('sai: rỗng, chỉ khoảng trắng, 31 ký tự', () {
      expect(AccountValidators.isValidDisplayName(''), isFalse);
      expect(AccountValidators.isValidDisplayName('   '), isFalse);
      expect(AccountValidators.isValidDisplayName('a' * 31), isFalse);
    });

    test('bỏ khoảng trắng đầu/cuối trước khi đếm và khi lưu', () {
      expect(AccountValidators.isValidDisplayName('  ${'a' * 30}  '), isTrue);
      expect(AccountValidators.normalizeDisplayName('  Minh '), 'Minh');
    });
  });

  group('UA-20: số điện thoại 10 chữ số, bắt đầu bằng 0', () {
    test('hợp lệ, kể cả dạng có khoảng trắng', () {
      expect(AccountValidators.isValidPhone('0912345678'), isTrue);
      expect(AccountValidators.isValidPhone('0912 345 678'), isTrue);
      expect(AccountValidators.normalizePhone('0912 345 678'), '0912345678');
    });

    test(
      'sai: 9 hoặc 11 chữ số, không bắt đầu bằng 0, có chữ, mã quốc gia',
      () {
        for (final bad in [
          '091234567',
          '09123456789',
          '1912345678',
          '09123a5678',
          '+84912345678',
          '',
        ]) {
          expect(AccountValidators.isValidPhone(bad), isFalse, reason: bad);
        }
      },
    );
  });

  group('UA-19: mật khẩu ít nhất 8 ký tự', () {
    test('7 ký tự sai, 8 ký tự đúng', () {
      expect(
        AccountValidators.isValidPassword(randomTestPassword(length: 7)),
        isFalse,
      );
      expect(
        AccountValidators.isValidPassword(randomTestPassword(length: 8)),
        isTrue,
      );
      expect(
        AccountValidators.isValidPassword(
          randomTestPassword(length: 8, vietnamese: true),
        ),
        isTrue,
      );
    });
  });

  group('S-01a: bảng kiểm tra khi đăng ký', () {
    test('hợp lệ → không có ô lỗi', () {
      final password = randomTestPassword();
      expect(
        AccountValidators.validateRegistration(
          displayName: 'Minh',
          phone: '0912 345 678',
          password: password,
          passwordConfirm: password,
        ),
        isEmpty,
      );
    });

    test('mọi ô sai → báo đủ theo thứ tự trên màn hình', () {
      expect(
        AccountValidators.validateRegistration(
          displayName: '',
          phone: '123',
          password: randomTestPassword(length: 6),
          passwordConfirm: randomTestPassword(length: 5),
        ),
        [
          AccountField.displayName,
          AccountField.phone,
          AccountField.password,
          AccountField.passwordConfirm,
        ],
      );
    });

    test('S-01a: mật khẩu nhập lại chưa khớp', () {
      expect(
        AccountValidators.validateRegistration(
          displayName: 'Minh',
          phone: '0912345678',
          password: randomTestPassword(),
          passwordConfirm: randomTestPassword(),
        ),
        [AccountField.passwordConfirm],
      );
    });
  });
}
