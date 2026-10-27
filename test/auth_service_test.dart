import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/services/auth_service.dart';

void main() {
  test('não envia cadastro quando o CPF é inválido ou está ausente', () async {
    var requisicoes = 0;
    final service = AuthService(
      api: ApiClient(
        client: MockClient((_) async {
          requisicoes++;
          return http.Response('{}', 201);
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    for (final cpf in ['529.982.247-24', '']) {
      await expectLater(
        service.cadastrar(
          nome: 'Paciente Teste',
          email: 'paciente@example.com',
          senha: 'senha123',
          cpf: cpf,
          dataNascimento: DateTime(1990, 1, 1),
          telefone: '12997756565',
        ),
        throwsA(isA<ApiException>().having(
          (erro) => erro.mensagem,
          'mensagem',
          'CPF inválido.',
        )),
      );
    }

    expect(requisicoes, 0);
  });

  test('envia cadastro quando o CPF é válido', () async {
    late http.Request requisicao;
    final service = AuthService(
      api: ApiClient(
        client: MockClient((request) async {
          requisicao = request;
          return http.Response('{}', 201);
        }),
        baseUrl: 'http://teste/api',
      ),
    );

    await service.cadastrar(
      nome: 'Paciente Teste',
      email: 'paciente@example.com',
      senha: 'senha123',
      cpf: '529.982.247-25',
      dataNascimento: DateTime(1990, 1, 1),
      telefone: '12997756565',
    );

    expect(requisicao.method, 'POST');
    expect(requisicao.url.path, '/api/usuarios/cadastro');
    expect(jsonDecode(requisicao.body)['cpf'], '529.982.247-25');
  });
}