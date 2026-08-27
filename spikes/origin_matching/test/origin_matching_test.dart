// SPDX-License-Identifier: MPL-2.0
import 'package:localhold_origin_matching_spike/origin_matching.dart';
import 'package:test/test.dart';

void main() {
  test('app requires exact ID and signer', () {
    const saved = AppOrigin(applicationId: 'com.example.bank', signerId: 'AA11');
    expect(exactOriginMatch(saved, const AppOrigin(applicationId: 'com.example.bank', signerId: 'aa11')), isTrue);
    expect(exactOriginMatch(saved, const AppOrigin(applicationId: 'com.example.bank', signerId: 'BB22')), isFalse);
    expect(exactOriginMatch(saved, const AppOrigin(applicationId: 'com.example.bank.fake', signerId: 'AA11')), isFalse);
  });

  test('web requires exact normalized host and port', () {
    const saved = WebOrigin(host: 'login.example.test');
    expect(exactOriginMatch(saved, const WebOrigin(host: 'LOGIN.EXAMPLE.TEST')), isTrue);
    expect(exactOriginMatch(saved, const WebOrigin(host: 'evil.example.test')), isFalse);
    expect(exactOriginMatch(saved, const WebOrigin(host: 'login.example.test.evil.test')), isFalse);
    expect(exactOriginMatch(saved, const WebOrigin(host: 'login.example.test', port: 8443)), isFalse);
  });

  test('ambiguous or Unicode host fails closed', () {
    expect(() => exactOriginMatch(const WebOrigin(host: '.example.test'), const WebOrigin(host: '.example.test')), throwsFormatException);
    expect(() => exactOriginMatch(const WebOrigin(host: 'exаmple.test'), const WebOrigin(host: 'exаmple.test')), throwsFormatException);
  });
}
