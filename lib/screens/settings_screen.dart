import 'package:flutter/material.dart';
import '../theme/ramble_theme.dart';
import '../services/settings_service.dart';
import '../widgets/ramble_button.dart';
import '../widgets/ramble_card.dart';
import '../widgets/miko/miko_character.dart';
import '../widgets/miko/miko_painter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _userNameController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _userNameController =
        TextEditingController(text: SettingsService.instance.userName);
    _apiKeyController =
        TextEditingController(text: SettingsService.instance.apiKey);
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveUserName() {
    SettingsService.instance.userName = _userNameController.text;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'name saved',
            style: RambleType.body(context.ramble.ink),
          ),
          backgroundColor: context.ramble.surface,
        ),
      );
    }
  }

  void _saveApiKey() {
    SettingsService.instance.apiKey = _apiKeyController.text;
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'saved',
            style: RambleType.body(context.ramble.ink),
          ),
          backgroundColor: context.ramble.surface,
        ),
      );
    }
  }

  void _resetOnboarding() {
    SettingsService.instance.onboarded = false;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'onboarding will show on next launch',
            style: RambleType.body(context.ramble.ink),
          ),
          backgroundColor: context.ramble.surface,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ramble;

    return Scaffold(
      backgroundColor: scheme.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(RambleSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar with back button and title
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: scheme.ink),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: RambleSpace.s3),
                Expanded(
                  child: Text(
                    'SETTINGS',
                    style: RambleType.screenTitle(scheme.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: RambleSpace.s5),

            // Centered Miko character
            Center(
              child: MikoCharacter(
                size: 80,
                state: MikoState.idle,
              ),
            ),
            const SizedBox(height: RambleSpace.s5),

            // Section 1: Your Name
            Text(
              'YOUR NAME',
              style: RambleType.label(scheme.inkSoft),
            ),
            const SizedBox(height: RambleSpace.s2),
            RambleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _userNameController,
                    style: RambleType.body(scheme.ink),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: BorderSide(
                          color: scheme.border,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: BorderSide(
                          color: scheme.border,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: BorderSide(
                          color: RambleColors.mikoPurple,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: scheme.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: RambleSpace.s3,
                        vertical: RambleSpace.s2,
                      ),
                      hintText: 'your name here',
                      hintStyle: RambleType.body(scheme.inkSoft),
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s3),
                  SizedBox(
                    width: double.infinity,
                    child: RambleButton(
                      label: 'SAVE',
                      kind: RambleButtonKind.primary,
                      onTap: _saveUserName,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RambleSpace.s5),

            // Section 2: Miko
            Text(
              'MIKO',
              style: RambleType.label(scheme.inkSoft),
            ),
            const SizedBox(height: RambleSpace.s2),
            RambleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Miko talks back',
                          style: RambleType.body(scheme.ink),
                        ),
                      ),
                      Switch(
                        value: SettingsService.instance.mikoEnabled,
                        activeColor: RambleColors.mikoPurple,
                        onChanged: (v) {
                          setState(
                            () => SettingsService.instance.mikoEnabled = v,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: RambleSpace.s2),
                  Text(
                    'miko notices patterns and responds to your notes. turn off for silence.',
                    style: RambleType.caption(scheme.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RambleSpace.s5),

            // Section 3: Miko's brain (LLM key)
            Text(
              "MIKO'S BRAIN",
              style: RambleType.label(scheme.inkSoft),
            ),
            const SizedBox(height: RambleSpace.s2),
            RambleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ramble structures your thinking offline for free. add a Claude API key to wake Miko up — real summaries, the arc of your thought, contradictions across your notes, and live stats on demand. your key stays on this device.',
                    style: RambleType.caption(scheme.inkSoft),
                  ),
                  const SizedBox(height: RambleSpace.s3),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    style: RambleType.body(scheme.ink),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: BorderSide(
                          color: scheme.border,
                          width: 2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: BorderSide(
                          color: scheme.border,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RambleGeo.inputRadius),
                        borderSide: BorderSide(
                          color: RambleColors.mikoPurple,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: scheme.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: RambleSpace.s3,
                        vertical: RambleSpace.s2,
                      ),
                      hintText: 'paste API key (optional)',
                      hintStyle: RambleType.body(scheme.inkSoft),
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s3),
                  SizedBox(
                    width: double.infinity,
                    child: RambleButton(
                      label: 'SAVE',
                      kind: RambleButtonKind.primary,
                      onTap: _saveApiKey,
                      expand: true,
                    ),
                  ),
                  const SizedBox(height: RambleSpace.s3),
                  Center(
                    child: Text(
                      SettingsService.instance.hasApiKey
                          ? '✓ Miko is awake'
                          : 'offline mode',
                      style: RambleType.caption(
                        SettingsService.instance.hasApiKey
                            ? RambleColors.bit8Green
                            : scheme.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RambleSpace.s5),

            // Section 4: About
            Text(
              'ABOUT',
              style: RambleType.label(scheme.inkSoft),
            ),
            const SizedBox(height: RambleSpace.s2),
            RambleCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ramble v1.0.0',
                    style: RambleType.body(scheme.ink),
                  ),
                  const SizedBox(height: RambleSpace.s2),
                  Text(
                    'we\'ll make sense of it.',
                    style: RambleType.caption(scheme.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RambleSpace.s5),

            // Reset onboarding button
            SizedBox(
              width: double.infinity,
              child: RambleButton(
                label: 'RESET ONBOARDING',
                kind: RambleButtonKind.danger,
                icon: Icons.refresh,
                onTap: _resetOnboarding,
                expand: true,
              ),
            ),
            const SizedBox(height: RambleSpace.s5),
          ],
        ),
      ),
    );
  }
}
