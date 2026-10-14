import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:projeto_final/app/routes.dart';
import 'package:projeto_final/core/utils/validadores.dart';
import 'package:projeto_final/features/auth/widgets/campo_auth.dart';

class SenhaScreen extends StatefulWidget {
  const SenhaScreen({super.key});

  @override
  State<SenhaScreen> createState() => _SenhaScreenState();
}

class _SenhaScreenState extends State<SenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _avisoRecuperacaoIndisponivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _voltarParaLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  void _solicitarRecuperacao() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() => _avisoRecuperacaoIndisponivel = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (screenWidth * 0.045).clamp(16.0, 32.0);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltarParaLogin();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: scheme.surface,
          centerTitle: true,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 100,
          title: SizedBox(
            height: 70,
            width: 200,
            child: Center(
              child: SvgPicture.asset(
                'assets/images/medlink_dark.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                24,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_reset,
                      size: 56,
                      color: scheme.secondary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Esqueceu sua senha?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Informe o e-mail cadastrado para recuperar o acesso à sua conta.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.primary.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    CampoAuth(
                      rotulo: 'E-mail',
                      controller: _emailController,
                      hint: 'nome@exemplo.com',
                      icone: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      onFieldSubmitted: (_) => _solicitarRecuperacao(),
                      validator: (valor) {
                        final email = valor?.trim() ?? '';
                        if (email.isEmpty) return 'Informe seu e-mail';
                        if (!emailValido(email)) return 'E-mail inválido';
                        return null;
                      },
                    ),
                    if (_avisoRecuperacaoIndisponivel) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'A recuperação de senha ainda não está disponível. '
                          'Entre em contato com a clínica para obter ajuda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onErrorContainer,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _solicitarRecuperacao,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.secondary,
                          foregroundColor: scheme.onSecondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Recuperar senha',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: TextButton(
                        onPressed: _voltarParaLogin,
                        child: Text(
                          'Voltar para o login',
                          style: TextStyle(
                            color: scheme.secondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
