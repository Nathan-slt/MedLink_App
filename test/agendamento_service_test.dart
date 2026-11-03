import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_final/core/auth/sessao.dart';
import 'package:projeto_final/core/models/agendamento.dart';
import 'package:projeto_final/core/models/usuario.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/services/agendamento_service.dart';
import 'package:projeto_final/services/auth_service.dart';

class _AuthServiceFake extends AuthService {
  @override
  Sessao? get sessao => const Sessao(
    token: 'token-teste',
    idUsuario: 1,
    papel: PapelUsuario.paciente,
    idPaciente: 9,
  );
}

void main() {
  final authOriginal = AuthService.instance;
  tearDown(() => AuthService.instance = authOriginal);

  test(
    'usa status finalizado da fila para incluir agendamento no histórico',
    () async {
      final caminhos = <String>[];
      AuthService.instance = _AuthServiceFake();
      final service = AgendamentoService(
        api: ApiClient(
          client: MockClient((request) async {
            caminhos.add(request.url.path);
            final corpo = switch (request.url.path) {
              '/api/agendamentos/paciente/9' => [
                {
                  'id_agendamento': 20,
                  'id_paciente': 9,
                  'id_profissional': 3,
                  'id_clinica': 7,
                  'id_horario': 10,
                  'data_hora_consulta': '2026-10-27T13:00:00.000Z',
                  'status': 'agendado',
                  'criado_por_usuario': 1,
                },
              ],
              '/api/profissionais' => [
                {
                  'id_profissional': 3,
                  'nome': 'Dra. Ana',
                  'Especialidade': {'nome': 'Clínica geral'},
                },
              ],
              '/api/clinica' => [
                {
                  'id_clinica': 7,
                  'nome': 'Clínica MedLink',
                  'endereco': 'Rua Central, 100',
                },
              ],
              '/api/fila/historico' => [
                {'id_agendamento': 20, 'status_fila': 'finalizado'},
              ],
              _ => throw StateError('Rota inesperada: ${request.url.path}'),
            };
            return http.Response(
              jsonEncode(corpo),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
          baseUrl: 'http://teste/api',
        ),
      );

      final agendamentos = await service.listarMeus();

      expect(caminhos, contains('/api/fila/historico'));
      expect(agendamentos.single.status, StatusAgendamento.realizado);
      expect(agendamentos.single.medico, 'Dra. Ana');
    },
  );

  test('lista clínicas da API em ordem alfabética', () async {
    late http.Request requisicao;
    final service = AgendamentoService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response(
            jsonEncode([
              {'id_clinica': 2, 'nome': 'Clínica Sul'},
              {'id_clinica': 1, 'nome': 'Clínica Centro'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    final clinicas = await service.listarClinicas();

    expect(requisicao.url.path, '/api/clinica');
    expect(clinicas.map((clinica) => clinica.nome), [
      'Clínica Centro',
      'Clínica Sul',
    ]);
    expect(clinicas.first.idClinica, 1);
  });

  test('lista especialidades da API em ordem alfabética', () async {
    late http.Request requisicao;
    final service = AgendamentoService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response(
            jsonEncode([
              {'id_especialidade': 2, 'nome': 'Ortopedia'},
              {'id_especialidade': 1, 'nome': 'Cardiologia'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    final especialidades = await service.listarEspecialidades();

    expect(requisicao.url.path, '/api/especialidades');
    expect(especialidades.map((especialidade) => especialidade.nome), [
      'Cardiologia',
      'Ortopedia',
    ]);
  });

  test('filtra profissionais pela clínica e especialidade', () async {
    late http.Request requisicao;
    final service = AgendamentoService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response(
            jsonEncode([
              {
                'id_profissional': 3,
                'nome': 'Dra. Ana',
                'id_especialidade': 5,
                'registro_profissional': 'CRM-123',
                'id_clinica': 7,
                'ativo': true,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    final profissionais = await service.listarProfissionais(
      idEspecialidade: 5,
      idClinica: 7,
    );

    expect(requisicao.url.path, '/api/profissionais');
    expect(requisicao.url.queryParameters, {
      'id_especialidade': '5',
      'id_clinica': '7',
    });
    expect(profissionais.single.idProfissional, 3);
  });

  test('lista somente horários disponíveis do profissional', () async {
    late http.Request requisicao;
    final service = AgendamentoService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response(
            jsonEncode([
              {
                'id_horario': 10,
                'id_profissional': 3,
                'data': '2026-10-10',
                'hora_inicio': '08:00:00',
                'hora_fim': '08:30:00',
                'disponivel': true,
              },
              {
                'id_horario': 11,
                'id_profissional': 3,
                'data': '2026-10-10',
                'hora_inicio': '08:30:00',
                'hora_fim': '09:00:00',
                'disponivel': false,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    final horarios = await service.listarHorariosDisponiveis(3);

    expect(requisicao.url.path, '/api/horarios/profissional/3');
    expect(horarios.map((horario) => horario.idHorario), [10]);
    expect(horarios.single.horaExibicao, '08:00');
  });

  test('envia payload do paciente na rota correta e notifica a Home', () async {
    late http.Request requisicao;
    final alteracoesAntes = AgendamentoService.alteracoes.value;
    final service = AgendamentoService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response(
            '{}',
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    await service.criarAgendamento(
      idClinica: 7,
      idProfissional: 3,
      idHorario: 10,
      dataHoraConsulta: DateTime.utc(2026, 10, 10, 11),
    );

    expect(requisicao.method, 'POST');
    expect(requisicao.url.path, '/api/agendamentos/criar-agendamento');
    expect(jsonDecode(requisicao.body), {
      'id_clinica': 7,
      'id_profissional': 3,
      'id_horario': 10,
      'data_hora_consulta': '2026-10-10T11:00:00.000Z',
    });
    expect(AgendamentoService.alteracoes.value, alteracoesAntes + 1);
  });
}
