import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';

void main() {
  test('normaliza variantes de status finalizado da API', () {
    for (final valor in ['realizado', 'Finalizada', 'concluída', 'ATENDIDA']) {
      final agendamento = Agendamento.fromJson({
        'id_agendamento': 1,
        'id_paciente': 2,
        'id_profissional': 3,
        'id_clinica': 4,
        'id_horario': 5,
        'data_hora_consulta': '2026-10-06T10:00:00.000Z',
        'status': valor,
        'criado_por_usuario': 6,
      });

      expect(agendamento.status, StatusAgendamento.realizado);
    }
  });

  test('não considera agendado quando a API omite status', () {
    expect(
      () => Agendamento.fromJson({
        'id_agendamento': 1,
        'id_paciente': 2,
        'id_profissional': 3,
        'id_clinica': 4,
        'id_horario': 5,
        'data_hora_consulta': '2026-10-06T10:00:00.000Z',
        'criado_por_usuario': 6,
      }),
      throwsA(isA<TypeError>()),
    );
  });

  test('restaura o horário de Brasília após a conversão da API', () {
    final horarioRecebido = DateTime(2026, 10, 6, 10);
    final agendamento = Agendamento(
      idAgendamento: 1,
      idPaciente: 2,
      idProfissional: 3,
      idClinica: 4,
      idHorario: 5,
      dataHoraConsulta: horarioRecebido,
      criadoPorUsuario: 6,
    );
    final detalhado = AgendamentoDetalhado(
      agendamento: agendamento,
      medico: 'Profissional',
      especialidade: 'Clínica geral',
      clinica: 'Clínica',
    );

    expect(detalhado.data, horarioRecebido.add(const Duration(hours: 3)));
    expect(agendamento.dataHoraConsulta, horarioRecebido);
  });
}
