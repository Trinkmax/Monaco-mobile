/// Compat shim — re-exporta el nuevo sistema "Liquid Glass" con los nombres
/// antiguos `GlassCard`, `GlassPill`, `GlassBackdrop` para que código legacy
/// siga compilando mientras se migra a los nuevos widgets.
///
/// Preferí importar desde `glass/liquid.dart` en código nuevo.
library;

import 'glass/liquid_backdrop.dart';
import 'glass/liquid_glass.dart';
import 'glass/liquid_pill.dart';

export 'glass/liquid.dart';

typedef GlassCard = LiquidGlass;
typedef GlassPill = LiquidPill;
typedef GlassBackdrop = LiquidBackdrop;
