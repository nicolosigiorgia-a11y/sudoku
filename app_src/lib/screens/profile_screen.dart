import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/cloud_sync.dart';
import '../ui/avatar.dart';
import '../ui/duo_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _sync = CloudSync.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  ValueListenable<String>? _email;
  bool _loading = false;
  bool _magicLink = false;
  bool _editingName = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _email = _sync.userEmail;
    _nameController.text = _sync.playerName.value;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action, {String? success}) async {
    setState(() {
      _loading = true;
      _message = '';
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = result ?? success ?? 'Operazione completata.';
    });
  }

  Future<void> _saveName() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    final error = await _sync.updateDisplayName(_nameController.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = error ?? '';
      // Dopo il salvo la card diventa un saluto: il campo ricompare
      // solo quando il giocatore sceglie di modificarlo.
      if (error == null) _editingName = false;
    });
  }

  void _startEditingName() {
    _nameController.text = _sync.playerName.value;
    setState(() {
      _message = '';
      _editingName = true;
    });
  }

  Future<void> _showChangePasswordDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Cambia password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imposta una password di almeno 6 caratteri. Ti servirà per accedere '
              'con email e password sugli altri dispositivi.',
              style: TextStyle(fontSize: 13, color: DuoColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nuova password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    final password = controller.text;
    controller.dispose();
    if (confirmed != true || !mounted || password.isEmpty) return;
    await _run(() => _sync.setPassword(password));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DuoCard(
                color: DuoColors.blueLight,
                child: Column(
                  children: [
                    const CatParade(size: 58),
                    const SizedBox(height: 12),
                    const Text(
                      'Il tuo album dei record',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Accedi per portare stelle, tempi e impostazioni su un altro telefono.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: DuoColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _sync.playerName,
                builder: (context, name, _) {
                  final editing = _editingName || name.isEmpty;
                  return DuoCard(
                    color: editing ? DuoColors.yellowLight : DuoColors.greenLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CatMascot(
                              size: 46,
                              mood: editing ? AvatarMood.thinking : AvatarMood.happy,
                              scarfColor: editing ? DuoColors.yellow : DuoColors.green,
                              showShadow: false,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                editing ? 'Come ti chiami?' : 'Ciao, $name!',
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        if (editing) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.done,
                            maxLength: 24,
                            onSubmitted: (_) => _saveName(),
                            decoration: const InputDecoration(
                              labelText: 'Nome giocatore',
                              hintText: 'Es. Sofia',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DuoButton(
                            label: 'Salva nome',
                            icon: Icons.save_outlined,
                            style: DuoButtonStyle.secondary,
                            onPressed: _loading ? null : _saveName,
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Il tuo gatto ti riconoscerà sempre. Puoi cambiare nome quando vuoi.',
                            style: TextStyle(fontSize: 12, color: DuoColors.muted),
                          ),
                          const SizedBox(height: 12),
                          DuoButton(
                            label: 'Modifica nome',
                            icon: Icons.edit_outlined,
                            style: DuoButtonStyle.secondary,
                            onPressed: _loading ? null : _startEditingName,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _email ?? _sync.userEmail,
                builder: (context, email, _) => email.isEmpty ? _loginCard() : _accountCard(email),
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                DuoCard(
                  color: DuoColors.yellowLight,
                  padding: const EdgeInsets.all(14),
                  child: Text(_message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _loginCard() {
    return DuoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatMascot(size: 52, mood: AvatarMood.happy, scarfColor: DuoColors.green),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Accedi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Password'), icon: Icon(Icons.password_outlined)),
              ButtonSegment(value: true, label: Text('Magic link'), icon: Icon(Icons.email_outlined)),
            ],
            selected: {_magicLink},
            onSelectionChanged: (value) => setState(() => _magicLink = value.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 10),
          if (!_magicLink)
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            ),
          if (_magicLink) ...[
            const SizedBox(height: 10),
            const Text(
              'Riceverai una email: clicca il link e l\'app si aprirà da sola.',
              style: TextStyle(fontSize: 12, color: DuoColors.muted),
            ),
          ],
          const SizedBox(height: 18),
          DuoButton(
            label: _magicLink ? 'Invia link' : 'Accedi',
            icon: _magicLink ? Icons.mail_outline : Icons.login,
            onPressed: _loading
                ? null
                : () => _magicLink
                    ? _run(() => _sync.sendMagicLink(_emailController.text), success: 'Link inviato: controlla la email.')
                    : _run(
                        () => _sync.signInWithPassword(_emailController.text, _passwordController.text),
                        success: 'Accesso effettuato.',
                      ),
          ),
          if (!_magicLink) ...[
            const SizedBox(height: 10),
            DuoButton(
              label: 'Crea account con password',
              icon: Icons.person_add_outlined,
              style: DuoButtonStyle.secondary,
              onPressed: _loading
                  ? null
                  : () => _run(
                        () => _sync.signUp(_emailController.text, _passwordController.text),
                        success: 'Account creato.',
                      ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _accountCard(String email) {
    return DuoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CatMascot(size: 56, mood: AvatarMood.happy, scarfColor: DuoColors.yellow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: _sync.playerName,
                      builder: (context, name, _) => Text(
                        name.isEmpty ? 'Accesso effettuato' : 'Ciao, $name!',
                        style: const TextStyle(fontSize: 12, color: DuoColors.muted),
                      ),
                    ),
                    Text(email, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 6),
                    const DuoBadge(
                      text: 'Account attivo',
                      icon: Icons.cloud_done_outlined,
                      color: DuoColors.greenLight,
                      textColor: DuoColors.greenDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DuoButton(
            label: 'Sincronizza ora',
            icon: Icons.cloud_sync_outlined,
            onPressed: _loading ? null : () => _run(() => _sync.sync(preferRemoteSettings: true)),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _loading ? null : _showChangePasswordDialog,
            icon: const Icon(Icons.key_outlined, size: 18),
            label: const Text('Cambia password'),
          ),
          const SizedBox(height: 10),
          DuoButton(
            label: 'Esci',
            icon: Icons.logout,
            style: DuoButtonStyle.ghost,
            onPressed: _loading ? null : () => _run(() => _sync.signOut(), success: 'Disconnesso.'),
          ),
        ],
      ),
    );
  }
}
