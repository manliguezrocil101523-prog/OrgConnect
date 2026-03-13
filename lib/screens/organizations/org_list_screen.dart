import 'package:flutter/material.dart';

import 'org_profile_screen.dart';

class OrgListScreen extends StatelessWidget {
  const OrgListScreen({super.key});

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
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/home'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF79CFC4),
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
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio:
                          1.2, // Adjusted aspect ratio for full logo visibility
                    ),
                    itemCount: 22,
                    itemBuilder: (context, index) {
                      final orgNumber = index + 1;
                      final orgName = "Org $orgNumber";
                      final imagePaths = [
                        "assets/primerabida.jpg",
                        "assets/eltiatro.jpg",
                        "assets/cronica.jpg",
                        "assets/bccmusicality.jpg",
                        "assets/drumandlyre.jpg",
                        "assets/pageturnersbookclub.jpg",
                        "assets/genderunited.jpg",
                        "assets/collegeelegante.jpg",
                        "assets/scap.jpg",
                        "assets/bccnigthngale.jpg",
                        "assets/speakiconics.jpg",
                        "assets/culturadefelipino.jpg",
                        "assets/inkwell.jpg",
                        "assets/christiancampusministry.jpg",
                        "assets/bccaces.jpg",
                        "assets/craftycreatorsclub.jpg",
                        "assets/ssg.jpg",
                        "assets/kasangasquad.jpg",
                        "assets/codehex.jpg",
                        "assets/motoclub.jpg",
                        "assets/bccdc.jpg",
                        "assets/peerfacilatatorscircles.jpg",
                      ];
                      final imagePath = imagePaths[index];
                      return buildOrgCard(context, orgName, imagePath, index);
                    },
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
  Widget buildOrgCard(
      BuildContext context, String name, String imagePath, int index) {
    final orgId = (index + 1).toString().padLeft(3, '0');

    return GestureDetector(
      onTap: () {
        // Navigate to the organization profile screen
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
                    fit: BoxFit.contain,
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
}
