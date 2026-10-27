/// Status de um agendamento (ENUM `status` no banco).
enum StatusAgendamento {
  agendado('agendado'),
  remarcado('remarcado'),
  cancelado('cancelado'),
  realizado('realizado');

  /// Valor exatamente como a API envia/recebe.
  final String valor;

  const StatusAgendamento(this.valor);

  static StatusAgendamento fromJson(String valor) {
    final normalizado = valor
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll(RegExp(r'[\s-]+'), '_');

    return switch (normalizado) {
      'agendado' || 'agendada' => StatusAgendamento.agendado,
      'remarcado' || 'remarcada' => StatusAgendamento.remarcado,
      'cancelado' || 'cancelada' => StatusAgendamento.cancelado,
      'realizado' ||
      'realizada' ||
      'atendido' ||
      'atendida' ||
      'finalizado' ||
      'finalizada' ||
      'concluido' ||
      'concluida' => StatusAgendamento.realizado,
      _ => throw FormatException('Status de agendamento inválido: $valor'),
    };
  }
}

/// Tabela `agendamentos`.
class Agendamento {
  final int idAgendamento;
  final int idPaciente;
  final int idProfissional;
  final int idClinica;
  final int idHorario;
  final DateTime dataHoraConsulta;
  final StatusAgendamento status;
  final int criadoPorUsuario;

  const Agendamento({
    required this.idAgendamento,
    required this.idPaciente,
    required this.idProfissional,
    required this.idClinica,
    required this.idHorario,
    required this.dataHoraConsulta,
    required this.criadoPorUsuario,
    this.status = StatusAgendamento.agendado,
  });

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    return Agendamento(
      idAgendamento: json['id_agendamento'] as int,
      idPaciente: json['id_paciente'] as int,
      idProfissional: json['id_profissional'] as int,
      idClinica: json['id_clinica'] as int,
      idHorario: json['id_horario'] as int,
      // A API manda a data em UTC (ISO 8601); converte para o fuso do aparelho.
      dataHoraConsulta:
          DateTime.parse(json['data_hora_consulta'] as String).toLocal(),
      status: StatusAgendamento.fromJson(json['status'] as String),
      criadoPorUsuario: json['criado_por_usuario'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_agendamento': idAgendamento,
      'id_paciente': idPaciente,
      'id_profissional': idProfissional,
      'id_clinica': idClinica,
      'id_horario': idHorario,
      'data_hora_consulta': dataHoraConsulta.toUtc().toIso8601String(),
      'status': status.valor,
      'criado_por_usuario': criadoPorUsuario,
    };
  }
}
