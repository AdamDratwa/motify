import 'package:flutter/material.dart';

import '../../../core/theme/motify_theme.dart';
import '../../../core/widgets/terminal_widgets.dart';
import '../models/free_window.dart';
import '../models/simple_time.dart';
import '../models/weekday.dart';

/// One-line summary of a free window, e.g. "Weekdays · 16:00 → midnight".
String describeFreeWindow(FreeWindow window) {
  final days = window.days;
  final String dayText;
  if (days.length == 7) {
    dayText = 'Every day';
  } else if (days.length == 2 && days.containsAll({Weekday.saturday, Weekday.sunday})) {
    dayText = 'Weekends';
  } else if (days.length == 5 &&
      !days.contains(Weekday.saturday) &&
      !days.contains(Weekday.sunday)) {
    dayText = 'Weekdays';
  } else {
    dayText = Weekday.values.where(days.contains).map((d) => d.shortLabel).join(', ');
  }

  final start = window.startTime;
  final end = window.endTime;
  final timeText = start == null && end == null
      ? 'all day'
      : '${start ?? '00:00'} → ${end ?? 'midnight'}${window.isOvernight ? ' (next day)' : ''}';
  return '$dayText · $timeText';
}

/// Lets the user create or edit a free window. Returns null if dismissed.
Future<FreeWindow?> showFreeWindowSheet(BuildContext context, {FreeWindow? initial}) =>
    showModalBottomSheet<FreeWindow>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FreeWindowSheet(initial: initial),
    );

class _FreeWindowSheet extends StatefulWidget {
  final FreeWindow? initial;
  const _FreeWindowSheet({this.initial});

  @override
  State<_FreeWindowSheet> createState() => _FreeWindowSheetState();
}

class _FreeWindowSheetState extends State<_FreeWindowSheet> {
  // Midnight stands for "start of day" (as From) and "end of day" (as To),
  // so 00:00 → 00:00 is all day; they map to null times in FreeWindow.
  static const _midnight = SimpleTime(0, 0);

  late final Set<Weekday> _days = {...?widget.initial?.days};
  late SimpleTime _from = widget.initial?.startTime ?? const SimpleTime(16, 0);
  late SimpleTime _to = widget.initial?.endTime ?? _midnight;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) _days.addAll(Weekday.values);
  }

  FreeWindow get _window => FreeWindow(
    id: widget.initial?.id ?? 'w${DateTime.now().microsecondsSinceEpoch}',
    days: _days,
    startTime: _from == _midnight ? null : _from,
    endTime: _to == _midnight ? null : _to,
  );

  Future<void> _pick({required bool from}) async {
    final current = from ? _from : _to;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
      builder: (context, child) => MediaQuery(
        // Always 24h, to match the terminal look and the summaries.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      final time = SimpleTime(picked.hour, picked.minute);
      if (from) {
        _from = time;
      } else {
        _to = time;
      }
    });
  }

  void _setDays(Set<Weekday> days) => setState(
    () => _days
      ..clear()
      ..addAll(days),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'ADD FREE TIME' : 'EDIT FREE TIME',
            style: const TextStyle(
              color: MotifyColors.neon,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'The app is unlocked during this time, whatever your goals.',
            style: TextStyle(color: MotifyColors.textDim, fontSize: 12),
          ),
          const SizedBox(height: 20),
          const TerminalLabel('days'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final day in Weekday.values)
                FilterChip(
                  label: Text(day.shortLabel),
                  selected: _days.contains(day),
                  showCheckmark: false,
                  onSelected: (on) => setState(() => on ? _days.add(day) : _days.remove(day)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton(
                onPressed: () => _setDays(Weekday.values.toSet()),
                child: const Text('EVERY DAY'),
              ),
              TextButton(
                onPressed: () => _setDays(Weekday.values.take(5).toSet()),
                child: const Text('WEEKDAYS'),
              ),
              TextButton(
                onPressed: () => _setDays({Weekday.saturday, Weekday.sunday}),
                child: const Text('WEEKENDS'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const TerminalLabel('time'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _TimeButton(label: 'FROM', time: _from, onTap: () => _pick(from: true)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('→', style: TextStyle(color: MotifyColors.textDim, fontSize: 20)),
              ),
              Expanded(
                child: _TimeButton(label: 'TO', time: _to, onTap: () => _pick(from: false)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _days.isEmpty ? '> pick at least one day' : '> ${describeFreeWindow(_window)}',
            style: TextStyle(
              color: _days.isEmpty ? MotifyColors.danger : MotifyColors.neon,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '00:00 → 00:00 is all day. A "to" time before "from" runs past midnight.',
            style: TextStyle(color: MotifyColors.textDim, fontSize: 11),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _days.isEmpty ? null : () => Navigator.of(context).pop(_window),
            child: const Text('SAVE FREE TIME'),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final SimpleTime time;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: MotifyColors.text,
      side: const BorderSide(color: MotifyColors.line),
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(color: MotifyColors.textDim, fontSize: 11)),
        const SizedBox(height: 2),
        Text('$time', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
