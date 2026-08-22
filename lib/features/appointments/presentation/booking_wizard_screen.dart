import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:monaco_mobile/app/theme/monaco_colors.dart';
import 'package:monaco_mobile/app/widgets/glass/liquid.dart';
import 'package:monaco_mobile/core/auth/auth_provider.dart';

import '../providers/booking_provider.dart';
import 'widgets/barber_sheet.dart';
import 'widgets/branch_picker_step.dart';
import 'widgets/confirmacion_verde.dart';
import 'widgets/confirmation_step.dart';
import 'widgets/services_step.dart';
import 'widgets/slot_step.dart';
import 'widgets/step_progress.dart';
import 'widgets/wizard_footer.dart';

/// Wizard nativo de reserva: Servicio → Día y horario → confirmación.
///
/// La identidad no se pide (el cliente está logueado; el server la saca del
/// JWT). La sucursal es `branchSlug ?? authState.selectedBranchSlug`; si no
/// toma turnos online (o no hay slug), se muestra un selector de sucursales
/// reservables.
class BookingWizardScreen extends ConsumerStatefulWidget {
  final String? branchSlug;
  const BookingWizardScreen({super.key, this.branchSlug});

  @override
  ConsumerState<BookingWizardScreen> createState() => _BookingWizardScreenState();
}

class _BookingWizardScreenState extends ConsumerState<BookingWizardScreen> {
  final _ctaKey = GlobalKey();
  final _nameCtrl = TextEditingController();
  Offset? _greenOrigin;

  String get _key => widget.branchSlug ?? '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _salir() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/turnos');
    }
  }

  /// Botón atrás (sistema o header): retrocede de paso; en confirmación sale a
  /// /turnos; si no hay a dónde volver, cierra.
  void _back() {
    final ctrl = ref.read(bookingWizardProvider(_key).notifier);
    final state = ref.read(bookingWizardProvider(_key));
    if (state.phase == WizardPhase.confirmation) {
      context.go('/turnos');
      return;
    }
    if (state.submitting) return;
    if (!ctrl.goBack()) _salir();
  }

  Future<void> _elegirBarbero() async {
    final state = ref.read(bookingWizardProvider(_key));
    final boot = state.bootstrap;
    if (boot == null) return;
    final choice = await showBarberSheet(
      context,
      staff: boot.staff,
      walkIn: boot.walkInStaff,
      current: state.staffFilter,
    );
    if (choice == null || !mounted) return;
    ref.read(bookingWizardProvider(_key).notifier).setStaffFilter(choice.staffId);
  }

  void _onNext() {
    final ctrl = ref.read(bookingWizardProvider(_key).notifier);
    final state = ref.read(bookingWizardProvider(_key));
    if (state.phase == WizardPhase.services) {
      ctrl.goNext();
      return;
    }
    if (state.phase == WizardPhase.slot) {
      FocusScope.of(context).unfocus();
      // Guardamos de dónde sale el verde ANTES de confirmar.
      final box = _ctaKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final topLeft = box.localToGlobal(Offset.zero);
        _greenOrigin = topLeft + Offset(box.size.width / 2, box.size.height / 2);
      }
      ctrl.confirm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingWizardProvider(_key));
    final ctrl = ref.read(bookingWizardProvider(_key).notifier);
    final auth = ref.watch(authProvider);
    final knownName = state.knownName(auth);
    final needsName = knownName.isEmpty;

    final enConfirmacion = state.phase == WizardPhase.confirmation;
    final conPasos = state.phase == WizardPhase.services || state.phase == WizardPhase.slot;
    final titulo = state.bootstrap?.branch.name ?? 'Reservar turno';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: MonacoColors.background,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Column(
              children: [
                LiquidAppBar(
                  title: enConfirmacion ? 'Listo' : titulo,
                  showBackButton: true,
                  onBack: _back,
                  scrolled: true,
                  actions: enConfirmacion
                      ? [
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: () => context.go('/turnos'),
                            icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ]
                      : null,
                ),
                if (conPasos)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: StepProgress(
                      current: state.stepIndex,
                      total: 2,
                      label: state.phase == WizardPhase.slot ? 'Día y horario' : 'Servicio',
                    ),
                  ),
                Expanded(child: _body(state, ctrl, auth)),
                if (conPasos)
                  WizardFooter(
                    state: state,
                    needsName: needsName,
                    canProceed: ctrl.canProceed,
                    showBack: state.phase == WizardPhase.slot,
                    onBack: _back,
                    onNext: _onNext,
                    onPolicy: ctrl.setPolicyAccepted,
                    onName: ctrl.setNameInput,
                    nameController: _nameCtrl,
                    ctaKey: _ctaKey,
                  ),
              ],
            ),
            if (state.showGreen)
              Positioned.fill(
                child: ConfirmacionVerde(
                  origin: _greenOrigin,
                  onDone: ctrl.greenDone,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BookingWizardState state, BookingWizardController ctrl, AuthState auth) {
    switch (state.phase) {
      case WizardPhase.loading:
        return ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: const [
            LiquidSkeleton.line(width: 200, height: 24),
            SizedBox(height: 10),
            LiquidSkeleton.line(width: 260, height: 14),
            SizedBox(height: 22),
            LiquidSkeleton(height: 76, radius: 20),
            SizedBox(height: 10),
            LiquidSkeleton(height: 76, radius: 20),
            SizedBox(height: 10),
            LiquidSkeleton(height: 76, radius: 20),
          ],
        );
      case WizardPhase.failed:
        return LiquidErrorState(
          error: state.loadError,
          title: 'No pudimos cargar el turnero',
          message: state.loadError,
          onRetry: ctrl.retryLoad,
        );
      case WizardPhase.pickBranch:
        return BranchPickerStep(
          branches: state.branches,
          loading: state.branchesLoading,
          originalNotBookable: state.originalNotBookable,
          originalBranchName: auth.selectedBranchName,
          onPick: ctrl.pickBranch,
        );
      case WizardPhase.services:
        final boot = state.bootstrap!;
        return ServicesStep(
          services: boot.services,
          selectedIds: state.selectedServiceIds,
          onToggle: ctrl.toggleService,
          welcomeMessage: boot.branding.welcomeMessage,
          upcoming: boot.client.upcoming,
          firstName: auth.firstName.isNotEmpty
              ? auth.firstName
              : (boot.client.firstName.isNotEmpty ? boot.client.firstName : null),
        );
      case WizardPhase.slot:
        return SlotStep(
          state: state,
          onSelectDate: ctrl.selectDate,
          onRetryDate: ctrl.retryDate,
          onSelectSlot: ctrl.selectSlot,
          onElegirBarbero: _elegirBarbero,
        );
      case WizardPhase.confirmation:
        final nombre = state.knownName(auth).isNotEmpty ? state.knownName(auth) : state.nameInput.trim();
        final phone = auth.clientPhone ?? state.bootstrap?.client.phone ?? '';
        return ConfirmationStep(
          state: state,
          clientName: nombre,
          clientPhone: phone,
          onVerTurno: () {
            final id = state.result?.appointmentId;
            if (id != null && id.isNotEmpty) {
              context.go('/turnos/$id');
            } else {
              context.go('/turnos');
            }
          },
          onIrMisTurnos: () => context.go('/turnos'),
        );
    }
  }
}
