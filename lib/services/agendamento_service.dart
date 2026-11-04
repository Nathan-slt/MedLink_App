import 'package:flutter/foundation.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/core/models/clinica.dart';
import 'package:projeto_final/core/models/especialidade.dart';
import 'package:projeto_final/core/models/horario_disponivel.dart';
import 'package:projeto_final/core/models/profissional.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/services/auth_service.dart';

/// Agendamentos do paciente logado.
class AgendamentoService {
  AgendamentoService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  /// Instância usada pelo app. Pode ser trocada em testes.
  static AgendamentoService instance = AgendamentoService();

  /// Sobe a cada mudança (criar, cancelar, remarcar). As telas que mostram
  /// agendamentos escutam isto e recarregam.
  static final ValueNotifier<int> alteracoes = ValueNotifier<int>(0);

  static void notificarAlteracao() => alteracoes.value++;

  static void notificarConclusaoConsulta() => notificarAlteracao();

  final ApiClient _api;

  /// Lista clínicas disponíveis para seleção no formulário de agendamento.
  Future<List<Clinica>> listarClinicas() async {
    final resposta = await _api.get('/clinica');
    try {
      final clinicas = _lista(resposta).map(Clinica.fromJson).toList();
      clinicas.sort((a, b) => a.nome.compareTo(b.nome));
      return clinicas;
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  Future<List<Especialidade>> listarEspecialidades() async {
    final resposta = await _api.get('/especialidades');
    try {
      final especialidades = _lista(
        resposta,
      ).map(Especialidade.fromJson).toList();
      especialidades.sort((a, b) => a.nome.compareTo(b.nome));
      return especialidades;
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  Future<List<Profissional>> listarProfissionais({
    required int idEspecialidade,
    required int idClinica,
  }) async {
    final resposta = await _api.get(
      '/profissionais',
      query: {
        'id_especialidade': '$idEspecialidade',
        'id_clinica': '$idClinica',
      },
    );
    try {
      final profissionais =
          _lista(resposta)
              .map(Profissional.fromJson)
              .where((profissional) => profissional.ativo)
              .toList()
            ..sort((a, b) => a.nome.compareTo(b.nome));
      return profissionais;
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  Future<List<HorarioDisponivel>> listarHorariosDisponiveis(
    int idProfissional,
  ) async {
    final resposta = await _api.get('/horarios/profissional/$idProfissional');
    try {
      final horarios =
          _lista(resposta)
              .map(HorarioDisponivel.fromJson)
              .where((horario) => horario.disponivel)
              .toList()
            ..sort((a, b) {
              final porData = a.data.compareTo(b.data);
              return porData != 0
                  ? porData
                  : a.horaInicio.compareTo(b.horaInicio);
            });
      return horarios;
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  Future<void> criarAgendamento({
    required int idClinica,
    required int idProfissional,
    required int idHorario,
    required DateTime dataHoraConsulta,
  }) async {
    await _api.post(
      '/agendamentos/criar-agendamento',
      corpo: {
        'id_clinica': idClinica,
        'id_profissional': idProfissional,
        'id_horario': idHorario,
        'data_hora_consulta': dataHoraConsulta.toUtc().toIso8601String(),
      },
    );
    notificarAlteracao();
  }

  /// Todos os agendamentos do paciente, do mais antigo para o mais novo.
  ///
  /// O backend devolve `/agendamentos/paciente/:id` só com IDs. Para mostrar
  /// nome do médico, especialidade e clínica, busca também `/profissionais`
  /// (que já traz a especialidade), `/clinica` e o histórico da fila, que
  /// confirma consultas finalizadas pelo atendimento.
  ///
  /// O histórico da fila é só um complemento: se essa chamada falhar, a lista
  /// continua funcionando (as consultas finalizadas apenas deixam de ser
  /// marcadas como realizadas pela fila).
  Future<List<AgendamentoDetalhado>> listarMeus() async {
    final idPaciente = AuthService.instance.sessao?.idPaciente;
    if (idPaciente == null) {
      throw const ApiException('Sessão inválida. Faça login novamente.');
    }

    // As quatro chamadas rodam ao mesmo tempo. A do histórico nunca derruba
    // as outras: se falhar, vira uma lista vazia.
    final respostas = await Future.wait<dynamic>([
      _api.get('/agendamentos/paciente/$idPaciente'),
      _api.get('/profissionais'),
      _api.get('/clinica'),
      _api.get('/fila/historico').catchError((Object erro) {
        debugPrint('Não foi possível carregar /fila/historico: $erro');
        return const [];
      }),
    ]);

    try {
      final agendamentos = _lista(
        respostas[0],
      ).map(Agendamento.fromJson).toList();

      final agendamentosFinalizadosNaFila = <int>{};
      final historicoFila = respostas[3] is List
          ? _lista(respostas[3])
          : const <Map<String, dynamic>>[];

      for (final fila in historicoFila) {
        final idAgendamento = fila['id_agendamento'];
        final statusFila = fila['status_fila'] ?? fila['status'];
        // registro incompleto: ignora e segue para o próximo
        if (idAgendamento is! int || statusFila is! String) continue;

        final statusNormalizado = statusFila
            .trim()
            .toLowerCase()
            .replaceAll(RegExp('[áàâãä]'), 'a')
            .replaceAll(RegExp('[éèêë]'), 'e')
            .replaceAll(RegExp('[íìîï]'), 'i')
            .replaceAll(RegExp('[óòôõö]'), 'o')
            .replaceAll(RegExp('[úùûü]'), 'u')
            .replaceAll(RegExp(r'[\s-]+'), '_');
        if (statusNormalizado == 'finalizado' ||
            statusNormalizado == 'finalizada') {
          agendamentosFinalizadosNaFila.add(idAgendamento);
        }
      }

      final profissionais = {
        for (final p in _lista(respostas[1])) p['id_profissional'] as int: p,
      };
      final clinicas = {
        for (final c in _lista(respostas[2])) c['id_clinica'] as int: c,
      };

      final detalhados = agendamentos.map((a) {
        final agendamento =
            agendamentosFinalizadosNaFila.contains(a.idAgendamento)
            ? a.copyWith(status: StatusAgendamento.realizado)
            : a;
        final profissional = profissionais[a.idProfissional];
        final especialidade = profissional?['Especialidade'];
        final clinica = clinicas[a.idClinica];

        return AgendamentoDetalhado(
          agendamento: agendamento,
          medico: profissional?['nome'] as String? ?? 'Profissional',
          especialidade: especialidade is Map
              ? (especialidade['nome'] as String?) ?? ''
              : '',
          clinica: clinica?['nome'] as String? ?? 'Clínica',
          endereco: clinica?['endereco'] as String?,
        );
      }).toList();

      detalhados.sort((a, b) => a.data.compareTo(b.data));
      return detalhados;
    } on FormatException {
      throw const ApiException('Resposta inesperada do servidor.');
    } on TypeError {
      throw const ApiException('Resposta inesperada do servidor.');
    }
  }

  List<Map<String, dynamic>> _lista(dynamic dado) {
    if (dado is! List) throw const FormatException('Esperava uma lista.');
    return dado.cast<Map<String, dynamic>>();
  }
}