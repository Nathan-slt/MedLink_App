import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';

/// Consulta exibida no histórico (dados já "montados" para a tela).
///
/// Diferente de `core/models/agendamento.dart`, que espelha a tabela
/// `agendamentos` (só IDs), esta classe traz nomes prontos para exibir.
class Consulta {
  final String medico;
  final String especialidade;
  final String tipoExame;
  final String clinica;
  final String endereco;
  final DateTime data;

  /// Ex.: Consultório, Telemedicina.
  final String tipoLocal;
  final String? fotoUrl;
  final bool finalizada;
  final bool atrasada;

  const Consulta({
    required this.medico,
    required this.especialidade,
    required this.tipoExame,
    required this.clinica,
    required this.endereco,
    required this.data,
    this.tipoLocal = 'Consultório',
    this.fotoUrl,
    this.finalizada = false,
    this.atrasada = false,
  });

  factory Consulta.fromAgendamento(
    AgendamentoDetalhado agendamento, {
    bool concluidaNaSessao = false,
  }) {
    return Consulta(
      medico: agendamento.medico,
      especialidade: agendamento.especialidade,
      tipoExame: 'Consulta médica',
      clinica: agendamento.clinica,
      endereco: agendamento.endereco ?? 'Endereço não informado',
      data: agendamento.data,
      tipoLocal: '',
      finalizada:
          agendamento.status == StatusAgendamento.realizado ||
          concluidaNaSessao,
      atrasada:
          !concluidaNaSessao &&
          agendamento.ativo &&
          agendamento.data.isBefore(DateTime.now()),
    );
  }
}
