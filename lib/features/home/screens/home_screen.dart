import 'package:flutter/material.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/widgets/app_bar.dart';
import 'package:projeto_final/features/home/widgets/agendamento_card.dart';
import 'package:projeto_final/features/home/widgets/calendario.dart';
import 'package:projeto_final/services/agendamento_service.dart';

/// Aba "Início". O rodapé e o botão de criar agendamento ficam no
/// [MainShellScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AgendamentoDetalhado> _consultas = const [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    // Recarrega quando um agendamento é criado, cancelado ou remarcado.
    AgendamentoService.alteracoes.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    AgendamentoService.alteracoes.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final consultas = await AgendamentoService.instance.listarMeus();
      if (!mounted) return;
      setState(() {
        _consultas = consultas;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    }
  }

  /// Próximo agendamento ativo, em ordem de data.
  AgendamentoDetalhado? get _proxima {
    final agora = DateTime.now();
    for (final consulta in _consultas) {
      if (consulta.ativo && consulta.data.isAfter(agora)) return consulta;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (screenWidth * 0.045).clamp(16.0, 32.0);

    return Scaffold(
      appBar: const AppBarWidget(),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: SingleChildScrollView(
          // Permite "puxar para atualizar" mesmo com pouco conteúdo.
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  // Espaço para o botão "+" não cobrir o fim da página.
                  48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    const Text(
                      'Meus agendamentos',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Próxima consulta:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    _buildProxima(context),
                    Calendario(agendamentos: _consultas),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProxima(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_carregando && _consultas.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.error.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _carregar,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    final proxima = _proxima;
    if (proxima != null) return AgendamentoCard(consulta: proxima);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Você não tem consultas agendadas.\nToque no + para agendar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.primary, fontSize: 15),
      ),
    );
  }
}