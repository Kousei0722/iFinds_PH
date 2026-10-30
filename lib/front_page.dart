import 'package:flutter/material.dart';

import 'store_page.dart';

class FrontPage extends StatelessWidget {
  const FrontPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF12ABAD),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 650;

                return Padding(
                  padding: const EdgeInsets.all(15),
                  child: isWide
                      ? Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: _buildOrangePanel(context),
                            ),
                            const SizedBox(width: 10),
                            Expanded(flex: 5, child: _buildPhoneImage()),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildOrangePanel(context),
                              const SizedBox(height: 20),
                              _buildPhoneImage(),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrangePanel(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 420,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xFFFF701B),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Welcome to iFinds PH',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFFF701B), fontSize: 11),
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white),
          const SizedBox(height: 35),

          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'ONLINE\nSHOPPING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: -1.5,
              ),
            ),
          ),

          const Spacer(),

          const Divider(color: Colors.white),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const StorePage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF701B),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Buying Everything Anytime and Anywhere',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneImage() {
    return Center(
      child: Image.asset(
        'assets/front_phone.png',
        width: double.infinity,
        height: 500,
        fit: BoxFit.contain,
      ),
    );
  }
}
