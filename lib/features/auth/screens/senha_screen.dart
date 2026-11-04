import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:projeto_final/app/routes.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/utils/validadores.dart';
import 'package:projeto_final/features/auth/widgets/campo_auth.dart';
import 'package:projeto_final/services/auth_service.dart';

class SenhaScreen extends StatefulWidget {
  const SenhaScreen({super.key});

  @override
  State<SenhaScreen> createState() => _SenhaScreenState();
}

class _SenhaScreenState extends State<SenhaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  bool _codigoEnviado = false;
  bool _concluido = false;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _voltarParaLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  Future<void> _solicitarCodigo() async {
    if (_carregando) return;
    FocusScope.of(context).unfocus();
    if (!_codigoEnviado && !(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      await AuthService.instance.solicitarCodigoRecuperacao(
        email: _emailController.text,
      );
      if (!mounted) return;
      setState(() {
        _codigoEnviado = true;
        _carregando = false;
        _autovalidate = AutovalidateMode.disabled;
      });
    } on ApiException catch (e) {
      _mostrarErro(e.mensagem);
    } catch (_) {
      _mostrarErro('Não foi possível solicitar o código. Tente novamente.');
    }
  }

  Future<void> _redefinirSenha() async {
    if (_carregando) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      await AuthService.instance.redefinirSenha(
        email: _emailController.text,
        codigo: _codigoController.text,
        novaSenha: _senhaController.text,
      );
      if (!mounted) return;
      setState(() {
        _concluido = true;
        _carregando = false;
      });
    } on ApiException catch (e) {
      _mostrarErro(e.mensagem);
    } catch (_) {
      _mostrarErro('Não foi possível redefinir a senha. Tente novamente.');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    setState(() {
      _erro = mensagem;
      _carregando = false;
    });
  }

  void _alterarEmail() {
    setState(() {
      _codigoEnviado = false;
      _erro = null;
      _codigoController.clear();
      _senhaController.clear();
      _confirmarSenhaController.clear();
      _autovalidate = AutovalidateMode.disabled;
    });
  }

  String? _validarSenha(String? valor) {
    final senha = valor ?? '';
    if (senha.length < 8 ||
        !RegExp(r'[A-Za-z]').hasMatch(senha) ||
        !RegExp(r'\d').hasMatch(senha)) {
      return 'Use ao menos 8 caracteres, com letras e números';
    }
    return null;
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
                      _concluido
                          ? Icons.check_circle_outline
                          : Icons.lock_reset,
                      size: 56,
                      color: scheme.secondary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _concluido ? 'Senha redefinida' : 'Esqueceu sua senha?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _concluido
                          ? 'Sua senha foi alterada. Agora você já pode entrar na sua conta.'
                          : _codigoEnviado
                          ? 'Se o e-mail estiver cadastrado, enviamos um código de 6 dígitos. Confira sua caixa de entrada.'
                          : 'Informe o e-mail cadastrado para receber um código de recuperação.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.primary.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (!_concluido) ...[
                      const SizedBox(height: 32),
                      CampoAuth(
                        rotulo: 'E-mail',
                        controller: _emailController,
                        hint: 'nome@exemplo.com',
                        icone: Icons.mail_outline,
                        enabled: !_codigoEnviado && !_carregando,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: _codigoEnviado
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: _codigoEnviado
                            ? null
                            : (_) => _solicitarCodigo(),
                        validator: (valor) {
                          final email = valor?.trim() ?? '';
                          if (email.isEmpty) return 'Informe seu e-mail';
                          if (!emailValido(email)) return 'E-mail inválido';
                          return null;
                        },
                      ),
                    ],
                    if (_codigoEnviado && !_concluido) ...[
                      const SizedBox(height: 20),
                      CampoAuth(
                        rotulo: 'Código de recuperação',
                        controller: _codigoController,
                        hint: 'Digite o código de 6 dígitos',
                        icone: Icons.pin_outlined,
                        enabled: !_carregando,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (valor) => (valor?.trim().length ?? 0) != 6
                            ? 'Informe o código de 6 dígitos'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      CampoAuth(
                        rotulo: 'Nova senha',
                        controller: _senhaController,
                        hint: 'Mínimo de 8 caracteres',
                        icone: Icons.lock_outline,
                        enabled: !_carregando,
                        senha: true,
                        textInputAction: TextInputAction.next,
                        validator: _validarSenha,
                      ),
                      const SizedBox(height: 20),
                      CampoAuth(
                        rotulo: 'Confirmar nova senha',
                        controller: _confirmarSenhaController,
                        hint: 'Digite a nova senha novamente',
                        icone: Icons.lock_outline,
                        enabled: !_carregando,
                        senha: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _redefinirSenha(),
                        validator: (valor) => valor != _senhaController.text
                            ? 'As senhas não conferem'
                            : null,
                      ),
                    ],
                    if (_erro != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _erro!,
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
                        onPressed: _carregando
                            ? null
                            : _concluido
                            ? _voltarParaLogin
                            : _codigoEnviado
                            ? _redefinirSenha
                            : _solicitarCodigo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.secondary,
                          foregroundColor: scheme.onSecondary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _carregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _concluido
                                    ? 'Ir para o login'
                                    : _codigoEnviado
                                    ? 'Redefinir senha'
                                    : 'Enviar código',
                                style: const TextStyle(fontSize: 16),
                              ),
                      ),
                    ),
                    if (_codigoEnviado && !_concluido) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _carregando ? null : _solicitarCodigo,
                        child: Text(
                          'Enviar código novamente',
                          style: TextStyle(color: scheme.secondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _carregando ? null : _alterarEmail,
                        child: Text(
                          'Alterar e-mail',
                          style: TextStyle(color: scheme.secondary),
                        ),
                      ),
                    ],
                    if (!_concluido) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 46,
                        child: TextButton(
                          onPressed: _carregando ? null : _voltarParaLogin,
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
