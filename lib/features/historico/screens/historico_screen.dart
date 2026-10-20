import 'package:flutter/material.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/widgets/app_bar.dart';
import 'package:projeto_final/features/historico/models/consulta.dart';
import 'package:projeto_final/features/historico/widgets/consulta_card.dart';
import 'package:projeto_final/services/agendamento_service.dart';

/// Aba "Histórico". O rodapé fica no [MainShellScreen].
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  static const _diasDaSemana = [
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
    'domingo',
  ];
  static const _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  List<Consulta> _consultas = const [];
  bool _carregando = true;
  String? _erro;
  final TextEditingController _buscaController = TextEditingController();
  String _busca = '';
  DateTime? _diaSelecionado;

  @override
  void initState() {
    super.initState();
    AgendamentoService.alteracoes.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    AgendamentoService.alteracoes.removeListener(_carregar);
    _buscaController.dispose();
    super.dispose();
  }

  List<Consulta> get _consultasFiltradas {
    final termo = _busca.trim().toLowerCase();

    return _consultas.where((consulta) {
      final correspondeAoTexto =
          termo.isEmpty ||
          [
            consulta.medico,
            consulta.especialidade,
            consulta.tipoExame,
            consulta.clinica,
            consulta.endereco,
          ].any((campo) => campo.toLowerCase().contains(termo));
      final correspondeAoDia =
          _diaSelecionado == null ||
          DateUtils.isSameDay(consulta.data, _diaSelecionado);

      return correspondeAoTexto && correspondeAoDia;
    }).toList();
  }

  Future<void> _selecionarDia() async {
    final hoje = DateUtils.dateOnly(DateTime.now());
    final dia = await showDatePicker(
      context: context,
      initialDate: _diaSelecionado ?? hoje,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Filtrar consultas por dia',
    );

    if (dia != null && mounted) {
      setState(() => _diaSelecionado = dia);
    }
  }

  void _limparFiltros() {
    _buscaController.clear();
    setState(() {
      _busca = '';
      _diaSelecionado = null;
    });
  }

  String _rotuloDia(DateTime data) {
    final hoje = DateUtils.dateOnly(DateTime.now());
    final dia = DateUtils.dateOnly(data);
    if (DateUtils.isSameDay(dia, hoje)) return 'Hoje';
    if (DateUtils.isSameDay(dia, hoje.subtract(const Duration(days: 1)))) {
      return 'Ontem';
    }

    final nomeDia = _diasDaSemana[data.weekday - 1];
    final nomeMes = _meses[data.month - 1];
    return '$nomeDia, ${data.day} de $nomeMes de ${data.year}';
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final agendamentos = await AgendamentoService.instance.listarMeus();
      final agora = DateTime.now();
      final consultas =
          agendamentos
              .where(
                (agendamento) =>
                    agendamento.status != StatusAgendamento.cancelado,
              )
              .where(
                (agendamento) =>
                    agendamento.status == StatusAgendamento.realizado ||
                    !agendamento.data.isAfter(agora),
              )
              .map(Consulta.fromAgendamento)
              .toList()
            ..sort((a, b) => b.data.compareTo(a.data));

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (screenWidth * 0.045).clamp(16.0, 32.0);

    return Scaffold(
      appBar: const AppBarWidget(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Últimas consultas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  12,
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _buscaController,
                      onChanged: (valor) => setState(() => _busca = valor),
                      decoration: InputDecoration(
                        hintText: 'Buscar médico, especialidade ou clínica',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _busca.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar busca',
                                onPressed: () {
                                  _buscaController.clear();
                                  setState(() => _busca = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selecionarDia,
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              _diaSelecionado == null
                                  ? 'Filtrar por dia'
                                  : '${_diaSelecionado!.day.toString().padLeft(2, '0')}/'
                                        '${_diaSelecionado!.month.toString().padLeft(2, '0')}/'
                                        '${_diaSelecionado!.year}',
                            ),
                          ),
                        ),
                        if (_busca.isNotEmpty || _diaSelecionado != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _limparFiltros,
                            child: const Text('Limpar'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildConteudo(horizontalPadding)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConteudo(double horizontalPadding) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_erro != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _carregar,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_consultas.isEmpty) {
      return const Center(child: Text('Nenhuma consulta no histórico.'));
    }

    final consultas = _consultasFiltradas;
    if (consultas.isEmpty) {
      return const Center(
        child: Text('Nenhuma consulta encontrada com esses filtros.'),
      );
    }

    final grupos = <DateTime, List<Consulta>>{};
    for (final consulta in consultas) {
      final dia = DateUtils.dateOnly(consulta.data);
      grupos.putIfAbsent(dia, () => []).add(consulta);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 16),
      children: [
        for (final grupo in grupos.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _rotuloDia(grupo.key),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  '${grupo.value.length} ${grupo.value.length == 1 ? 'consulta' : 'consultas'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (var i = 0; i < grupo.value.length; i++) ...[
            ConsultaCard(consulta: grupo.value[i]),
            if (i < grupo.value.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
