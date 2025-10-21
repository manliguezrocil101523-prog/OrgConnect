import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import 'officer_rule_screen.dart';

class OfficerAuthorizationScreen extends StatefulWidget {
  const OfficerAuthorizationScreen({Key? key}) : super(key: key);

  @override
  State<OfficerAuthorizationScreen> createState() =>
      _OfficerAuthorizationScreenState();
}

class _OfficerAuthorizationScreenState
    extends State<OfficerAuthorizationScreen> {
  static const Color mintBg = Color(0xFFEAF6F0);
  static const Color tealHeader = Color(0xFF79CFC4);

  Organization? _selectedOrganization;
  final TextEditingController _passwordController = TextEditingController();
  bool _isAuthenticating = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mintBg,
      appBar: AppBar(
        backgroundColor: tealHeader,
        elevation: 0,
        title: const Text(
          'Officer Authorization',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedOrganization != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        _selectedOrganization!.logoAsset,
                        width: 120,
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.badge_outlined,
                    size: 80,
                    color: tealHeader,
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Select Your Organization',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your organization and enter its password',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Organization Selection
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Select Organization',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ...AppState.instance.organizations.map(
                        (org) => _buildOrganizationOption(org),
                      ),
                    ],
                  ),
                ),

                if (_selectedOrganization != null) ...[
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Organization Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      errorText:
                          _errorMessage.isNotEmpty ? _errorMessage : null,
                    ),
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAuthenticating ? null : _authenticate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealHeader,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isAuthenticating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'ACCESS DASHBOARD',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrganizationOption(Organization org) {
    final isSelected = _selectedOrganization?.id == org.id;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrganization = org;
          _errorMessage = '';
          _passwordController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? tealHeader.withOpacity(0.1) : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? tealHeader : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        org.logoAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.business,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    org.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? tealHeader : Colors.black87,
                    ),
                  ),
                  Text(
                    'ID: ${org.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _authenticate() async {
    if (_selectedOrganization == null) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (_passwordController.text == _selectedOrganization!.id) {
      // Set the current officer organization
      AppState.instance.setCurrentOfficerOrgId(_selectedOrganization!.id);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BaseOfficerDashboard(
              orgId: _selectedOrganization!.id,
              orgName: _selectedOrganization!.name,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _isAuthenticating = false;
        _errorMessage =
            'Invalid password. Password should be organization ID (${_selectedOrganization!.id})';
        _passwordController.clear();
      });
    }
  }
}
