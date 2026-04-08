import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class OfficerEventsScreen extends StatelessWidget {
  final String orgId, orgName;
  const OfficerEventsScreen({super.key, required this.orgId, required this.orgName});

  static const _p  = Color(0xFF4F46E5);
  static const _s  = Color(0xFF06B6D4);
  static const _bg = Color(0xFFF8FAFC);
  static const _ok = Color(0xFF22C55E);

  // UNTOUCHED
  String _dateLabel(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static const _months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: MediaQuery.of(context).size.height * 0.20,
            backgroundColor: _p, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17, letterSpacing: 0.3)),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(background: _GradientHero(orgName: orgName)),
          ),

          // ── List ──────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: AppState.instance,
            builder: (ctx, _) {
              // UNTOUCHED: original filter logic
              final events = AppState.instance.events
                  .where((e) => e.orgId == orgId || e.orgName == orgName).toList();

              if (events.isEmpty) {
                return SliverFillRemaining(child: _Empty(
                  icon: Icons.event_available_rounded,
                  label: 'No events yet',
                  sub: 'Add your first event to get started.',
                ));
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                sliver: SliverList(delegate: SliverChildListDelegate([
                  Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Label('${events.length} Event${events.length == 1 ? '' : 's'}'),
                      const SizedBox(height: 12),
                      ...events.asMap().entries.map((e) => _EventCard(
                        event: e.value, index: e.key, months: _months,
                        onEdit:   () => _dialog(ctx, existing: e.value),
                        onDelete: () {
                          AppState.instance.removeEvent(e.value.id);
                          _snack(ctx, 'Removed ${e.value.title}', Colors.redAccent);
                        },
                      )),
                    ]),
                  )),
                ])),
              );
            },
          ),
        ],
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: _GradFab(
        icon: Icons.event_available_rounded, label: 'Add Event',
        onTap: () => _dialog(context),
      ),
    );
  }

  // ── Event dialog (all original logic) ───────────────────────────────────
  void _dialog(BuildContext context, {Event? existing}) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final dateCtrl  = TextEditingController(text: existing != null ? _dateLabel(existing.date) : '');
    final descCtrl  = TextEditingController(text: existing?.description ?? '');
    DateTime? selected = existing?.date;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DialogHeader(existing == null ? Icons.event_available_rounded : Icons.edit_rounded,
                existing == null ? 'Add Event' : 'Edit Event'),
            const SizedBox(height: 20),
            _Field(ctrl: titleCtrl, label: 'Event Title', hint: 'Enter event title', icon: Icons.title_rounded),
            const SizedBox(height: 14),
            // Date picker field
            _FieldLabel('Date'),
            TextField(
              controller: dateCtrl, readOnly: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
              onTap: () async {
                final now = DateTime.now();
                final p = await showDatePicker(
                  context: ctx,
                  initialDate: selected ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 3),
                  builder: (_, child) => Theme(
                    data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _p, onPrimary: Colors.white)),
                    child: child!,
                  ),
                );
                if (p != null) ss(() { selected = p; dateCtrl.text = _dateLabel(p); });
              },
              decoration: _fieldDeco(Icons.calendar_today_rounded, hint: 'Select a date').copyWith(
                suffixIcon: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
              ),
            ),
            const SizedBox(height: 14),
            _Field(ctrl: descCtrl, label: 'Description', hint: 'Enter event description', icon: Icons.description_rounded, maxLines: 3),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: _CancelBtn(onTap: () => Navigator.pop(ctx))),
              const SizedBox(width: 12),
              Expanded(child: _SaveBtn(onTap: () {
                final title = titleCtrl.text.trim();
                final desc  = descCtrl.text.trim();
                final date  = selected ?? DateTime.now();
                if (title.isEmpty) return;
                if (existing == null) {
                  AppState.instance.addEvent(title: title, date: date, description: desc, orgName: orgName, orgId: orgId);
                  _snack(context, 'Added $title', _ok);
                } else {
                  AppState.instance.updateEvent(existing.copyWith(title: title, date: date, description: desc, orgName: orgName, orgId: orgId));
                  _snack(context, 'Updated $title', _ok);
                }
                Navigator.pop(ctx);
              })),
            ]),
          ],
        ))),
      )),
    );
  }

  void _snack(BuildContext ctx, String msg, Color bg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

// ── Event card ───────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Event event; final int index;
  final List<String> months;
  final VoidCallback onEdit, onDelete;
  const _EventCard({required this.event, required this.index, required this.months, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final upcoming = event.date.isAfter(DateTime.now());
    final accent   = upcoming ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + index * 55), curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14*(1-v)), child: child)),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: upcoming ? const Color(0xFF4F46E5).withOpacity(0.15) : const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 5))],
          ),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Date badge
            Container(width: 50, height: 56,
              decoration: BoxDecoration(
                color: upcoming ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: upcoming ? const Color(0xFF4F46E5).withOpacity(0.18) : const Color(0xFFE2E8F0)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${event.date.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent, height: 1)),
                const SizedBox(height: 2),
                Text(months[event.date.month - 1], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8,
                    color: upcoming ? const Color(0xFF06B6D4) : const Color(0xFF94A3B8))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A), letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text(event.orgName, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4)),
              ],
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: upcoming ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(upcoming ? 'Upcoming' : 'Past',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accent)),
              ),
            ])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              _IconBtn(icon: Icons.edit_rounded,   color: const Color(0xFF4F46E5), onTap: onEdit,   tip: 'Edit'),
              const SizedBox(height: 6),
              _IconBtn(icon: Icons.delete_rounded, color: const Color(0xFFEF4444), onTap: onDelete, tip: 'Remove'),
            ]),
          ])),
        ),
      ),
    );
  }
}

// ── Shared widgets (same as members screen) ──────────────────────────────────

class _GradientHero extends StatelessWidget {
  final String orgName;
  const _GradientHero({required this.orgName});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    )),
    child: Stack(children: [
      Positioned(top: -30, right: -20, child: _orb(160, 0.07)),
      Positioned(bottom: 10, left: -40, child: _orb(120, 0.05)),
      SafeArea(child: Padding(
        padding: const EdgeInsets.only(top: 52, left: 24, right: 24),
        child: Row(children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5)),
            child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 26)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Organisation Events', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(orgName, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12.5), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      )),
    ]),
  );

  Widget _orb(double size, double opacity) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)));
}

class _GradFab extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _GradFab({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
    ),
    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16),
      child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ])))),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color; final VoidCallback onTap; final String tip;
  const _IconBtn({required this.icon, required this.color, required this.onTap, required this.tip});

  @override
  Widget build(BuildContext context) => Tooltip(message: tip,
    child: Material(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
      child: InkWell(borderRadius: BorderRadius.circular(10), onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: color, size: 16)))));
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 14,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
    const SizedBox(width: 10),
    Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: Color(0xFF94A3B8))),
  ]);
}

class _Empty extends StatelessWidget {
  final IconData icon; final String label, sub;
  const _Empty({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 8))]),
      child: Icon(icon, size: 36, color: Colors.white)),
    const SizedBox(height: 18),
    Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
    const SizedBox(height: 6),
    Text(sub,   style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
  ]));
}

class _DialogHeader extends StatelessWidget {
  final IconData icon; final String title;
  const _DialogHeader(this.icon, this.title);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 40, height: 40,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Icon(icon, color: Colors.white, size: 18)),
    const SizedBox(width: 12),
    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
  ]);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 7),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
  );
}

InputDecoration _fieldDeco(IconData icon, {String? hint}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5),
  filled: true, fillColor: const Color(0xFFF8FAFC),
  prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
);

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint; final IconData icon; final int maxLines;
  const _Field({required this.ctrl, required this.label, required this.hint, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _FieldLabel(label),
    TextField(controller: ctrl, maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
      decoration: _fieldDeco(icon, hint: hint)),
  ]);
}

class _CancelBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
  );
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)], begin: Alignment.centerLeft, end: Alignment.centerRight),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(12),
      child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
        child: const Padding(padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))))),
  );
}