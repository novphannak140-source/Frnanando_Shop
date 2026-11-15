import 'package:franando_shop_api/models/customer.dart';
import 'package:test/test.dart';

void main() {
  test('parseUpdate keeps only allowed fields', () {
    final out = Customer.parseUpdate({'name': ' Dara ', 'role': 'admin', 'gender': 'male'});
    expect(out['name'], 'Dara');
    expect(out.containsKey('role'), isFalse);
  });

  test('parseUpdate rejects bad gender', () {
    expect(() => Customer.parseUpdate({'gender': 'x'}), throwsFormatException);
  });

  test('exactly one default address', () {
    final out = Customer.parseUpdate({
      'addresses': [
        {'address': 'A'},
        {'address': 'B', 'isDefault': true},
      ],
    });
    final list = out['addresses'] as List;
    expect(list.where((a) => (a as Map)['isDefault'] == true).length, 1);
    expect((list[1] as Map)['isDefault'], isTrue);
  });
}
