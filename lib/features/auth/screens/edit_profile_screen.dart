import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/rail_data_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_views.dart';
import '../../../data/models/station.dart';
import '../../../data/models/user_profile.dart';
import '../../routing/screens/station_picker_screen.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _mobile;
  late PassengerType _passengerType;
  late String _homeStationId;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _name = TextEditingController(text: profile.fullName);
    _mobile = TextEditingController(text: profile.mobile);
    _passengerType = profile.passengerType;
    _homeStationId = profile.homeStationId;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _pickHomeStation() async {
    final station = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => const StationPickerScreen(title: 'Home station'),
      ),
    );
    if (station != null) setState(() => _homeStationId = station.id);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    await auth.updateProfile(
      auth.profile.copyWith(
        fullName: _name.text.trim(),
        mobile: _mobile.text.trim(),
        passengerType: _passengerType,
        homeStationId: _homeStationId,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final network = context.read<RailDataProvider>().network;
    final homeStation =
        _homeStationId.isEmpty ? null : network.station(_homeStationId);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: Validators.fullName,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  prefixIcon: Icon(Icons.phone_iphone_rounded),
                  hintText: '0123456789',
                ),
                validator: (value) => Validators.mobile(value),
              ),
              const SizedBox(height: 22),
              Text(
                'Passenger type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in PassengerType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _passengerType == type,
                      onSelected: (_) => setState(() => _passengerType = type),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              InfoBanner(
                icon: Icons.card_membership_rounded,
                message: _passengerType.concessionNote,
                colour: AppColors.accent,
              ),
              const SizedBox(height: 22),
              ListTile(
                onTap: _pickHomeStation,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Icons.home_outlined),
                title: const Text('Home station'),
                subtitle: Text(homeStation?.name ?? 'Not selected'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
