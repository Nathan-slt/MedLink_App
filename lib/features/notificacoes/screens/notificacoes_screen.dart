import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:projeto_final/core/auth/sessao.dart';
import 'package:projeto_final/core/storage/armazenamento_local.dart';
import 'package:projeto_final/services/notificacao_service.dart';
import 'package:projeto_final/core/models/notificacoes.dart';

class TelaNotificacoes extends StatefulWidget {
  final String tokenJwt; // Passe o token do usuário logado para a tela
  final NotificacaoService? service;
  final ArmazenamentoLocal? armazenamento;

  const TelaNotificacoes({
    super.key,
    required this.tokenJwt,
    this.service,
    this.armazenamento,
  });

  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  late final NotificacaoService _service =
      widget.service ?? NotificacaoService();
  late final ArmazenamentoLocal _armazenamento =
      widget.armazenamento ?? ArmazenamentoLocal();
  final Set<int> _dispensadas = {};
  late Future<List<Notificacao>> _futureNotificacoes;

  @override
  void initState() {
    super.initState();
    _futureNotificacoes = _buscarNotificacoes();
  }

  void _carregarNotificacoes() {
    setState(() {
      _futureNotificacoes = _buscarNotificacoes();
    });
  }

  Future<List<Notificacao>> _buscarNotificacoes() async {
    final sessao = Sessao.fromToken(widget.tokenJwt);
    final idPaciente = sessao.idPaciente;
    if (idPaciente == null) {
      throw const FormatException('Sessão sem paciente associado.');
    }

    final dispensadas = await _armazenamento.lerNotificacoesDispensadas(
      idPaciente,
    );
    _dispensadas
      ..clear()
      ..addAll(dispensadas);
    return _service.listarMinhasNotificacoes(widget.tokenJwt);
  }

  Future<void> _dispensar(Notificacao notificacao) async {
    final idPaciente = Sessao.fromToken(widget.tokenJwt).idPaciente;
    if (idPaciente == null) {
      _carregarNotificacoes();
      return;
    }

    final atualizadas = {..._dispensadas, notificacao.id};
    try {
      await _armazenamento.salvarNotificacoesDispensadas(
        idPaciente,
        atualizadas,
      );
      if (mounted) setState(() => _dispensadas.add(notificacao.id));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível dispensar a notificação.'),
        ),
      );
      _carregarNotificacoes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Notificações'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: FutureBuilder<List<Notificacao>>(
        future: _futureNotificacoes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Nenhuma notificação encontrada.'));
          }

          final notificacoes = snapshot.data!
              .where((item) => !_dispensadas.contains(item.id))
              .toList();
          if (notificacoes.isEmpty) {
            return Center(child: Text('Nenhuma notificação encontrada.'));
          }

          return ListView.separated(
            itemCount: notificacoes.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            itemBuilder: (context, index) {
              final item = notificacoes[index];
              final titulo = item.titulo?.trim() ?? '';
              final mensagem = item.mensagem.trim();
              final textoTitulo = titulo.isNotEmpty
                  ? titulo
                  : mensagem.isNotEmpty
                  ? mensagem
                  : 'Notificação';
              final detalhes = <Widget>[
                if (titulo.isNotEmpty && mensagem.isNotEmpty) Text(mensagem),
                if (item.dataEnvio.isNotEmpty)
                  Text('Enviado em: ${item.dataEnvio}'),
              ];

              return Dismissible(
                key: ValueKey('notificacao-${item.id}'),
                direction: DismissDirection.horizontal,
                background: _fundoDispensar(alignment: Alignment.centerLeft),
                secondaryBackground: _fundoDispensar(
                  alignment: Alignment.centerRight,
                ),
                onDismissed: (_) => _dispensar(item),
                child: Container(
                  key: ValueKey('notificacao-container-${item.id}'),
                  color: item.lida
                      ? scheme.onSurface.withValues(alpha: 0.04)
                      : null,
                  child: ListTile(
                    leading: Icon(
                      item.lida
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: item.lida ? Colors.grey : Colors.blue,
                    ),
                    title: Text(textoTitulo),
                    subtitle: detalhes.isEmpty
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: detalhes,
                          ),
                    trailing: !item.lida
                        ? IconButton(
                            icon: Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              bool sucesso = await _service.marcarComoLida(
                                item.id,
                                widget.tokenJwt,
                              );
                              if (sucesso) _carregarNotificacoes();
                            },
                          )
                        : null,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _fundoDispensar({required Alignment alignment}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: scheme.secondary,
      child: Icon(Icons.archive_outlined, color: scheme.onSecondary),
    );
  }
}
