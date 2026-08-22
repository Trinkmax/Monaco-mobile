import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/core/auth/pin_service.dart';
import 'package:monaco_mobile/core/auth/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Storage en memoria: sin Keychain en el runner de tests.
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('sin PIN: hasPin/isEnabled false, verify falla', () async {
    expect(await PinService.hasPin(), isFalse);
    expect(await PinService.isEnabled(), isFalse);
    expect(await PinService.verifyPin('1234'), isFalse);
  });

  test('setPin guarda un hash (no el PIN) y prende el gate', () async {
    await PinService.setPin('2580');
    final stored = await SecureStorageService.getLocalPinHash();
    expect(stored, isNotNull);
    expect(stored, isNot(contains('2580')));
    expect(stored!.length, 64); // sha256 hex
    expect(await PinService.hasPin(), isTrue);
    expect(await PinService.isEnabled(), isTrue);
    expect(await SecureStorageService.isPinEnabled(), isTrue);
  });

  test('verifyPin acepta el correcto y rechaza el resto', () async {
    await PinService.setPin('2580');
    expect(await PinService.verifyPin('2580'), isTrue);
    expect(await PinService.verifyPin('2581'), isFalse);
    expect(await PinService.verifyPin('258'), isFalse);
    expect(await PinService.verifyPin('abcd'), isFalse);
  });

  test('el hash depende del device_id (sal)', () async {
    await PinService.setPin('2580');
    final a = await SecureStorageService.getLocalPinHash();
    // Dispositivo distinto → device_id distinto → hash distinto.
    FlutterSecureStorage.setMockInitialValues({});
    await PinService.setPin('2580');
    final b = await SecureStorageService.getLocalPinHash();
    expect(a, isNot(equals(b)));
  });

  test('removePin borra y apaga', () async {
    await PinService.setPin('2580');
    await PinService.removePin();
    expect(await PinService.hasPin(), isFalse);
    expect(await PinService.isEnabled(), isFalse);
    expect(await PinService.verifyPin('2580'), isFalse);
  });

  test('isValidFormat', () {
    expect(PinService.isValidFormat('1234'), isTrue);
    expect(PinService.isValidFormat('123'), isFalse);
    expect(PinService.isValidFormat('12a4'), isFalse);
    expect(() => PinService.setPin('12'), throwsArgumentError);
  });
}
