import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_final/app/theme.dart';
import 'package:projeto_final/core/models/notificacoes.dart';
import 'package:projeto_final/core/storage/armazenamento_local.dart';
import 'package:projeto_final/features/notificacoes/screens/notificacoes_screen.dart';
import 'package:projeto_final/services/notificacao_service.dart';

class _NotificacaoServiceFake extends NotificacaoService {
  _NotificacaoServiceFake(this.notificacoes);

  final List<Notificacao> notificacoes;

  @override
  Future<List<Notificacao>> listarMinhasNotificacoes(String tokenJwt) async =>
      notificacoes;
}

class _ArmazenamentoLocalFake extends ArmazenamentoLocal {
  final Map<int, Set<int>> dispensadasPorPaciente = {};

  @override
  Future<Set<int>> lerNotificacoesDispensadas(int idPaciente) async => {
    ...?dispensadasPorPaciente[idPaciente],
  };

  @override
  Future<void> salvarNotificacoesDispensadas(
    int idPaciente,
    Set<int> ids,
  ) async {
    dispensadasPorPaciente[idPaciente] = {...ids};
  }
}

String _tokenPaciente() {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'id_usuario': 1, 'papel': 'paciente', 'id_paciente': 5}),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

Notificacao _notificacao(int id, {bool lida = true}) => Notificacao(
  id: id,
  idAgendamento: 100 + id,
  tipo: 'lembrete',
  titulo: 'Consulta $id',
  mensagem: 'Mensagem da consulta $id',
  lida: lida,
  dataEnvio: '2026-10-28T10:00:00Z',
);

Notificacao _notificacaoSemTexto() => Notificacao(
  id: 8,
  idAgendamento: 108,
  tipo: 'lembrete_antecipado',
  titulo: null,
  mensagem: '',
  lida: false,
  dataEnvio: '2026-10-28T14:21:11.000Z',
);

void main() {
  testWidgets('cabeçalho usa azul escuro e foreground branco', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TelaNotificacoes(
          tokenJwt: _tokenPaciente(),
          service: _NotificacaoServiceFake([_notificacao(1)]),
          armazenamento: _ArmazenamentoLocalFake(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppTheme.blue950);
    expect(appBar.foregroundColor, Colors.white);
  });

  testWidgets('separa notificações e sombreia somente as lidas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TelaNotificacoes(
          tokenJwt: _tokenPaciente(),
          service: _NotificacaoServiceFake([
            _notificacao(1, lida: true),
            _notificacao(2, lida: false),
          ]),
          armazenamento: _ArmazenamentoLocalFake(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lida = tester.widget<Container>(
      find.byKey(const ValueKey('notificacao-container-1')),
    );
    final naoLida = tester.widget<Container>(
      find.byKey(const ValueKey('notificacao-container-2')),
    );

    expect(lida.color, isNotNull);
    expect(naoLida.color, isNull);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('usa título padrão e formata data para o horário local', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TelaNotificacoes(
          tokenJwt: _tokenPaciente(),
          service: _NotificacaoServiceFake([_notificacaoSemTexto()]),
          armazenamento: _ArmazenamentoLocalFake(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notificação'), findsOneWidget);
    expect(find.textContaining('Enviado em: '), findsOneWidget);
    expect(find.textContaining('2026-10-28T'), findsNothing);
  });

  testWidgets('dispensar remove da lista e mantém dispensada ao reabrir', (
    tester,
  ) async {
    final armazenamento = _ArmazenamentoLocalFake();
    final service = _NotificacaoServiceFake([_notificacao(1)]);

    Future<void> abrirTela() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TelaNotificacoes(
            tokenJwt: _tokenPaciente(),
            service: service,
            armazenamento: armazenamento,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await abrirTela();
    expect(find.text('Consulta 1'), findsOneWidget);

    await tester.drag(find.text('Consulta 1'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Consulta 1'), findsNothing);
    expect(armazenamento.dispensadasPorPaciente[5], contains(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await abrirTela();

    expect(find.text('Consulta 1'), findsNothing);
    expect(find.text('Nenhuma notificação encontrada.'), findsOneWidget);
  });
}
