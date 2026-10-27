import 'package:flutter/material.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/core/utils/datas.dart';

/// Cartão de uma consulta (médico, clínica, hora e dia).
class AgendamentoCard extends StatelessWidget {
  final AgendamentoDetalhado consulta;

  const AgendamentoCard({super.key, required this.consulta});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;
    final data = consulta.data;
    final cardId = consulta.agendamento.idAgendamento;
    final atrasada = consulta.ativo && data.isBefore(DateTime.now());

    return Container(
      key: ValueKey('agendamento-card-$cardId'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 110),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 110),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 33,
                        backgroundColor: onPrimary,
                        child: const Icon(
                          Icons.person_outline,
                          size: 45,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: consulta.medico,
                                    style: TextStyle(
                                      color: onPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (consulta.especialidade.isNotEmpty)
                                    TextSpan(
                                      text: ' - ${consulta.especialidade}',
                                      style: TextStyle(
                                        color: onPrimary,
                                        fontSize: 15,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              consulta.clinica,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: onPrimary,
                                fontSize: 14,
                              ),
                            ),
                            if (atrasada) ...[
                              const SizedBox(height: 8),
                              Container(
                                key: ValueKey('agendamento-atrasado-$cardId'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: scheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Atrasada - atendimento não concluído',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.onErrorContainer,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                key: ValueKey('agendamento-card-divider-$cardId'),
                width: 1.5,
                color: onPrimary,
              ),
              SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatarHora(data),
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${data.day} ${abreviacaoMes(data.month)}',
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}