import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/supabase/supabase_provider.dart';

import '../data/appointment_model.dart';
import '../data/appointments_repository.dart';

/// Provider del repositorio (singleton ligado al Supabase client).
final appointmentsRepositoryProvider =
    Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository(ref.watch(supabaseClientProvider));
});

/// Turnos próximos del cliente autenticado.
final upcomingAppointmentsProvider =
    FutureProvider<List<Appointment>>((ref) async {
  final clientId = ref.watch(authProvider).clientId;
  if (clientId == null) return [];
  final repo = ref.read(appointmentsRepositoryProvider);
  return repo.fetchUpcoming(clientId);
});

/// Turnos pasados del cliente (últimos 50).
final pastAppointmentsProvider =
    FutureProvider<List<Appointment>>((ref) async {
  final clientId = ref.watch(authProvider).clientId;
  if (clientId == null) return [];
  final repo = ref.read(appointmentsRepositoryProvider);
  return repo.fetchPast(clientId);
});

/// Estado de la mutación de cancelación.
class CancelAppointmentState {
  final bool isLoading;
  final String? error;
  final bool justCancelled;

  const CancelAppointmentState({
    this.isLoading = false,
    this.error,
    this.justCancelled = false,
  });

  CancelAppointmentState copyWith({
    bool? isLoading,
    String? error,
    bool? justCancelled,
  }) {
    return CancelAppointmentState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      justCancelled: justCancelled ?? this.justCancelled,
    );
  }
}

/// Notifier que orquesta cancelaciones + invalida los providers de listado.
class AppointmentsNotifier extends StateNotifier<CancelAppointmentState> {
  final Ref _ref;

  AppointmentsNotifier(this._ref) : super(const CancelAppointmentState());

  Future<bool> cancelByToken(String token, {String? reason}) async {
    state = const CancelAppointmentState(isLoading: true);
    try {
      await _ref
          .read(appointmentsRepositoryProvider)
          .cancelByToken(token, reason: reason);

      // Refrescar ambas listas (próximos y pasados) ya que un turno cancelado
      // pasa de upcoming a past.
      _ref.invalidate(upcomingAppointmentsProvider);
      _ref.invalidate(pastAppointmentsProvider);

      state = const CancelAppointmentState(justCancelled: true);
      return true;
    } on AppointmentCancelException catch (e) {
      state = CancelAppointmentState(error: e.userMessage);
      return false;
    } catch (e) {
      state = const CancelAppointmentState(
          error: 'No pudimos cancelar el turno. Intentalo de nuevo.');
      return false;
    }
  }

  void clear() {
    state = const CancelAppointmentState();
  }
}

final appointmentsNotifierProvider =
    StateNotifierProvider<AppointmentsNotifier, CancelAppointmentState>(
        (ref) => AppointmentsNotifier(ref));
