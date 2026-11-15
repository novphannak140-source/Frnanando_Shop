import 'package:franando_shop_api/repositories/password_helper.dart';
import 'package:test/test.dart';

void main() {
  test('password hash verifies', () {
    final h = hashPassword('secret123');
    expect(verifyPassword('secret123', h), isTrue);
    expect(verifyPassword('wrong', h), isFalse);
  });

}
