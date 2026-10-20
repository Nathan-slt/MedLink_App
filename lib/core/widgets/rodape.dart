import 'package:flutter/material.dart';

/// Barra de navegação inferior.
///
/// Não navega por conta própria: avisa a tela pai via [onTap]. Tocar na aba
/// que já está selecionada é ignorado, então a tela atual não é recarregada.
class Rodape extends StatelessWidget {
  final int currentIndex;
  final bool usuarioNaFila;
  final ValueChanged<int> onTap;

  const Rodape({
    super.key,
    required this.currentIndex,
    this.usuarioNaFila = false,
    required this.onTap,
  });

  void _select(int index) {
    if (index == currentIndex) return;
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 60,
      color: Theme.of(context).colorScheme.primary,
      child: Row(
        children: [
          _RodapeItem(
            label: 'Início',
            icon: Icons.home,
            selected: currentIndex == 0,
            onTap: () => _select(0),
          ),
          _RodapeItem(
            label: 'Histórico',
            icon: Icons.history_outlined,
            selected: currentIndex == 1,
            onTap: () => _select(1),
          ),
          // Espaço para o botão flutuante "Criar agendamento".
          const SizedBox(width: 20),
          _RodapeItem(
            label: usuarioNaFila ? 'Fila, você está na fila' : 'Fila',
            text: 'PXX',
            selected: currentIndex == 2,
            showQueueStatus: usuarioNaFila,
            onTap: () => _select(2),
          ),
          _RodapeItem(
            label: 'Perfil',
            icon: Icons.account_circle_outlined,
            selected: currentIndex == 3,
            onTap: () => _select(3),
          ),
        ],
      ),
    );
  }
}

class _RodapeItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? text;
  final bool selected;
  final bool showQueueStatus;
  final VoidCallback onTap;

  const _RodapeItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showQueueStatus = false,
    this.icon,
    this.text,
  }) : assert(icon != null || text != null);

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? onPrimary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (icon != null)
                      Icon(
                        icon,
                        color: onPrimary,
                        size: selected ? 31 : 27,
                      )
                    else
                      Text(
                        text!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: onPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: selected
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: onPrimary,
                          decorationThickness: 2,
                        ),
                      ),
                    if (text == 'PXX')
                      Positioned(
                        top: -5,
                        right: -5,
                        child: AnimatedScale(
                          scale: showQueueStatus ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: AnimatedOpacity(
                            opacity: showQueueStatus ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.tertiary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: onPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: Icon(
                                  Icons.done,
                                  size: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onTertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
