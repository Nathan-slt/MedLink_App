import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:projeto_final/services/auth_service.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/widgets/app_bar.dart';
import 'package:projeto_final/features/home/widgets/agendamento_card.dart';
import 'package:projeto_final/features/home/widgets/calendario.dart';
import 'package:projeto_final/services/agendamento_service.dart';
import 'package:projeto_final/features/notificacoes/screens/notificacoes_screen.dart';
import 'package:projeto_final/services/notificacao_push_service.dart';

/// Aba "Início". O rodapé e o botão de criar agendamento ficam no
/// [MainShellScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AgendamentoDetalhado> _consultas = const [];
  final Set<int> _concluidasNaSessao = {};
  int _carregamentoAtual = 0;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    AgendamentoService.alteracoes.addListener(_carregar);
    AgendamentoService.conclusoes.addListener(_marcarConsultaAtualConcluida);
    _carregar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Firebase.apps.isNotEmpty) {
        PushNotificationService.instance.abrirNotificacaoInicialSeNecessario();
      }
    });
  }

  @override
  void dispose() {
    AgendamentoService.alteracoes.removeListener(_carregar);
    AgendamentoService.conclusoes.removeListener(_marcarConsultaAtualConcluida);
    super.dispose();
  }

  void _marcarConsultaAtualConcluida() {
    final agora = DateTime.now();
    final consultasDoDia = _consultasAtivas
        .where((consulta) => DateUtils.isSameDay(consulta.data, agora))
        .toList()
      ..sort(
        (a, b) => a.data
            .difference(agora)
            .inMicroseconds
            .abs()
            .compareTo(
              b.data.difference(agora).inMicroseconds.abs(),
            ),
      );
    final consulta = consultasDoDia.isNotEmpty
        ? consultasDoDia.first
        : _proxima;
    if (consulta == null ||
        _concluidasNaSessao.contains(consulta.agendamento.idAgendamento)) {
      return;
    }

    setState(() {
      _concluidasNaSessao.add(consulta.agendamento.idAgendamento);
    });
    AgendamentoService.marcarConcluidaNaSessao(
      consulta.agendamento.idAgendamento,
    );
  }

  Future<void> _carregar() async {
    final carregamento = ++_carregamentoAtual;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final consultas = await AgendamentoService.instance.listarMeus();
      if (!mounted || carregamento != _carregamentoAtual) return;
      setState(() {
        _consultas = consultas;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted || carregamento != _carregamentoAtual) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    }
  }

  List<AgendamentoDetalhado> get _consultasAtivas => _consultas
      .where(
        (consulta) =>
            consulta.ativo &&
            !_concluidasNaSessao.contains(consulta.agendamento.idAgendamento) &&
            !AgendamentoService.foiConcluidaNaSessao(
              consulta.agendamento.idAgendamento,
            ),
      )
      .toList();

  List<AgendamentoDetalhado> get _consultasAtivasEFuturas {
    final agora = DateTime.now();
    return _consultasAtivas
        .where((consulta) => consulta.data.isAfter(agora))
        .toList();
  }

  List<AgendamentoDetalhado> get _consultasVisiveisNoCalendario {
    final agora = DateTime.now();
    return _consultasAtivas
        .where(
          (consulta) =>
              consulta.data.isAfter(agora) ||
              DateUtils.isSameDay(consulta.data, agora),
        )
        .toList();
  }

  AgendamentoDetalhado? get _proxima {
    final consultas = _consultasAtivasEFuturas;
    return consultas.isEmpty ? null : consultas.first;
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
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  8,
                  horizontalPadding,
                  48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Meus agendamentos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () {
                            final token = AuthService.instance.sessao?.token;
                            if (token == null || token.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Não foi possível identificar sua sessão. Faça login novamente.',
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    TelaNotificacoes(tokenJwt: token),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Text(
                      'Próxima consulta:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 5),
                    _buildProxima(context),
                    Calendario(agendamentos: _consultasVisiveisNoCalendario),
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
        'Você não tem próximas consultas agendadas.\nToque no + para agendar.',
        textAlign: TextAlign.center,
        style: TextStyle(color: scheme.primary, fontSize: 15),
      ),
    );
  }
}
