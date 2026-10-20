import 'package:flutter/material.dart';
import 'package:projeto_final/services/notificacao_service.dart';
import 'package:projeto_final/core/models/notificacoes.dart';

class TelaNotificacoes extends StatefulWidget {
  final String tokenJwt; // Passe o token do usuário logado para a tela

  const TelaNotificacoes({Key? key, required this.tokenJwt}) : super(key: key);

  @override
  _TelaNotificacoesState createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> {
  final NotificacaoService _service = NotificacaoService();
  late Future<List<Notificacao>> _futureNotificacoes;

  @override
  void initState() {
    super.initState();
    _carregarNotificacoes();
  }

  void _carregarNotificacoes() {
    setState(() {
      _futureNotificacoes = _service.listarMinhasNotificacoes(widget.tokenJwt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Minhas Notificações')),
      body: FutureBuilder<List<Notificacao>>(
        future: _futureNotificacoes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Nenhuma notificação encontrada.'));
          }

          final notificacoes = snapshot.data!;

          return ListView.builder(
            itemCount: notificacoes.length,
            itemBuilder: (context, index) {
              final item = notificacoes[index];
              return ListTile(
                leading: Icon(
                  item.lida ? Icons.notifications_none : Icons.notifications_active,
                  color: item.lida ? Colors.grey : Colors.blue,
                ),
                title: Text(item.mensagem),
                subtitle: Text('Enviado em: ${item.dataEnvio}'),
                trailing: !item.lida
                    ? IconButton(
                        icon: Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          bool sucesso = await _service.marcarComoLida(item.id, widget.tokenJwt);
                          if (sucesso) {
                            _carregarNotificacoes(); // Atualiza a lista após marcar como lida
                          }
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}