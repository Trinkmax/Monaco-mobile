import 'package:flutter_test/flutter_test.dart';

import 'package:monaco_mobile/core/push/push_handler.dart';

/// El ruteo de push y bandeja. Las notificaciones de fidelización llegan con
/// `type = reward | points` y la familia en `data.loyalty_kind` (así las
/// escribe `loyalty_notify`, mig 197); `deep_link` gana siempre.
void main() {
  test('deep_link interno gana', () {
    expect(
      PushHandler.routeForData({'type': 'points', 'deep_link': '/categoria', 'loyalty_kind': 'tier_up'}),
      '/categoria',
    );
  });

  test('sin deep_link, la familia de loyalty_kind decide antes que el type', () {
    expect(PushHandler.routeForData({'type': 'reward', 'loyalty_kind': 'benefit_new'}), '/mis-premios');
    expect(PushHandler.routeForData({'type': 'points', 'loyalty_kind': 'tier_up'}), '/categoria');
    expect(PushHandler.routeForData({'type': 'points', 'loyalty_kind': 'near_tier'}), '/categoria');
    expect(PushHandler.routeForData({'type': 'points', 'loyalty_kind': 'tier_grace_warning'}), '/categoria');
    expect(PushHandler.routeForData({'type': 'points', 'loyalty_kind': 'points_expiring'}), '/points');
    expect(PushHandler.routeForData({'type': 'reward', 'loyalty_kind': 'reward_unlocked'}), '/rewards');
    expect(PushHandler.routeForData({'type': 'points', 'loyalty_kind': 'referral_completed_referrer'}), '/invitar');
  });

  test('sin loyalty_kind manda el type', () {
    expect(PushHandler.routeForData({'type': 'reward'}), '/rewards');
    expect(PushHandler.routeForData({'type': 'points'}), '/points');
    expect(PushHandler.routeForData({'type': 'appointment_reminder'}), '/turnos');
    expect(PushHandler.routeForData({'type': 'campaign'}), '/home');
    expect(PushHandler.routeForData({'type': 'reward', 'loyalty_kind': ''}), '/rewards');
  });

  test('un deep_link externo se ignora', () {
    expect(PushHandler.routeForData({'type': 'promo', 'deep_link': 'https://x.com'}), '/home');
    expect(PushHandler.routeForData({'type': 'promo', 'deep_link': '//x.com'}), '/home');
  });
}
