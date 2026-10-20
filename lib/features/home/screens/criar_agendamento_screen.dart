import 'package:flutter/material.dart';
import 'package:projeto_final/app/navigation.dart';
import 'package:projeto_final/core/models/clinica.dart';
import 'package:projeto_final/core/models/especialidade.dart';
import 'package:projeto_final/core/models/horario_disponivel.dart';
import 'package:projeto_final/core/models/profissional.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/widgets/app_bar.dart';
import 'package:projeto_final/services/agendamento_service.dart';

String _formatarData(DateTime d) {
  final dia = d.day.toString().padLeft(2, '0');
  final mes = d.month.toString().padLeft(2, '0');
  return '$dia/$mes/${d.year}';
}

/// Tela empilhada por cima do shell (aberta pelo botão "+" da Home).
/// Tem botão de voltar e não repete o rodapé.
class CriarAgendamentoScreen extends StatefulWidget {
  const CriarAgendamentoScreen({super.key});

  @override
  State<CriarAgendamentoScreen> createState() => _CriarAgendamentoScreenState();
}

class _CriarAgendamentoScreenState extends State<CriarAgendamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataController = TextEditingController();

  // Só passa a validar enquanto o usuário digita depois da 1ª tentativa
  // de agendar, para não mostrar erros num formulário ainda vazio.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  int? _idEspecialidade;
  int? _idProfissional;
  int? _idClinica;
  DateTime? _data;
  HorarioDisponivel? _horarioSelecionado;
  List<Clinica> _clinicas = const [];
  List<Especialidade> _especialidades = const [];
  List<Profissional> _profissionais = const [];
  List<HorarioDisponivel> _horarios = const [];
  bool _carregandoClinicas = true;
  bool _carregandoEspecialidades = true;
  bool _carregandoProfissionais = false;
  bool _carregandoHorarios = false;
  bool _enviando = false;
  String? _erroClinicas;
  String? _erroEspecialidades;
  String? _erroProfissionais;
  String? _erroHorarios;

  @override
  void initState() {
    super.initState();
    _carregarClinicas();
    _carregarEspecialidades();
  }

  @override
  void dispose() {
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _carregarClinicas() async {
    setState(() {
      _carregandoClinicas = true;
      _erroClinicas = null;
    });

    try {
      final clinicas = await AgendamentoService.instance.listarClinicas();
      if (!mounted) return;
      setState(() {
        _clinicas = clinicas;
        _carregandoClinicas = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroClinicas = e.mensagem;
        _carregandoClinicas = false;
      });
    }
  }

  Future<void> _carregarEspecialidades() async {
    setState(() {
      _carregandoEspecialidades = true;
      _erroEspecialidades = null;
    });

    try {
      final especialidades =
          await AgendamentoService.instance.listarEspecialidades();
      if (!mounted) return;
      setState(() {
        _especialidades = especialidades;
        _carregandoEspecialidades = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroEspecialidades = e.mensagem;
        _carregandoEspecialidades = false;
      });
    }
  }

  Future<void> _carregarProfissionais() async {
    final idClinica = _idClinica;
    final idEspecialidade = _idEspecialidade;
    if (idClinica == null || idEspecialidade == null) return;

    setState(() {
      _carregandoProfissionais = true;
      _erroProfissionais = null;
    });

    try {
      final profissionais = await AgendamentoService.instance.listarProfissionais(
        idEspecialidade: idEspecialidade,
        idClinica: idClinica,
      );
      if (!mounted ||
          _idClinica != idClinica ||
          _idEspecialidade != idEspecialidade) {
        return;
      }
      setState(() {
        _profissionais = profissionais;
        _carregandoProfissionais = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroProfissionais = e.mensagem;
        _carregandoProfissionais = false;
      });
    }
  }

  Future<void> _carregarHorarios() async {
    final idProfissional = _idProfissional;
    final data = _data;
    if (idProfissional == null || data == null) return;

    setState(() {
      _carregandoHorarios = true;
      _erroHorarios = null;
      _horarioSelecionado = null;
    });

    try {
      final horarios =
          await AgendamentoService.instance.listarHorariosDisponiveis(
        idProfissional,
      );
      if (!mounted || _idProfissional != idProfissional || _data != data) {
        return;
      }
      setState(() {
        _horarios = horarios
          .where((horario) => horario.disponivel)
            .where((horario) => DateUtils.isSameDay(horario.data, data))
            .toList();
        _carregandoHorarios = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erroHorarios = e.mensagem;
        _carregandoHorarios = false;
      });
    }
  }

  void _selecionarClinica(String? valor) {
    setState(() {
      _idClinica = int.tryParse(valor ?? '');
      _idProfissional = null;
      _profissionais = const [];
      _horarios = const [];
      _horarioSelecionado = null;
    });
    _carregarProfissionais();
  }

  void _selecionarEspecialidade(String? valor) {
    setState(() {
      _idEspecialidade = int.tryParse(valor ?? '');
      _idProfissional = null;
      _profissionais = const [];
      _horarios = const [];
      _horarioSelecionado = null;
    });
    _carregarProfissionais();
  }

  void _selecionarProfissional(String? valor) {
    setState(() {
      _idProfissional = int.tryParse(valor ?? '');
      _horarios = const [];
      _horarioSelecionado = null;
    });
    _carregarHorarios();
  }

  Future<void> _selecionarData() async {
    final hoje = DateUtils.dateOnly(DateTime.now());

    final data = await showDatePicker(
      context: context,
      initialDate: _data ?? hoje,
      firstDate: hoje,
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'Selecione a data',
    );

    if (data == null || !mounted) return;

    setState(() {
      _data = data;
      _dataController.text = _formatarData(data);
      _horarioSelecionado = null;
    });
    await _carregarHorarios();
  }

  Future<void> _agendar() async {
    final valido = _formKey.currentState?.validate() ?? false;

    if (!valido) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }

    final data = _data;
    final horario = _horarioSelecionado;
    final idClinica = _idClinica;
    final idProfissional = _idProfissional;
    if (data == null ||
        horario == null ||
        idClinica == null ||
        idProfissional == null) {
      return;
    }

    final partesHora = horario.horaInicio.split(':');
    final dataHoraConsulta = DateTime.utc(
      data.year,
      data.month,
      data.day,
      int.parse(partesHora[0]),
      int.parse(partesHora[1]),
    );

    setState(() => _enviando = true);
    try {
      await AgendamentoService.instance.criarAgendamento(
        idClinica: idClinica,
        idProfissional: idProfissional,
        idHorario: horario.idHorario,
        dataHoraConsulta: dataHoraConsulta,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppNavigator.messengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Agendamento criado com sucesso.')),
        );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (screenWidth * 0.045).clamp(16.0, 32.0);

    final clinicaIds = _clinicas.map((clinica) => '${clinica.idClinica}').toList();
    final nomesClinicas = {
      for (final clinica in _clinicas)
        '${clinica.idClinica}': clinica.nome,
    };
    final especialidadeIds =
        _especialidades.map((especialidade) => '${especialidade.idEspecialidade}').toList();
    final nomesEspecialidades = {
      for (final especialidade in _especialidades)
        '${especialidade.idEspecialidade}': especialidade.nome,
    };
    final profissionalIds =
        _profissionais.map((profissional) => '${profissional.idProfissional}').toList();
    final nomesProfissionais = {
      for (final profissional in _profissionais)
        '${profissional.idProfissional}': profissional.nome,
    };
    final horariosDoDia = _horarios
      .where((horario) => horario.disponivel)
        .where((horario) => _data != null && DateUtils.isSameDay(horario.data, _data))
        .toList();
    final horarioIds = horariosDoDia.map((horario) => '${horario.idHorario}').toList();
    final nomesHorarios = {
      for (final horario in horariosDoDia)
        '${horario.idHorario}': horario.horaExibicao,
    };

    return Scaffold(
      appBar: const AppBarWidget(showBackButton: true),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Criar agendamento',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _CampoDropdown(
                      rotulo: 'Clínica',
                      hint: _carregandoClinicas
                          ? 'Carregando clínicas...'
                          : _clinicas.isEmpty
                              ? 'Nenhuma clínica disponível'
                              : 'Selecione a clínica',
                      mensagemErro: 'Selecione a clínica',
                      opcoes: clinicaIds,
                      rotulosOpcoes: nomesClinicas,
                        onChanged: _clinicas.isEmpty || _carregandoClinicas
                          ? null
                          : _selecionarClinica,
                    ),
                    if (_erroClinicas != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _carregarClinicas,
                          child: const Text('Tentar carregar clínicas novamente'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    _CampoDropdown(
                      key: ValueKey('especialidade-$_idClinica'),
                      rotulo: 'Especialidade',
                      hint: _carregandoEspecialidades
                          ? 'Carregando especialidades...'
                          : 'Selecione a especialidade médica',
                      mensagemErro: 'Selecione a especialidade',
                      opcoes: especialidadeIds,
                      rotulosOpcoes: nomesEspecialidades,
                      onChanged: _especialidades.isEmpty ||
                              _carregandoEspecialidades
                          ? null
                          : _selecionarEspecialidade,
                    ),
                    if (_erroEspecialidades != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _erroEspecialidades!,
                        style: TextStyle(color: scheme.error),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _carregarEspecialidades,
                          child: const Text(
                            'Tentar carregar especialidades novamente',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // A key recria o campo (e limpa a seleção) quando a
                    // especialidade muda. Fica desabilitado até escolher uma.
                    _CampoDropdown(
                      key: ValueKey('profissional-$_idClinica-$_idEspecialidade'),
                      rotulo: 'Profissional',
                      hint: _idClinica == null || _idEspecialidade == null
                        ? 'Selecione clínica e especialidade'
                        : _carregandoProfissionais
                          ? 'Carregando profissionais...'
                          : _erroProfissionais ?? 'Selecione o profissional',
                      mensagemErro: 'Selecione o profissional',
                      opcoes: profissionalIds,
                      rotulosOpcoes: nomesProfissionais,
                      onChanged: profissionalIds.isEmpty ||
                          _carregandoProfissionais
                          ? null
                        : _selecionarProfissional,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _CampoComRotulo(
                            rotulo: 'Data',
                            child: TextFormField(
                              controller: _dataController,
                              readOnly: true,
                              showCursor: false,
                              onTap: _idProfissional == null
                                  ? null
                                  : _selecionarData,
                              style: TextStyle(
                                fontSize: 14,
                                color: scheme.primary,
                              ),
                              decoration: _decoracaoCampo(
                                context,
                                hint: _idProfissional == null
                                  ? 'Selecione profissional'
                                  : 'dd/mm/aaaa',
                                suffixIcon: Icon(
                                  Icons.calendar_today_outlined,
                                  size: 20,
                                  color: scheme.primary,
                                ),
                              ),
                              validator: (valor) =>
                                    (valor == null || valor.isEmpty)
                                      ? 'Selecione a data'
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _CampoDropdown(
                            key: ValueKey(
                              'horario-$_idProfissional-${_data?.toIso8601String()}',
                            ),
                            rotulo: 'Hora',
                            hint: _idProfissional == null
                              ? 'Selecione profissional'
                              : _data == null
                                ? 'Selecione a data'
                                : _carregandoHorarios
                                  ? 'Carregando horários...'
                                  : horariosDoDia.isEmpty
                                    ? _erroHorarios ??
                                      'Sem horários livres'
                                    : 'Selecione o horário',
                            mensagemErro: 'Selecione o horário',
                            opcoes: horarioIds,
                            rotulosOpcoes: nomesHorarios,
                            onChanged: horariosDoDia.isEmpty ||
                                _carregandoHorarios
                              ? null
                              : (valor) => setState(() {
                                final id = int.tryParse(valor ?? '');
                                _horarioSelecionado = horariosDoDia
                                  .where((horario) =>
                                    horario.idHorario == id)
                                  .firstOrNull;
                                }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: scheme.secondary,
                                side: BorderSide(
                                  color: scheme.secondary,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _enviando ? null : _agendar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.secondary,
                                foregroundColor: scheme.onSecondary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: _enviando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Agendar',
                                      style: TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ),
                      ],
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

/// Borda/preenchimento comuns a todos os campos do formulário.
InputDecoration _decoracaoCampo(
  BuildContext context, {
  String? hint,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;

  OutlineInputBorder borda(Color cor, [double largura = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: cor, width: largura),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: 14,
      color: scheme.primary.withValues(alpha: 0.6),
    ),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    suffixIcon: suffixIcon,
    enabledBorder: borda(scheme.primary.withValues(alpha: 0.6)),
    disabledBorder: borda(scheme.primary.withValues(alpha: 0.25)),
    focusedBorder: borda(scheme.secondary, 1.5),
    errorBorder: borda(scheme.error),
    focusedErrorBorder: borda(scheme.error, 1.5),
  );
}

/// Rótulo em negrito acima de um campo (mesmo estilo do login).
class _CampoComRotulo extends StatelessWidget {
  final String rotulo;
  final Widget child;

  const _CampoComRotulo({required this.rotulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Campo de seleção (lista suspensa) com rótulo e validação de obrigatório.
/// Com [onChanged] nulo, o campo fica desabilitado.
class _CampoDropdown extends StatelessWidget {
  final String rotulo;
  final String hint;
  final String mensagemErro;
  final List<String> opcoes;
  final Map<String, String>? rotulosOpcoes;
  final ValueChanged<String?>? onChanged;

  const _CampoDropdown({
    super.key,
    required this.rotulo,
    required this.hint,
    required this.mensagemErro,
    required this.opcoes,
    required this.onChanged,
    this.rotulosOpcoes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final habilitado = onChanged != null;

    return _CampoComRotulo(
      rotulo: rotulo,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _decoracaoCampo(context),
        icon: const Icon(Icons.keyboard_arrow_down),
        iconEnabledColor: scheme.primary,
        iconDisabledColor: scheme.primary.withValues(alpha: 0.35),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(8),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: scheme.primary,
        ),
        hint: Text(
          hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: scheme.primary.withValues(alpha: habilitado ? 0.6 : 0.35),
          ),
        ),
        items: [
          for (final opcao in opcoes)
            DropdownMenuItem<String>(
              value: opcao,
              child: Text(rotulosOpcoes?[opcao] ?? opcao),
            ),
        ],
        onChanged: onChanged,
        validator: (valor) => valor == null ? mensagemErro : null,
      ),
    );
  }
}
