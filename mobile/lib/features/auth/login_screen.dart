import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../app/theme/tokens.dart';
import '../../core/auth/session.dart';
import '../../widgets/info_banner.dart';
import 'auth_scaffold.dart';
import 'validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(sessionProvider.notifier).login(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final surfaces = context.surfaces;

    return AuthScaffold(
      title: 'Connexion',
      subtitle: 'Des probabilités, pas des promesses.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '18+ · Les probabilités sont des estimations. Aucun gain n’est garanti, '
            'les pertes sont possibles.',
            style: Tokens.caption.copyWith(color: surfaces.muted),
          ),
          const SizedBox(height: Tokens.space2),
          Text(
            'Aucune clé fournisseur n’est présente dans l’application.',
            style: Tokens.caption.copyWith(color: surfaces.muted),
          ),
        ],
      ),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('login-email'),
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
                  key: const ValueKey('login-password'),
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Afficher' : 'Masquer',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: validateLoginPassword,
                ),
              ],
            ),
          ),
        ),
        if (session.error != null && !session.busy) ...[
          const SizedBox(height: Tokens.space3),
          InfoBanner(
            tone: BannerTone.danger,
            title: 'Connexion impossible',
            message: session.error!,
          ),
        ],
        const SizedBox(height: Tokens.space4),
        FilledButton(
          key: const ValueKey('login-submit'),
          onPressed: session.busy ? null : _submit,
          child: session.busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Se connecter'),
        ),
        const SizedBox(height: Tokens.space2),
        TextButton(
          onPressed: session.busy ? null : () => context.push('/register'),
          child: const Text('Pas encore de compte ? Créer un compte'),
        ),
      ],
    );
  }
}
