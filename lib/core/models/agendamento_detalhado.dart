import 'package:projeto_final/core/models/agendamento.dart';

/// Um agendamento já com os nomes prontos para exibir na tela.
///
/// A API devolve o agendamento só com IDs (profissional, clínica); o
/// `AgendamentoService` junta com as listas de profissionais e clínicas.
class AgendamentoDetalhado {
  static const Duration _diferencaParaBrasilia = Duration(hours: 3);

  final Agendamento agendamento;
  final String medico;
  final String especialidade;
  final String clinica;
  final String? endereco;

  const AgendamentoDetalhado({
    required this.agendamento,
    required this.medico,
    required this.especialidade,
    required this.clinica,
    this.endereco,
  });

  /// A API envia o horário de Brasília com sufixo UTC; restaura as 3h removidas
  /// pela conversão para o fuso local feita em [Agendamento.fromJson].
  DateTime get data => agendamento.dataHoraConsulta.add(_diferencaParaBrasilia);

  StatusAgendamento get status => agendamento.status;

  /// Ainda vale: nem cancelada nem já realizada (agendada ou remarcada).
  bool get ativo =>
      status == StatusAgendamento.agendado ||
      status == StatusAgendamento.remarcado;
}
