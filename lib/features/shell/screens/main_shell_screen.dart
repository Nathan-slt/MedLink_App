import 'package:flutter/material.dart';
import 'package:projeto_final/core/widgets/rodape.dart';
import 'package:projeto_final/features/fila/screens/fila_screen.dart';
import 'package:projeto_final/features/historico/screens/historico_screen.dart';
import 'package:projeto_final/features/home/screens/home_screen.dart';
import 'package:projeto_final/features/home/widgets/criar_agendamento.dart';
import 'package:projeto_final/features/perfil/screens/perfil_screen.dart';
import 'package:projeto_final/services/agendamento_service.dart';

/// Casca da área logada: mantém o [Rodape] fixo e troca só o conteúdo.
///
/// As abas ficam num [IndexedStack], então cada uma preserva seu estado
/// (calendário, rolagem, campos do perfil...) ao alternar, e tocar na aba
/// atual não reconstrói nada.
class MainShellScreen extends StatefulWidget {
  final int initialIndex;

  const MainShellScreen({super.key, this.initialIndex = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  // Ordem precisa bater com os índices do Rodape.
  late int _currentIndex = widget.initialIndex;
  bool _usuarioNaFila = false;
  bool _estaSendoChamado = false;
  bool _estaEmAtendimento = false;

  void _selecionarAba(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Botão "voltar" do Android: em qualquer aba que não seja a Home, volta
    // para a Home em vez de fechar o app.
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _selecionarAba(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const HomeScreen(), // 0
            const HistoricoScreen(), // 1
            FilaScreen(
              isActive: _currentIndex == 2,
              keepPolling: true,
              onQueueStatusChanged: (naFila) {
                if (_usuarioNaFila != naFila) {
                  setState(() => _usuarioNaFila = naFila);
                }
              },
              onCalledStatusChanged: (chamado) {
                if (_estaSendoChamado != chamado ||
                    (chamado && _currentIndex != 2)) {
                  setState(() {
                    _estaSendoChamado = chamado;
                    if (chamado) _currentIndex = 2;
                  });
                }
              },
              onInServiceStatusChanged: (emAtendimento) {
                if (_estaEmAtendimento != emAtendimento ||
                    (emAtendimento && _currentIndex != 2)) {
                  setState(() {
                    _estaEmAtendimento = emAtendimento;
                    if (emAtendimento) _currentIndex = 2;
                  });
                }
              },
              onConsultationCompleted: () {
                AgendamentoService.notificarAlteracao();
                setState(() {
                  _usuarioNaFila = false;
                  _estaSendoChamado = false;
                  _estaEmAtendimento = false;
                  if (_currentIndex == 2) _currentIndex = 0;
                });
              },
            ), // 2
            const PerfilScreen(), // 3
          ],
        ),
        bottomNavigationBar: _currentIndex == 2 && _estaSendoChamado
            ? null
            : Rodape(
                currentIndex: _currentIndex,
                usuarioNaFila: _usuarioNaFila,
                onTap: _selecionarAba,
              ),
        // O botão de criar agendamento só aparece na Home (como antes).
        floatingActionButton: _currentIndex == 0
            ? const AppFloatingActionButton()
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}
