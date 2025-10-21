import 'package:flutter/material.dart';

import 'org_profile_screen.dart';

class OrgListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFEAF6F0),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Header Image
                Image.asset(
                  "assets/newheader.jpg",
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 100,
                ),

                const SizedBox(height: 16),

                // Centered Back button (teal style per theme)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF79CFC4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      // Row 1
                      SizedBox(
                        height: 160, // ✅ FIXED height so Expanded works
                        child: Row(
                          children: [
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 1",
                                        "assets/primerabida.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 2",
                                        "assets/eltiatro.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 3",
                                        "assets/cronica.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 4",
                                        "assets/bccmusicality.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 5",
                                        "assets/drumandlyre.jpg"))),
                          ],
                        ),
                      ),

                      // Row 2
                      SizedBox(
                        height: 160,
                        child: Row(
                          children: [
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 6",
                                        "assets/pageturnersbookclub.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 7",
                                        "assets/genderunited.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 8",
                                        "assets/collegeelegante.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(
                                        context, "Org 9", "assets/scap.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 10",
                                        "assets/bccnigthngale.jpg"))),
                          ],
                        ),
                      ),

                      // Row 3
                      SizedBox(
                        height: 160,
                        child: Row(
                          children: [
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 11",
                                        "assets/speakiconics.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 12",
                                        "assets/culturadefelipino.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 13",
                                        "assets/inkwell.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 14",
                                        "assets/christiancampusministry.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 15",
                                        "assets/bccaces.jpg"))),
                          ],
                        ),
                      ),

                      // Row 4
                      SizedBox(
                        height: 160,
                        child: Row(
                          children: [
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 16",
                                        "assets/craftycreatorsclub.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(
                                        context, "Org 17", "assets/ssg.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 18",
                                        "assets/kasangasquad.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 19",
                                        "assets/codehex.jpg"))),
                            Expanded(
                                child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: buildOrgCard(context, "Org 20",
                                        "assets/motoclub.jpg"))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Last Row (2 cards centered)
                      SizedBox(
                        height: 160,
                        child: Row(
                          children: [
                            const Spacer(flex: 2),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: buildOrgCard(
                                    context, "Org 21", "assets/bccdc.jpg"),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: buildOrgCard(context, "Org 22",
                                    "assets/peerfacilatatorscircles.jpg"),
                              ),
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "Choose and Click to Discover your Passion!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Clickable card widget
  Widget buildOrgCard(BuildContext context, String name, String imagePath) {
    final orgId = _getOrgIdFromName(name);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrgDetailScreen(orgId: orgId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.green.shade900,
            width: 3,
          ),
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Organization Image
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    height: double.infinity,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOrgIdFromName(String name) {
    final orgNumber = int.parse(name.replaceAll('Org ', ''));
    return orgNumber.toString();
  }
}
