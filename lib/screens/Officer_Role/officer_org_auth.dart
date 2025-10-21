import 'package:flutter/material.dart';
import '../../core/app_state.dart';

class OfficerOrgAuthScreen extends StatefulWidget {
  const OfficerOrgAuthScreen({Key? key}) : super(key: key);

  @override
  State<OfficerOrgAuthScreen> createState() => _OfficerOrgAuthScreenState();
}

class _OfficerOrgAuthScreenState extends State<OfficerOrgAuthScreen> {
  String? _selectedOrgId;
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _authenticating = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Organization? get _selectedOrg {
    if (_selectedOrgId == null) return null;
    try {
      return AppState.instance.organizations.firstWhere((o) => o.id == _selectedOrgId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _attemptAuth() async {
    final org = _selectedOrg;
    if (org == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an organization.')),
      );
      return;
    }
    final pass = _passwordCtrl.text;
    if (pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the officer password.')),
      );
      return;
    }

    setState(() => _authenticating = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    if (pass != org.officerPassword) {
      setState(() => _authenticating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password.')),
      );
      return;
    }

    AppState.instance.setOfficerOrgContext(org.id);
    setState(() => _authenticating = false);

    // Route back through role router so it can render the correct destination
    Navigator.pushReplacementNamed(context, '/role');
  }

  @override
  Widget build(BuildContext context) {
    final orgs = AppState.instance.organizations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Officer Authorization'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'Select Organization',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF424242),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOrgId,
                    items: [
                      for (final o in orgs)
                        DropdownMenuItem(
                          value: o.id,
                          child: Text(o.name),
                        ),
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF8FD4CC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setState(() => _selectedOrgId = v),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Officer Password',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF424242),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF8FD4CC),
                      hintText: 'Enter password',
                      hintStyle: const TextStyle(color: Colors.black87, fontSize: 13.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _authenticating ? null : _attemptAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF79CFC4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _authenticating
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Enter Dashboard',
                              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tip: Admin can set per-organization officer passwords in Organization settings.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF616161)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
