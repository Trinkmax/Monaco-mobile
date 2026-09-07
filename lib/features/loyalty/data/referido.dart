/// Una fila de `get_client_referrals()` (mig 197): una invitación en la que el
/// cliente participa, como quien invitó (`iAmReferrer`) o como invitado.
///
/// `status` viene de `referrals.status` (`pending | completed | cancelled`;
/// los `rejected` no los devuelve la RPC). `points` son los puntos que le
/// tocan a ESTE cliente por esa invitación (los del recomendador si invitó,
/// los del referido si fue invitado).
class Referido {
  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final int points;
  final String? friendFirstName;
  final bool iAmReferrer;

  const Referido({
    required this.id,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.points = 0,
    this.friendFirstName,
    this.iAmReferrer = true,
  });

  factory Referido.fromJson(Map<String, dynamic> j) => Referido(
        id: j['id']?.toString() ?? '',
        status: (j['status'] ?? 'pending').toString().trim(),
        createdAt: _fecha(j['created_at']),
        completedAt: _fecha(j['completed_at']),
        points: (j['points'] as num?)?.toInt() ?? 0,
        friendFirstName: _limpio(j['friend_first_name']),
        iAmReferrer: j['i_am_referrer'] != false,
      );

  bool get completada => status == 'completed';
  bool get pendiente => status == 'pending';
  bool get cancelada => status == 'cancelled' || status == 'rejected';

  static String? _limpio(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _fecha(Object? v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }
}
