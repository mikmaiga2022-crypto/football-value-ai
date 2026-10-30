import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/auth/session.dart';
import '../../widgets/info_banner.dart';
import 'auth_scaffold.dart';
import 'validators.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _accepted = false;
  bool _termsError = false;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!_accepted) setState(() => _termsError = true);
    if (!formValid || !_accepted) return;

    await ref.read(sessionProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          displayName: _displayName.text.trim().isEmpty ? null : _displayName.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final surfaces = context.surfaces;

    return AuthScaffold(
      title: 'Créer un compte',
      subtitle: 'Bêta privée. Aucun pari réel n’est placé par l’application.',
      footer: Text(
        'Les probabilités sont des estimations. Aucun gain n’est garanti. '
        'L’application peut recommander de ne pas parier.',
        style: Tokens.caption.copyWith(color: surfaces.muted),
      ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('register-name'),
                  controller: _displayName,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nom affiché (facultatif)',
                  ),
                  validator: validateDisplayName,
                ),
                const SizedBox(height: Tokens.space3),
                TextFormField(
                  key: const ValueKey('register-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Adresse e-mail',
                    hintText: 'vous@exemple.com',
                  ),
                  validator: validateEmail,
                ),
                const SizedBox(height: Tokens.space3),
                TextFormField(
                  key: const ValueKey('register-password'),
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    helperText: '10 caractères minimum.',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Afficher' : 'Masquer',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: validateNewPassword,
                ),
                const SizedBox(height: Tokens.space3),
                TextFormField(
                  key: const ValueKey('register-confirm'),
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirmez le mot de passe.';
                    }
                    if (value != _password.text) {
                      return 'Les mots de passe ne correspondent pas.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        CheckboxListTile(
          key: const ValueKey('register-terms'),
          value: _accepted,
          onChanged: (value) => setState(() {
            _accepted = value ?? false;
            if (_accepted) _termsError = false;
          }),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            'J’ai 18 ans ou plus et j’accepte l’avertissement légal : '
            'aucun gain n’est garanti, les pertes sont possibles.',
            style: Tokens.caption.copyWith(color: surfaces.muted),
          ),
        ),
        if (_termsError)
          Padding(
            padding: const EdgeInsets.only(left: Tokens.space3, bottom: Tokens.space2),
            child: Text(
              'Vous devez accepter l’avertissement pour continuer.',
              style: Tokens.caption.copyWith(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (session.error != null && !session.busy) ...[
          const SizedBox(height: Tokens.space2),
          InfoBanner(
            tone: BannerTone.danger,
            title: 'Inscription impossible',
            message: session.error!,
          ),
        ],
        const SizedBox(height: Tokens.space4),
        FilledButton(
          key: const ValueKey('register-submit'),
          onPressed: session.busy ? null : _submit,
          child: session.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer mon compte'),
        ),
        const SizedBox(height: Tokens.space2),
        TextButton(
          onPressed: session.busy ? null : () => context.go('/login'),
          child: const Text('Déjà un compte ? Se connecter'),
        ),
      ],
    );
  }
}
