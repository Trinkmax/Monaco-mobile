import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:monaco_mobile/core/api/mobile_api.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';
import 'package:monaco_mobile/core/branch/test_mode_provider.dart';

import '../data/booking_api.dart';
import '../data/fechas.dart';
import 'appointments_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SUCURSALES (API mobile)
// ═══════════════════════════════════════════════════════════════════════════

/// Sucursales de la org con `bookable` resuelto por el server. Esconde Test
/// salvo en modo prueba (§6.6). Lo usa Home para saber si la sucursal elegida
/// toma turnos online y el wizard para el selector.
final mobileBranchesProvider = FutureProvider<List<MobileBranch>>((ref) async {
  final testMode = await ref.watch(testModeProvider.future);
  final res = await ref.read(bookingApiProvider).fetchBranches();
  if (testMode) return res.branches;
  return res.branches.where((b) => !b.isTest).toList();
});

/// ¿Hay AL MENOS UNA sucursal tomando turnos online? Lo mira el Home para
/// decidir si ofrece "Reservar turno".
///
/// **Falla abierto (`true`)** mientras carga o si la API no contesta: mostrar
/// el CTA de más lleva, en el peor caso, a un selector que dice "por ahora no
/// hay turnos online"; mostrarlo de menos deja al cliente sin forma de
/// reservar y sin explicación. Antes esto miraba la sucursal *elegida* en el
/// onboarding, que ya no existe.
final hayTurnosOnlineProvider = Provider<bool>((ref) {
  final branches = ref.watch(mobileBranchesProvider);
  return branches.whenOrNull(data: (list) => list.any((b) => b.bookable)) ?? true;
});

/// Bootstrap del wizard por slug (para pantallas que sólo necesitan leer la
/// configuración, p. ej. la política de cancelación del detalle).
final bookingBootstrapProvider =
    FutureProvider.autoDispose.family<BookingBootstrap, String>((ref, slug) async {
  return ref.read(bookingApiProvider).fetchBootstrap(slug);
});

/// Horas mínimas de anticipación para cancelar en una sucursal. Default 2 si
/// no se pudo leer (el server aplica la regla real igual).
final cancellationMinHoursProvider =
    Provider.autoDispose.family<int, String?>((ref, slug) {
  if (slug == null || slug.isEmpty) return 2;
  final boot = ref.watch(bookingBootstrapProvider(slug));
  return boot.whenOrNull(data: (b) => b.settings.cancellationMinHours) ?? 2;
});

// ═══════════════════════════════════════════════════════════════════════════
// WIZARD — estado
// ═══════════════════════════════════════════════════════════════════════════

enum WizardPhase { loading, failed, pickBranch, services, slot, confirmation }

/// Hora elegida + el barbero que la ofrece (el PRIMERO que la tiene libre).
class SlotSelection {
  final String time;
  final String staffId;
  final String staffName;
  final String? staffAvatarUrl;

  const SlotSelection({
    required this.time,
    required this.staffId,
    required this.staffName,
    this.staffAvatarUrl,
  });

  String get key => '$staffId@$time';
}

/// Resultado de consultar un día: grupos por barbero, o el error crudo del
/// motor. `error != null` = "sin datos" (NUNCA "lleno").
class SlotsOutcome {
  final List<SlotGroup> groups;
  final String? error;

  const SlotsOutcome.ok(this.groups) : error = null;
  const SlotsOutcome.failed(this.error) : groups = const [];

  bool get ok => error == null;
  bool get hasCupo => groups.any((g) => g.hasCupo);
}

const _unset = Object();

class BookingWizardState {
  final WizardPhase phase;

  /// Slug efectivo ('' si todavía no hay).
  final String slug;

  /// El slug con el que se entró no era reservable (walk-in): el selector lo
  /// explica.
  final bool originalNotBookable;
  final BookingBootstrap? bootstrap;
  final List<MobileBranch> branches;
  final bool branchesLoading;
  final String? loadError;

  final List<String> selectedServiceIds;
  final String? selectedDate;
  final Map<String, SlotsOutcome> slotsByDate;
  final String? loadingDate;
  final Set<String> fullDates;
  final Set<String> unknownDates;
  final List<String> suggestions;
  final bool scanning;
  final bool scanFailed;
  final SlotSelection? selectedSlot;
  final String? staffFilter;
  final bool policyAccepted;
  final String nameInput;
  final String? error;
  final bool submitting;
  final BookingResult? result;
  final bool showGreen;

  const BookingWizardState({
    this.phase = WizardPhase.loading,
    this.slug = '',
    this.originalNotBookable = false,
    this.bootstrap,
    this.branches = const [],
    this.branchesLoading = false,
    this.loadError,
    this.selectedServiceIds = const [],
    this.selectedDate,
    this.slotsByDate = const {},
    this.loadingDate,
    this.fullDates = const {},
    this.unknownDates = const {},
    this.suggestions = const [],
    this.scanning = false,
    this.scanFailed = false,
    this.selectedSlot,
    this.staffFilter,
    this.policyAccepted = false,
    this.nameInput = '',
    this.error,
    this.submitting = false,
    this.result,
    this.showGreen = false,
  });

  BookingWizardState copyWith({
    WizardPhase? phase,
    String? slug,
    bool? originalNotBookable,
    Object? bootstrap = _unset,
    List<MobileBranch>? branches,
    bool? branchesLoading,
    Object? loadError = _unset,
    List<String>? selectedServiceIds,
    Object? selectedDate = _unset,
    Map<String, SlotsOutcome>? slotsByDate,
    Object? loadingDate = _unset,
    Set<String>? fullDates,
    Set<String>? unknownDates,
    List<String>? suggestions,
    bool? scanning,
    bool? scanFailed,
    Object? selectedSlot = _unset,
    Object? staffFilter = _unset,
    bool? policyAccepted,
    String? nameInput,
    Object? error = _unset,
    bool? submitting,
    Object? result = _unset,
    bool? showGreen,
  }) {
    return BookingWizardState(
      phase: phase ?? this.phase,
      slug: slug ?? this.slug,
      originalNotBookable: originalNotBookable ?? this.originalNotBookable,
      bootstrap: bootstrap == _unset ? this.bootstrap : bootstrap as BookingBootstrap?,
      branches: branches ?? this.branches,
      branchesLoading: branchesLoading ?? this.branchesLoading,
      loadError: loadError == _unset ? this.loadError : loadError as String?,
      selectedServiceIds: selectedServiceIds ?? this.selectedServiceIds,
      selectedDate: selectedDate == _unset ? this.selectedDate : selectedDate as String?,
      slotsByDate: slotsByDate ?? this.slotsByDate,
      loadingDate: loadingDate == _unset ? this.loadingDate : loadingDate as String?,
      fullDates: fullDates ?? this.fullDates,
      unknownDates: unknownDates ?? this.unknownDates,
      suggestions: suggestions ?? this.suggestions,
      scanning: scanning ?? this.scanning,
      scanFailed: scanFailed ?? this.scanFailed,
      selectedSlot: selectedSlot == _unset ? this.selectedSlot : selectedSlot as SlotSelection?,
      staffFilter: staffFilter == _unset ? this.staffFilter : staffFilter as String?,
      policyAccepted: policyAccepted ?? this.policyAccepted,
      nameInput: nameInput ?? this.nameInput,
      error: error == _unset ? this.error : error as String?,
      submitting: submitting ?? this.submitting,
      result: result == _unset ? this.result : result as BookingResult?,
      showGreen: showGreen ?? this.showGreen,
    );
  }

  // ── Derivados ──────────────────────────────────────────────────────────

  BookingSettings? get settings => bootstrap?.settings;

  /// Servicios elegidos, en el orden en que se tocaron ([0] = principal).
  List<PublicService> get selectedServices {
    final b = bootstrap;
    if (b == null) return const [];
    final byId = {for (final s in b.services) s.id: s};
    return selectedServiceIds.map((id) => byId[id]).whereType<PublicService>().toList();
  }

  num get totalPrice => selectedServices.fold<num>(0, (acc, s) => acc + s.price);

  /// Un servicio sin duración cuenta `slot_interval_minutes`, igual que el motor.
  int get totalDuration {
    final step = settings?.slotIntervalMinutes ?? 15;
    return selectedServices.fold<int>(0, (acc, s) => acc + (s.durationMinutes ?? step));
  }

  /// `settings.appointment_days ∩ días de algún barbero`; si el cruce queda
  /// vacío, los configurados tal cual (§3 del turnero web).
  List<int> get enabledDays {
    final b = bootstrap;
    if (b == null) return const [];
    final configured = b.settings.appointmentDays;
    final staffDays = <int>{for (final s in b.staff) ...s.days};
    final cruce = configured.where(staffDays.contains).toList();
    return cruce.isEmpty ? configured : cruce;
  }

  /// Días de la tira: desde `server_today` hasta `max_advance_days`, cortando
  /// en el primer día fuera de ventana (§6.a).
  List<String> get windowDays {
    final b = bootstrap;
    if (b == null) return const [];
    return diasDeVentana(
      today: b.serverToday,
      maxAdvanceDays: b.settings.maxAdvanceDays,
      nowUtc: b.nowFromServer,
      tz: b.branch.timezone,
    );
  }

  String? get primerDiaHabilitado {
    final enabled = enabledDays;
    for (final d in windowDays) {
      if (enabled.contains(Fechas.dayOfWeek(d))) return d;
    }
    return null;
  }

  SlotsOutcome? get currentOutcome =>
      selectedDate == null ? null : slotsByDate[selectedDate!];

  bool get loadingCurrent => selectedDate != null && loadingDate == selectedDate;

  /// Nombre que ya conocemos del cliente (app o bootstrap). Vacío = pedirlo.
  String knownName(AuthState auth) {
    if (auth.firstName.isNotEmpty) return (auth.clientName ?? '').trim();
    final fromServer = bootstrap?.client.fullName ?? '';
    final first = fromServer.split(RegExp(r'\s+')).first;
    if (fromServer.isNotEmpty && !RegExp(r'^\d+$').hasMatch(first)) return fromServer;
    return '';
  }

  bool get nameInputValid => nameInput.trim().length >= 2;

  /// 1-based sobre los TRES pasos visibles: Sucursal → Servicio → Día y hora.
  int get stepIndex => switch (phase) {
        WizardPhase.slot => 3,
        WizardPhase.services => 2,
        _ => 1,
      };

  /// Etiqueta del paso actual, para el `StepProgress`.
  String get stepLabel => switch (phase) {
        WizardPhase.slot => 'Día y horario',
        WizardPhase.services => 'Servicio',
        _ => 'Sucursal',
      };
}

// ── Ventana de fechas (réplica de `ventana.ts`) ────────────────────────────

/// El motor compara `date@12:00` (en la TZ del proceso, UTC en Vercel) contra
/// `now + max_advance_days`. Replicamos el chequeo bajo DOS lecturas —UTC y la
/// zona de la sucursal— y descartamos el día si cualquiera lo rechaza: mejor
/// ofrecer un día menos que un día que el server va a rechazar.
bool fechaDentroDeVentana({
  required String dateStr,
  required int maxAdvanceDays,
  required DateTime nowUtc,
  required String tz,
}) {
  final maxDate = nowUtc.toUtc().add(Duration(days: maxAdvanceDays));
  final d = Fechas.parseDate(dateStr);
  final lecturaUtc = DateTime.utc(d.year, d.month, d.day, 12);
  final lecturaTz = lecturaUtc.subtract(Fechas.offsetOf(tz));
  return !lecturaUtc.isAfter(maxDate) && !lecturaTz.isAfter(maxDate);
}

List<String> diasDeVentana({
  required String today,
  required int maxAdvanceDays,
  required DateTime nowUtc,
  required String tz,
}) {
  final out = <String>[];
  for (var i = 0; i <= maxAdvanceDays; i++) {
    final d = Fechas.addDays(today, i);
    if (!fechaDentroDeVentana(
      dateStr: d,
      maxAdvanceDays: maxAdvanceDays,
      nowUtc: nowUtc,
      tz: tz,
    )) {
      break;
    }
    out.add(d);
  }
  return out;
}

/// Las próximas `n` fechas habilitadas después de `dateStr` dentro de la tira.
List<String> proximosDias(
  String dateStr,
  List<int> enabledDays,
  List<String> windowDays, {
  int n = 3,
}) {
  final out = <String>[];
  for (final d in windowDays) {
    if (d.compareTo(dateStr) <= 0) continue;
    if (!enabledDays.contains(Fechas.dayOfWeek(d))) continue;
    out.add(d);
    if (out.length >= n) break;
  }
  return out;
}

// ═══════════════════════════════════════════════════════════════════════════
// WIZARD — controller
// ═══════════════════════════════════════════════════════════════════════════

/// Un controller por slug pedido ('' = "la sucursal elegida en la app").
final bookingWizardProvider = StateNotifierProvider.autoDispose
    .family<BookingWizardController, BookingWizardState, String>((ref, requestedSlug) {
  return BookingWizardController(ref, requestedSlug: requestedSlug);
});

class BookingWizardController extends StateNotifier<BookingWizardState> {
  final Ref _ref;
  final String requestedSlug;

  BookingWizardController(this._ref, {required this.requestedSlug})
      : super(const BookingWizardState()) {
    _init();
  }

  BookingApi get _api => _ref.read(bookingApiProvider);

  // ── Carga inicial ──────────────────────────────────────────────────────

  /// Paso 1 = sucursal, SIEMPRE — salvo deep-link con `?branch=<slug>`, que es
  /// el único caso en que ya sabemos dónde quiere reservar (QR del local, push,
  /// link compartido). La app no tiene sucursal guardada: elegirla es parte de
  /// reservar, no del onboarding.
  Future<void> _init() async {
    if (requestedSlug.isEmpty) {
      await _loadBranches(originalNotBookable: false);
      return;
    }
    await _loadBootstrap(requestedSlug, fromPicker: false);
  }

  Future<void> retryLoad() async {
    state = state.copyWith(phase: WizardPhase.loading, loadError: null);
    if (state.slug.isNotEmpty) {
      await _loadBootstrap(state.slug, fromPicker: state.originalNotBookable);
    } else {
      await _loadBranches(originalNotBookable: state.originalNotBookable);
    }
  }

  Future<void> _loadBootstrap(String slug, {required bool fromPicker}) async {
    state = state.copyWith(phase: WizardPhase.loading, slug: slug, loadError: null);
    try {
      final boot = await _api.fetchBootstrap(slug);
      if (!mounted) return;
      if (!boot.bookable) {
        await _loadBranches(originalNotBookable: true);
        return;
      }
      state = state.copyWith(
        phase: WizardPhase.services,
        bootstrap: boot,
        slug: slug,
        selectedServiceIds: const [],
        selectedDate: null,
        slotsByDate: const {},
        fullDates: const {},
        unknownDates: const {},
        suggestions: const [],
        selectedSlot: null,
        staffFilter: null,
        policyAccepted: false,
        error: null,
      );
    } on MobileApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'NOT_BOOKABLE' || e.code == 'BRANCH_NOT_FOUND') {
        await _loadBranches(originalNotBookable: true);
        return;
      }
      state = state.copyWith(phase: WizardPhase.failed, loadError: e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[turnos] bootstrap $slug falló: $e');
      state = state.copyWith(
        phase: WizardPhase.failed,
        loadError: 'No pudimos cargar el turnero. Probá de nuevo.',
      );
    }
  }

  Future<void> _loadBranches({required bool originalNotBookable}) async {
    // El skeleton sólo si NO tenemos lista: al volver del paso 2 al 1 ya la
    // tenemos, y parpadear en gris una lista que el cliente acaba de ver se
    // siente como que la app se reinició. Igual se refresca por debajo
    // (`open_now` cambia durante el día).
    state = state.copyWith(
      phase: WizardPhase.pickBranch,
      originalNotBookable: originalNotBookable,
      branchesLoading: state.branches.isEmpty,
      loadError: null,
    );
    try {
      final testMode = await _ref.read(testModeProvider.future);
      final res = await _api.fetchBranches();
      if (!mounted) return;
      final list = res.branches
          .where((b) => b.bookable && (testMode || !b.isTest))
          .toList();
      state = state.copyWith(branches: list, branchesLoading: false);
    } on MobileApiException catch (e) {
      if (!mounted) return;
      _branchesFallaron(e.message);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[turnos] branches falló: $e');
      _branchesFallaron('No pudimos cargar las sucursales. Probá de nuevo.');
    }
  }

  /// Si YA teníamos la lista (volvimos al paso 1), un refresco fallido no puede
  /// tirar al cliente a la pantalla de error: se queda con la lista que tenía.
  void _branchesFallaron(String mensaje) {
    if (state.branches.isNotEmpty) {
      state = state.copyWith(branchesLoading: false);
      return;
    }
    state = state.copyWith(
      phase: WizardPhase.failed,
      branchesLoading: false,
      loadError: mensaje,
    );
  }

  /// El cliente eligió una sucursal del selector.
  Future<void> pickBranch(MobileBranch branch) async {
    await _loadBootstrap(branch.slug, fromPicker: true);
  }

  // ── Paso 1: servicios ──────────────────────────────────────────────────

  void toggleService(String id) {
    final ids = List<String>.from(state.selectedServiceIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    // La duración cambia la grilla: se limpia la hora elegida y el cache.
    state = state.copyWith(
      selectedServiceIds: ids,
      selectedSlot: null,
      slotsByDate: const {},
      fullDates: const {},
      unknownDates: const {},
      suggestions: const [],
      scanFailed: false,
      error: null,
    );
  }

  // ── Navegación entre pasos ─────────────────────────────────────────────

  bool get canProceed {
    switch (state.phase) {
      case WizardPhase.services:
        return state.selectedServiceIds.isNotEmpty;
      case WizardPhase.slot:
        return state.selectedDate != null &&
            state.selectedSlot != null &&
            state.policyAccepted;
      case WizardPhase.loading:
      case WizardPhase.failed:
      case WizardPhase.pickBranch:
      case WizardPhase.confirmation:
        return false;
    }
  }

  void goNext() {
    if (state.phase != WizardPhase.services) return;
    if (state.selectedServiceIds.isEmpty) {
      state = state.copyWith(error: 'Seleccioná al menos un servicio para continuar.');
      return;
    }
    final date = state.selectedDate ?? state.primerDiaHabilitado;
    state = state.copyWith(phase: WizardPhase.slot, selectedDate: date, error: null);
    if (date != null) unawaited(_loadSlots(date));
  }

  /// `true` si el wizard retrocedió un paso; `false` si hay que salir.
  bool goBack() {
    switch (state.phase) {
      case WizardPhase.slot:
        state = state.copyWith(phase: WizardPhase.services, error: null);
        return true;
      case WizardPhase.services:
        // Volver al paso 1 tiene que OLVIDAR la sucursal: si sólo cambiáramos
        // de fase, el título del header y el paso de horarios seguirían
        // mostrando la sucursal anterior. `slug: ''` además hace que
        // `retryLoad` reintente la lista de sucursales y no un bootstrap.
        state = state.copyWith(
          phase: WizardPhase.pickBranch,
          bootstrap: null,
          slug: '',
          selectedServiceIds: const [],
          selectedDate: null,
          slotsByDate: const {},
          fullDates: const {},
          unknownDates: const {},
          suggestions: const [],
          selectedSlot: null,
          staffFilter: null,
          policyAccepted: false,
          error: null,
        );
        unawaited(_loadBranches(originalNotBookable: false));
        return true;
      case WizardPhase.loading:
      case WizardPhase.failed:
        // Si ya listamos sucursales, atrás vuelve al paso 1 en vez de cerrar el
        // wizard. Sin esto, elegir sucursal es un camino de ida: si el bootstrap
        // de la que tocó tarda o falla, el único botón que hay reintenta SIEMPRE
        // la misma (`retryLoad` ramifica por `state.slug`) y el atrás sale de la
        // pantalla. Cuando el selector era un fallback raro daba igual; ahora es
        // el paso 1 de toda reserva.
        if (state.branches.isEmpty) return false;
        state = state.copyWith(
          phase: WizardPhase.pickBranch,
          bootstrap: null,
          slug: '',
          loadError: null,
          error: null,
        );
        return true;
      case WizardPhase.pickBranch:
      case WizardPhase.confirmation:
        return false;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  // ── Paso 2: día y horario ──────────────────────────────────────────────

  void selectDate(String date) {
    if (state.selectedDate == date && state.slotsByDate.containsKey(date)) {
      // Re-tocar el día seleccionado sin datos = reintentar.
      if (state.unknownDates.contains(date)) unawaited(_loadSlots(date, force: true));
      return;
    }
    state = state.copyWith(
      selectedDate: date,
      selectedSlot: null,
      suggestions: const [],
      scanFailed: false,
      error: null,
    );
    unawaited(_loadSlots(date, force: state.unknownDates.contains(date)));
  }

  void retryDate(String date) => unawaited(_loadSlots(date, force: true));

  void selectSlot(SlotSelection sel) {
    state = state.copyWith(selectedSlot: sel, error: null);
  }

  /// Filtro de barbero desde la hoja. Limpia la hora elegida (la grilla cambia).
  void setStaffFilter(String? staffId) {
    state = state.copyWith(staffFilter: staffId, selectedSlot: null, error: null);
  }

  void setPolicyAccepted(bool v) {
    state = state.copyWith(policyAccepted: v, error: null);
  }

  void setNameInput(String v) {
    state = state.copyWith(nameInput: v, error: null);
  }

  Future<SlotsOutcome> _fetchOutcome(String date) async {
    try {
      final res = await _api.fetchSlots(
        slug: state.slug,
        date: date,
        serviceIds: state.selectedServiceIds,
      );
      if (!res.ok) return SlotsOutcome.failed(res.error);
      return SlotsOutcome.ok(res.groups);
    } on MobileApiException catch (e) {
      return SlotsOutcome.failed(e.message);
    } catch (e) {
      debugPrint('[turnos] slots $date falló: $e');
      return const SlotsOutcome.failed(
          'No pudimos leer la disponibilidad. Reintentá en un momento.');
    }
  }

  Future<void> _loadSlots(String date, {bool force = false}) async {
    final cached = state.slotsByDate[date];
    if (!force && cached != null) {
      _applyMark(date, cached);
      if (cached.ok && !cached.hasCupo) unawaited(_scanNext(date));
      return;
    }
    state = state.copyWith(loadingDate: date);
    final outcome = await _fetchOutcome(date);
    if (!mounted) return;
    final map = Map<String, SlotsOutcome>.from(state.slotsByDate)..[date] = outcome;
    state = state.copyWith(
      slotsByDate: map,
      loadingDate: state.loadingDate == date ? null : state.loadingDate,
    );
    _applyMark(date, outcome);
    if (state.selectedDate == date && outcome.ok && !outcome.hasCupo) {
      await _scanNext(date);
    }
  }

  void _applyMark(String date, SlotsOutcome outcome) {
    final full = Set<String>.from(state.fullDates);
    final unknown = Set<String>.from(state.unknownDates);
    if (!outcome.ok) {
      unknown.add(date);
      full.remove(date);
    } else if (outcome.hasCupo) {
      unknown.remove(date);
      full.remove(date);
    } else {
      full.add(date);
      unknown.remove(date);
    }
    state = state.copyWith(fullDates: full, unknownDates: unknown);
  }

  /// Sin cupo en el día elegido: busca hasta 3 próximas fechas habilitadas
  /// con lugar (en paralelo, usando el cache).
  Future<void> _scanNext(String date) async {
    final candidates = proximosDias(date, state.enabledDays, state.windowDays);
    if (candidates.isEmpty) {
      state = state.copyWith(suggestions: const [], scanning: false, scanFailed: false);
      return;
    }
    state = state.copyWith(scanning: true, scanFailed: false, suggestions: const []);
    final results = await Future.wait(candidates.map((d) async {
      final cached = state.slotsByDate[d];
      if (cached != null && cached.ok) return MapEntry(d, cached);
      return MapEntry(d, await _fetchOutcome(d));
    }));
    if (!mounted) return;
    final map = Map<String, SlotsOutcome>.from(state.slotsByDate);
    for (final r in results) {
      map[r.key] = r.value;
    }
    state = state.copyWith(slotsByDate: map);
    for (final r in results) {
      _applyMark(r.key, r.value);
    }
    if (state.selectedDate != date) {
      state = state.copyWith(scanning: false);
      return;
    }
    final sugerencias = results.where((r) => r.value.ok && r.value.hasCupo).map((r) => r.key).toList();
    final fallidos = results.every((r) => !r.value.ok);
    state = state.copyWith(suggestions: sugerencias, scanning: false, scanFailed: fallidos);
  }

  // ── Confirmar ──────────────────────────────────────────────────────────

  Future<void> confirm() async {
    if (state.phase != WizardPhase.slot || state.submitting) return;
    final date = state.selectedDate;
    final slot = state.selectedSlot;
    if (date == null || slot == null) {
      state = state.copyWith(error: 'Elegí un horario para continuar.');
      return;
    }
    if (!state.policyAccepted) {
      state = state.copyWith(error: 'Aceptá la política de cancelación para confirmar.');
      return;
    }
    final auth = _ref.read(authProvider);
    final known = state.knownName(auth);
    final needsName = known.isEmpty;
    if (needsName && !state.nameInputValid) {
      state = state.copyWith(error: 'Ingresá tu nombre para continuar.');
      return;
    }

    state = state.copyWith(submitting: true, error: null);
    try {
      final res = await _api.book(
        slug: state.slug,
        staffId: slot.staffId,
        date: date,
        startTime: slot.time,
        serviceIds: state.selectedServiceIds,
        durationMinutes: state.totalDuration,
        name: needsName ? state.nameInput.trim() : null,
      );
      if (!mounted) return;
      invalidateAppointments(_ref);
      if (needsName) {
        unawaited(_ref.read(authProvider.notifier).updateClientName(state.nameInput.trim()));
      }
      state = state.copyWith(
        submitting: false,
        result: res,
        showGreen: true,
        phase: WizardPhase.confirmation,
        error: null,
      );
    } on MobileApiException catch (e) {
      if (!mounted) return;
      final msg = bookingErrorMessage(e);
      if (bookingErrorNeedsReload(e)) {
        final map = Map<String, SlotsOutcome>.from(state.slotsByDate)..remove(date);
        state = state.copyWith(
          submitting: false,
          error: msg,
          selectedSlot: null,
          slotsByDate: map,
        );
        unawaited(_loadSlots(date, force: true));
        return;
      }
      state = state.copyWith(submitting: false, error: msg);
    } catch (e) {
      if (!mounted) return;
      debugPrint('[turnos] book falló: $e');
      state = state.copyWith(
        submitting: false,
        error: 'No pudimos confirmar el turno. Probá de nuevo en un momento.',
      );
    }
  }

  /// La animación verde terminó.
  void greenDone() {
    if (state.showGreen) state = state.copyWith(showGreen: false);
  }
}
