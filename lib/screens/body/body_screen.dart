import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/glass_kit.dart';
import '../../models/body_entry.dart';
import '../../models/body_measurement.dart';
import '../../models/measurement_type.dart';
import '../../services/body_service.dart';

// ── Cálculos ──────────────────────────────────────────────────────────────────

double? calcBmi(double? weightKg, double? heightCm) {
  if (weightKg == null || heightCm == null || heightCm == 0) return null;
  final hm = heightCm / 100;
  return weightKg / (hm * hm);
}

String bmiCategory(double bmi) {
  if (bmi < 18.5) return 'Bajo peso';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Sobrepeso';
  return 'Obesidad';
}

Color bmiColor(double bmi, ColorScheme colors) {
  if (bmi < 18.5) return Colors.blue;
  if (bmi < 25) return Colors.green;
  if (bmi < 30) return Colors.orange;
  return colors.error;
}

/// Fórmula Navy para % grasa corporal (hombres).
/// Requiere: cintura, cuello y altura (todos en cm).
double? calcBodyFat(double? waistCm, double? neckCm, double? heightCm) {
  if (waistCm == null || neckCm == null || heightCm == null) return null;
  final diff = waistCm - neckCm;
  if (diff <= 0) return null;
  return 495 /
          (1.0324 -
              0.19077 * log(diff) / ln10 +
              0.15456 * log(heightCm) / ln10) -
      450;
}

class BodyScreen extends StatefulWidget {
  const BodyScreen({super.key});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  final _service = BodyService.instance;
  List<BodyEntry> _entries = [];
  List<({DateTime date, double weightKg})> _weightHistory = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _service.getAll(),
      _service.getWeightHistory(),
    ]);
    setState(() {
      _entries = results[0] as List<BodyEntry>;
      _weightHistory =
          results[1] as List<({DateTime date, double weightKg})>;
      _loading = false;
    });
  }

  Future<void> _addEntry() async {
    final lastHeight = _entries.isNotEmpty
        ? _entries.first.heightCm  // entries ordenadas DESC, primera = más reciente
        : null;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddEntrySheet(
        lastHeightCm: lastHeight,
        onSaved: () => Navigator.pop(context, true),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _deleteEntry(BodyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: const Text('¿Eliminar este registro corporal?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.delete(entry.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Cuerpo'),
        centerTitle: false,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  if (_weightHistory.length >= 2)
                    _WeightChartCard(history: _weightHistory),
                  if (_entries.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monitor_weight_outlined,
                                size: 64, color: colors.outline),
                            const SizedBox(height: 16),
                            Text('Sin registros',
                                style: TextStyle(
                                    color: colors.outline, fontSize: 18)),
                            const SizedBox(height: 8),
                            Text('Toca + para agregar medidas',
                                style: TextStyle(color: colors.outlineVariant)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._entries.map(
                      (e) => _EntryCard(
                        entry: e,
                        service: _service,
                        onDelete: () => _deleteEntry(e),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        child: FloatingActionButton.extended(
          onPressed: _addEntry,
          icon: const Icon(Icons.add),
          label: const Text('Registrar'),
        ),
      ),
    );
  }
}

// ── Weight chart ──────────────────────────────────────────────────────────────

class _WeightChartCard extends StatelessWidget {
  const _WeightChartCard({required this.history});
  final List<({DateTime date, double weightKg})> history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weightKg))
        .toList();
    final weights = history.map((h) => h.weightKg);
    final minY = weights.reduce((a, b) => a < b ? a : b);
    final maxY = weights.reduce((a, b) => a > b ? a : b);
    final yPad = (maxY - minY) * 0.3 + 2;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Peso corporal',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '${history.last.weightKg.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: LineChart(LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(0)}kg',
                        style: TextStyle(fontSize: 10, color: colors.outline),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                minY: minY - yPad,
                maxY: maxY + yPad,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: colors.primary,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 3, color: colors.primary, strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              )),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Entry card ────────────────────────────────────────────────────────────────

class _EntryCard extends StatefulWidget {
  const _EntryCard({
    required this.entry,
    required this.service,
    required this.onDelete,
  });
  final BodyEntry entry;
  final BodyService service;
  final VoidCallback onDelete;

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  List<BodyMeasurement> _measurements = [];

  @override
  void initState() {
    super.initState();
    widget.service.getMeasurementsForEntry(widget.entry.id!).then((m) {
      if (mounted) setState(() => _measurements = m);
    });
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entry = widget.entry;

    final bmi = calcBmi(entry.weightKg, entry.heightCm);
    final waist = _measurements
        .where((m) => m.type == MeasurementType.cintura)
        .firstOrNull
        ?.valueCm;
    final neck = _measurements
        .where((m) => m.type == MeasurementType.cuello)
        .firstOrNull
        ?.valueCm;
    final bodyFat = calcBodyFat(waist, neck, entry.heightCm);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        borderRadius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila superior: fecha + peso + altura + delete
            Row(
              children: [
                Text(_formatDate(entry.date),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (entry.weightKg != null) ...[
                  const SizedBox(width: 8),
                  _Pill('${entry.weightKg!.toStringAsFixed(1)} kg', colors.primaryContainer, colors.onPrimaryContainer),
                ],
                if (entry.heightCm != null) ...[
                  const SizedBox(width: 6),
                  _Pill('${entry.heightCm!.toStringAsFixed(0)} cm', colors.secondaryContainer, colors.onSecondaryContainer),
                ],
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.error),
                  onPressed: widget.onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            // IMC y % grasa
            if (bmi != null || bodyFat != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (bmi != null) ...[
                    Icon(Icons.monitor_weight_outlined, size: 14, color: bmiColor(bmi, colors)),
                    const SizedBox(width: 4),
                    Text(
                      'IMC ${bmi.toStringAsFixed(1)} · ${bmiCategory(bmi)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: bmiColor(bmi, colors),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (bmi != null && bodyFat != null) const SizedBox(width: 16),
                  if (bodyFat != null) ...[
                    Icon(Icons.percent, size: 14, color: colors.outline),
                    const SizedBox(width: 4),
                    Text(
                      'Grasa ${bodyFat.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: colors.outline),
                    ),
                  ],
                ],
              ),
            ],

            // Medidas
            if (_measurements.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _measurements
                    .map((m) => Chip(
                          label: Text('${m.type.displayName}: ${m.valueCm.toStringAsFixed(0)} cm'),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          labelStyle: TextStyle(fontSize: 11, color: colors.onSurface),
                        ))
                    .toList(),
              ),
            ],

            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(entry.notes!, style: TextStyle(color: colors.outline, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.bg, this.fg);
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

// ── Add entry sheet ───────────────────────────────────────────────────────────

class _AddEntrySheet extends StatefulWidget {
  const _AddEntrySheet({required this.onSaved, this.lastHeightCm});
  final VoidCallback onSaved;
  final double? lastHeightCm;

  @override
  State<_AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<_AddEntrySheet> {
  final _service = BodyService.instance;
  final _formKey = GlobalKey<FormState>();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Map<MeasurementType, TextEditingController> _measureCtrl = {
    for (final t in MeasurementType.values) t: TextEditingController(),
  };
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.lastHeightCm != null) {
      _heightCtrl.text = widget.lastHeightCm!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _measureCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final weightText = _weightCtrl.text.replaceAll(',', '.');
      final heightText = _heightCtrl.text.replaceAll(',', '.');
      final entry = await _service.insert(BodyEntry(
        date: DateTime.now(),
        weightKg: weightText.isEmpty ? null : double.tryParse(weightText),
        heightCm: heightText.isEmpty ? null : double.tryParse(heightText),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
      for (final t in MeasurementType.values) {
        final text = _measureCtrl[t]!.text.replaceAll(',', '.');
        if (text.isNotEmpty) {
          final value = double.tryParse(text);
          if (value != null) {
            await _service.insertMeasurement(BodyMeasurement(
              bodyEntryId: entry.id!,
              type: t,
              valueCm: value,
            ));
          }
        }
      }
      widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Nuevo registro',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Peso (kg)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.monitor_weight_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _heightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Altura (cm)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.height),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'MEDIDAS (cm)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...MeasurementType.values.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextFormField(
                          controller: _measureCtrl[t],
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: InputDecoration(
                            labelText: t.displayName,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
