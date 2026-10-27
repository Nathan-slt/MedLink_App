import 'package:flutter/material.dart';
import 'package:projeto_final/features/historico/models/consulta.dart';

class ConsultaCard extends StatelessWidget {
  final Consulta consulta;
  final VoidCallback? onTap;

  const ConsultaCard({super.key, required this.consulta, this.onTap});

  static const _meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];

  String get _hora {
    final h = consulta.data.hour.toString().padLeft(2, '0');
    final m = consulta.data.minute.toString().padLeft(2, '0');
    return '$h:${m}h';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildInfo(scheme)),
              Container(
                width: 2,
                color: scheme.onPrimary.withValues(alpha: 0.6),
              ),
              SizedBox(width: 100, child: _buildData(scheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(ColorScheme scheme) {
    final cor = scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.onPrimary,
                backgroundImage: consulta.fotoUrl != null
                    ? NetworkImage(consulta.fotoUrl!)
                    : null,
                child: consulta.fotoUrl == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consulta.medico,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: cor,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                consulta.especialidade,
                                style: TextStyle(fontSize: 12, color: cor),
                              ),
                              Text(
                                consulta.tipoExame,
                                style: TextStyle(fontSize: 12, color: cor),
                              ),
                            ],
                          ),
                        ),
                        if (consulta.tipoLocal.isNotEmpty) _buildChip(scheme),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            consulta.clinica,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
          Text(consulta.endereco, style: TextStyle(fontSize: 12, color: cor)),
          if (consulta.atrasada) ...[
            const SizedBox(height: 8),
            Container(
              key: ValueKey('consulta-atrasada-${consulta.medico}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      'Atrasada - não realizada',
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
    );
  }

  Widget _buildChip(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        consulta.tipoLocal,
        style: TextStyle(fontSize: 11, color: scheme.secondary),
      ),
    );
  }

  Widget _buildData(ColorScheme scheme) {
    final cor = scheme.onPrimaryContainer;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          consulta.data.day.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: cor,
          ),
        ),
        Text(
          _meses[consulta.data.month - 1],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _hora,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: cor,
          ),
        ),
      ],
    );
  }
}
