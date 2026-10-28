import 'package:flutter/material.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/widgets/app_bar.dart';
import 'package:projeto_final/features/historico/models/consulta.dart';
import 'package:projeto_final/features/historico/widgets/consulta_card.dart';
import 'package:projeto_final/services/agendamento_service.dart';

enum _FiltroPeriodo { todos, semana, dia, mes }

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
  DateTime _dataReferencia = DateTime.now();
  _FiltroPeriodo _filtroPeriodo = _FiltroPeriodo.todos;

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
      final correspondeAoPeriodo = switch (_filtroPeriodo) {
        _FiltroPeriodo.todos => true,
        _FiltroPeriodo.dia => DateUtils.isSameDay(
          consulta.data,
          _dataReferencia,
        ),
        _FiltroPeriodo.semana => _estaNaSemana(consulta.data),
        _FiltroPeriodo.mes =>
          consulta.data.year == _dataReferencia.year &&
              consulta.data.month == _dataReferencia.month,
      };
      return correspondeAoTexto && correspondeAoPeriodo && consulta.finalizada;
    }).toList();
  }

  DateTime _inicioDaSemana(DateTime data) {
    final dia = DateUtils.dateOnly(data);
    return dia.subtract(Duration(days: dia.weekday - DateTime.monday));
  }

  bool _estaNaSemana(DateTime data) {
    final inicio = _inicioDaSemana(_dataReferencia);
    final fim = inicio.add(const Duration(days: 7));
    final dia = DateUtils.dateOnly(data);
    return !dia.isBefore(inicio) && dia.isBefore(fim);
  }

  String _formatarDataCurta(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}';

  String get _rotuloDataReferencia {
    return switch (_filtroPeriodo) {
      _FiltroPeriodo.todos => '',
      _FiltroPeriodo.dia =>
        '${_formatarDataCurta(_dataReferencia)}/${_dataReferencia.year}',
      _FiltroPeriodo.semana =>
        '${_formatarDataCurta(_inicioDaSemana(_dataReferencia))} - '
            '${_formatarDataCurta(_inicioDaSemana(_dataReferencia).add(const Duration(days: 6)))}/'
            '${_dataReferencia.year}',
      _FiltroPeriodo.mes =>
        '${_meses[_dataReferencia.month - 1]} ${_dataReferencia.year}',
    };
  }

  Future<void> _selecionarDataReferencia() async {
    final dia = await showDatePicker(
      context: context,
      initialDate: _dataReferencia,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Escolher referência do período',
    );

    if (dia != null && mounted) {
      setState(() => _dataReferencia = dia);
    }
  }

  void _limparFiltros() {
    _buscaController.clear();
    setState(() {
      _busca = '';
      _dataReferencia = DateTime.now();
      _filtroPeriodo = _FiltroPeriodo.todos;
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
      final consultas =
          agendamentos
              .where(
                (agendamento) =>
                    agendamento.status != StatusAgendamento.cancelado,
              )
              .map(
                (agendamento) => Consulta.fromAgendamento(
                  agendamento,
                  concluidaNaSessao: AgendamentoService.foiConcluidaNaSessao(
                    agendamento.agendamento.idAgendamento,
                  ),
                ),
              )
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
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (screenWidth < 430)
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: DropdownButtonFormField<_FiltroPeriodo>(
                              initialValue: _filtroPeriodo,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.filter_list, size: 18),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: _FiltroPeriodo.todos,
                                  child: Text('Todos'),
                                ),
                                DropdownMenuItem(
                                  value: _FiltroPeriodo.semana,
                                  child: Text('Semana'),
                                ),
                                DropdownMenuItem(
                                  value: _FiltroPeriodo.dia,
                                  child: Text('Dia'),
                                ),
                                DropdownMenuItem(
                                  value: _FiltroPeriodo.mes,
                                  child: Text('Mês'),
                                ),
                              ],
                              onChanged: (periodo) {
                                if (periodo != null) {
                                  setState(() => _filtroPeriodo = periodo);
                                }
                              },
                            ),
                          )
                        else
                          SegmentedButton<_FiltroPeriodo>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                              padding: WidgetStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: _FiltroPeriodo.todos,
                                label: Text('Todos'),
                              ),
                              ButtonSegment(
                                value: _FiltroPeriodo.semana,
                                label: Text('Semana'),
                              ),
                              ButtonSegment(
                                value: _FiltroPeriodo.dia,
                                label: Text('Dia'),
                              ),
                              ButtonSegment(
                                value: _FiltroPeriodo.mes,
                                label: Text('Mês'),
                              ),
                            ],
                            selected: {_filtroPeriodo},
                            onSelectionChanged: (selecionados) => setState(
                              () => _filtroPeriodo = selecionados.single,
                            ),
                          ),
                        if (_filtroPeriodo != _FiltroPeriodo.todos)
                          if (screenWidth < 430)
                            IconButton(
                              tooltip: 'Período: $_rotuloDataReferencia',
                              onPressed: _selecionarDataReferencia,
                              icon: const Icon(Icons.calendar_today_outlined),
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 40,
                                height: 40,
                              ),
                              padding: EdgeInsets.zero,
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: _selecionarDataReferencia,
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(_rotuloDataReferencia),
                            ),
                        TextButton(
                          onPressed: _limparFiltros,
                          child: const Text('Limpar'),
                        ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nenhuma consulta encontrada com esses filtros.'),
            if (_busca.isNotEmpty ||
                _filtroPeriodo != _FiltroPeriodo.todos) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _limparFiltros,
                child: const Text('Mostrar todo o histórico'),
              ),
            ],
          ],
        ),
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
