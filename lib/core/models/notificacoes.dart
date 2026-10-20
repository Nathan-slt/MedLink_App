class Notificacao {
  final int id;
  final int idAgendamento;
  final String tipo;
  final String mensagem;
  final bool lida;
  final String dataEnvio;

  Notificacao({
    required this.id,
    required this.idAgendamento,
    required this.tipo,
    required this.mensagem,
    required this.lida,
    required this.dataEnvio,
  });

  factory Notificacao.fromJson(Map<String, dynamic> json) {
    return Notificacao(
      id: json['id'],
      idAgendamento: json['id_agendamento'],
      tipo: json['tipo'] ?? '',
      mensagem: json['mensagem'] ?? '',
      lida: json['lida'] ?? false,
      dataEnvio: json['data_envio'] ?? '',
    );
  }
}