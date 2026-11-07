import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _keys = [
    'store_name',
    'address',
    'phone',
    'nif',
    'nis',
    'rc',
    'ai',
    'stamp_rate',
  ];
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _c = {
      for (final k in _keys)
        k: TextEditingController(
            text: st.getS(k, k == 'stamp_rate' ? '1' : '')),
    };
  }

  Future<void> _save() async {
    final st = context.read<AppState>();
    for (final k in _keys) {
      await st.setS(k, _c[k]!.text.trim());
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.t('saved'))));
    }
  }

  Widget _f(String key, String label,
          {TextInputType type = TextInputType.text}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _c[key],
          keyboardType: type,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(context.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.t('language'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ar', label: Text('العربية')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {st.lang},
            onSelectionChanged: (s) => st.setLang(s.first),
          ),
          const SizedBox(height: 20),
          Text(context.t('store_info'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _f('store_name', context.t('store_name')),
          _f('address', context.t('address')),
          _f('phone', context.t('phone'), type: TextInputType.phone),
          _f('nif', context.t('nif')),
          _f('nis', context.t('nis')),
          _f('rc', context.t('rc')),
          _f('ai', context.t('ai')),
          const Divider(),
          SwitchListTile(
            title: Text(context.t('thermal')),
            value: st.thermal,
            onChanged: (v) => st.setBool('thermal', v),
          ),
          SwitchListTile(
            title: Text(context.t('stamp_on')),
            value: st.stampOn,
            onChanged: (v) => st.setBool('stamp_on', v),
          ),
          if (st.stampOn)
            _f('stamp_rate', context.t('stamp_rate'),
                type: const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(context.t('save')),
          ),
        ],
      ),
    );
  }
}
