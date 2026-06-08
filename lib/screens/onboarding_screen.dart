import 'package:flutter/material.dart';
import '../theme/ramble_theme.dart';
import '../services/settings_service.dart';
import '../widgets/ramble_button.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleLetsGo() {
    SettingsService.instance.userName = _controller.text.trim();
    SettingsService.instance.onboarded = true;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;

    return Scaffold(
      backgroundColor: scheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: RambleSpace.s7),
                // Miko + wordmark hero (the real logo art)
                Image.asset(
                  'assets/miko_logo.png',
                  width: 280,
                  filterQuality: FilterQuality.none,
                ),
                SizedBox(height: RambleSpace.s3),
                // Tagline
                Text(
                  "we'll make sense of it",
                  style: RambleType.label(scheme.inkSoft),
                ),
                SizedBox(height: RambleSpace.s6),
                // Miko message card
                Container(
                  margin: EdgeInsets.symmetric(horizontal: RambleSpace.s4),
                  padding: EdgeInsets.all(RambleSpace.s4),
                  decoration: BoxDecoration(
                    color: RambleColors.deepNavy,
                    borderRadius: BorderRadius.circular(RambleGeo.cardRadius),
                    border: Border.all(
                      color: RambleColors.mikoPurple,
                      width: RambleGeo.borderWidth,
                    ),
                  ),
                  child: Text(
                    "i'll make sense of what you say. let's start.",
                    style: RambleType.mikoMessage(Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: RambleSpace.s6),
                // Name input section
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: RambleSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WHAT SHOULD I CALL YOU?',
                        style: RambleType.label(scheme.inkSoft),
                      ),
                      SizedBox(height: RambleSpace.s3),
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'your name (optional)',
                          hintStyle: RambleType.body(scheme.inkSoft),
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                            borderSide: BorderSide(
                              color: scheme.border,
                              width: RambleGeo.borderWidth,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                            borderSide: BorderSide(
                              color: scheme.border,
                              width: RambleGeo.borderWidth,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                            borderSide: BorderSide(
                              color: RambleColors.mikoPurple,
                              width: RambleGeo.borderWidth,
                            ),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: RambleSpace.s3,
                            vertical: RambleSpace.s3,
                          ),
                        ),
                        style: RambleType.body(scheme.ink),
                        cursorColor: RambleColors.mikoPurple,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: RambleSpace.s6),
                // LET'S GO button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: RambleSpace.s4),
                  child: RambleButton(
                    label: "LET'S GO",
                    expand: true,
                    icon: Icons.arrow_forward,
                    onTap: _handleLetsGo,
                  ),
                ),
                SizedBox(height: RambleSpace.s6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
