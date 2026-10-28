class Notificacao {
  final int id;
  final int idAgendamento;
  final String tipo;
  final String? titulo;
  final String mensagem;
  final bool lida;
  final String dataEnvio;

  Notificacao({
    required this.id,
    required this.idAgendamento,
    required this.tipo,
    this.titulo,
    required this.mensagem,
    required this.lida,
    required this.dataEnvio,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    final id = json['id_notificacao'] ?? json['id'];
    final idAgendamento = json['id_agendamento'];
    final tipo = json['tipo'];
    final titulo = json['titulo'];
    final mensagem = json['mensagem'];
    final lida = json['lida'];
    final dataEnvio = json['data_envio'];
    if (id is! int ||
        idAgendamento is! int ||
        (tipo != null && tipo is! String) ||
        (titulo != null && titulo is! String) ||
        (mensagem != null && mensagem is! String) ||
        (lida != null && lida is! bool) ||
        (dataEnvio != null && dataEnvio is! String)) {
      throw const FormatException('Notificação inválida.');
    }

    return Notificacao(
      id: id,
      idAgendamento: idAgendamento,
      tipo: tipo as String? ?? '',
      titulo: titulo as String?,
      mensagem: mensagem as String? ?? '',
      lida: lida as bool? ?? false,
      dataEnvio: dataEnvio as String? ?? '',
    );
  }
}
