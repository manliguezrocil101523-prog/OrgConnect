import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class OfficerMembersScreen extends StatelessWidget {
  const OfficerMembersScreen({super.key});

  static const _p = Color(0xFF4F46E5); // primary
  static const _s = Color(0xFF06B6D4); // secondary
  static const _bg = Color(0xFFF8FAFC); // background
  static const _ok = Color(0xFF22C55E); // success

  // Position → accent color
  static Color _posColor(String pos) {
    switch (pos.toLowerCase()) {
      case 'president':
        return const Color(0xFF4F46E5);
      case 'vice president':
        return const Color(0xFF06B6D4);
      case 'secretary':
        return const Color(0xFF0D9488);
      case 'officer':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF94A3B8);
    }
  }

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
            backgroundColor: _p,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Members',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: 0.3)),
            centerTitle: true,
            flexibleSpace: FlexibleSpaceBar(
                background: _GradientHero(
              icon: Icons.groups_rounded,
              title: 'Organisation Members',
              subtitle: 'Manage and track your members',
            )),
          ),

          // ── List ──────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: AppState.instance,
            builder: (ctx, _) {
              final members = AppState.instance.members;
              if (members.isEmpty) {
                return SliverFillRemaining(
                    child: _Empty(
                  icon: Icons.groups_rounded,
                  label: 'No members yet',
                  sub: 'Add your first member to get started.',
                ));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                sliver: SliverList(
                    delegate: SliverChildListDelegate([
                  Center(
                      child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Label(
                              '${members.length} Member${members.length == 1 ? '' : 's'}'),
                          const SizedBox(height: 12),
                          ...members.asMap().entries.map((e) => _MemberCard(
                                member: e.value,
                                index: e.key,
                                accentColor: _posColor(e.value.position),
                                onEdit: () => _dialog(ctx, existing: e.value),
                                onDelete: () {
                                  AppState.instance.removeMember(e.value.id);
                                  // FIX Bug 6: use ctx (the AnimatedBuilder
                                  // context) consistently — same scope used
                                  // for edit/delete snacks.
                                  _snack(ctx, 'Removed ${e.value.name}',
                                      Colors.redAccent);
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

      // ── FAB ────────────────────────────────────────────────────────────
      floatingActionButton: _GradFab(
        icon: Icons.person_add_rounded,
        label: 'Add Member',
        onTap: () => _dialog(context),
      ),
    );
  }

  // ── Member dialog ────────────────────────────────────────────────────────
  void _dialog(BuildContext context, {Member? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final orgCtrl = TextEditingController(text: existing?.orgName ?? '');
    String position =
        existing?.position.isNotEmpty == true ? existing!.position : 'Member';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (ctx, ss) => Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DialogHeader(
                            existing == null
                                ? Icons.person_add_rounded
                                : Icons.edit_rounded,
                            existing == null ? 'Add Member' : 'Edit Member'),
                        const SizedBox(height: 20),
                        _Field(
                            ctrl: nameCtrl,
                            label: 'Full Name',
                            hint: 'Enter member name',
                            icon: Icons.person_rounded),
                        const SizedBox(height: 14),
                        // Position dropdown
                        _FieldLabel('Position'),
                        DropdownButtonFormField<String>(
                          value: position,
                          decoration: _fieldDeco(Icons.badge_rounded),
                          // FIX Bug 7: 'Member' was the default value but was
                          // missing from the items list, causing a Flutter
                          // assertion error ("value must be in items").
                          items: [
                            'Member',
                            'Officer',
                            'President',
                            'Vice President',
                            'Secretary',
                          ]
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) => ss(() => position = v ?? 'Member'),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                            ctrl: orgCtrl,
                            label: 'Organization',
                            hint: 'Enter organization name',
                            icon: Icons.groups_rounded),
                        const SizedBox(height: 22),
                        Row(children: [
                          Expanded(
                              child:
                                  _CancelBtn(onTap: () => Navigator.pop(ctx))),
                          const SizedBox(width: 12),
                          Expanded(child: _SaveBtn(onTap: () {
                            final name = nameCtrl.text.trim();
                            final org = orgCtrl.text.trim();
                            if (name.isEmpty || org.isEmpty) return;
                            if (existing == null) {
                              AppState.instance.addMember(
                                  name: name, position: position, orgName: org);
                              // FIX Bug 6: use ctx (dialog context) for snack
                              // so the messenger scope is always valid.
                              _snack(ctx, 'Added $name', _ok);
                            } else {
                              AppState.instance.updateMember(existing.copyWith(
                                  name: name,
                                  position: position,
                                  orgName: org));
                              _snack(ctx, 'Updated $name', _ok);
                            }
                            Navigator.pop(ctx);
                          })),
                        ]),
                      ],
                    )),
              )),
    );
  }

  void _snack(BuildContext ctx, String msg, Color bg) =>
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

// ── Member card ─────────────────────────────────────────────────────────────
class _MemberCard extends StatelessWidget {
  final Member member;
  final int index;
  final Color accentColor;
  final VoidCallback onEdit, onDelete;
  const _MemberCard(
      {required this.member,
      required this.index,
      required this.accentColor,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final initial = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + index * 50),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, 12 * (1 - v)), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text(initial,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w800))),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(member.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(member.orgName,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(member.position,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: accentColor)),
                    ),
                  ])),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _IconBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF4F46E5),
                    onTap: onEdit,
                    tip: 'Edit'),
                const SizedBox(width: 4),
                _IconBtn(
                    icon: Icons.delete_rounded,
                    color: const Color(0xFFEF4444),
                    onTap: onDelete,
                    tip: 'Remove'),
              ]),
            ])),
      ),
    );
  }
}

// ── Shared small widgets ────────────────────────────────────────────────────

class _GradientHero extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _GradientHero(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )),
        child: Stack(children: [
          Positioned(top: -30, right: -20, child: _orb(160, 0.07)),
          Positioned(bottom: 10, left: -40, child: _orb(120, 0.05)),
          SafeArea(
              child: Padding(
            padding: const EdgeInsets.only(top: 52, left: 24, right: 24),
            child: Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.30), width: 1.5)),
                  child: Icon(icon, color: Colors.white, size: 26)),
              const SizedBox(width: 16),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 12.5)),
                  ]),
            ]),
          )),
        ]),
      );

  Widget _orb(double size, double opacity) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)));
}

class _GradFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GradFab(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 6))
          ],
        ),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ])))),
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tip;
  const _IconBtn(
      {required this.icon,
      required this.color,
      required this.onTap,
      required this.tip});

  @override
  Widget build(BuildContext context) => Tooltip(
      message: tip,
      child: Material(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, color: color, size: 17)))));
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter))),
        const SizedBox(width: 10),
        Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: Color(0xFF94A3B8))),
      ]);
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  const _Empty({required this.icon, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.28),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]),
            child: Icon(icon, size: 36, color: Colors.white)),
        const SizedBox(height: 18),
        Text(label,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Text(sub,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
      ]));
}

// ── Dialog helpers ───────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _DialogHeader(this.icon, this.title);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child: Icon(icon, color: Colors.white, size: 18)),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ]);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 7),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151))),
      );
}

InputDecoration _fieldDeco(IconData icon, {String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(icon, color: const Color(0xFF4F46E5), size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
    );

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  const _Field(
      {required this.ctrl,
      required this.label,
      required this.hint,
      required this.icon,
      this.maxLines = 1});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _FieldLabel(label),
        TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A)),
            decoration: _fieldDeco(icon, hint: hint)),
      ]);
}

class _CancelBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CancelBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        child: const Text('Cancel',
            style: TextStyle(
                color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      );
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SaveBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.28),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                        child: Text('Save',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)))))),
      );
}
