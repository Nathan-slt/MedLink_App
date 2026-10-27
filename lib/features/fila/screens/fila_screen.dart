import 'dart:async';

import 'package:flutter/material.dart';
import 'package:projeto_final/core/models/fila_posicao.dart';
import 'package:projeto_final/core/network/api_exception.dart';
import 'package:projeto_final/core/widgets/app_bar.dart';
import 'package:projeto_final/services/fila_service.dart';

/// Aba "Fila". O rodapé fica no [MainShellScreen].
class FilaScreen extends StatefulWidget {
  final bool isActive;
  final bool keepPolling;
  final FilaService service;
  final ValueChanged<bool>? onQueueStatusChanged;
  final ValueChanged<bool>? onCalledStatusChanged;
  final ValueChanged<bool>? onInServiceStatusChanged;
  final VoidCallback? onConsultationCompleted;

  FilaScreen({
    super.key,
    required this.isActive,
    this.keepPolling = false,
    FilaService? service,
    this.onQueueStatusChanged,
    this.onCalledStatusChanged,
    this.onInServiceStatusChanged,
    this.onConsultationCompleted,
  }) : service = service ?? FilaService.instance;

  @override
  State<FilaScreen> createState() => _FilaScreenState();
}

class _FilaScreenState extends State<FilaScreen> {
  static const _intervaloAtualizacao = Duration(seconds: 1);
  static const _duracaoChamada = Duration(seconds: 40);

  Timer? _timer;
  Timer? _timerChamada;
  FilaPosicao? _fila;
  String? _erro;
  bool _consultando = false;
  bool _carregando = true;
  bool _entradaConfirmada = false;
  bool _conclusaoNotificada = false;
  Duration _tempoChamadaRestante = _duracaoChamada;

  bool get _deveConsultar => widget.isActive || widget.keepPolling;

  String? _normalizarStatus(String? status) =>
      status
        ?.trim()
        .toLowerCase()
        .replaceAll(RegExp('[áàâãä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll(RegExp(r'[\s-]+'), '_');

  bool get _estaSendoChamado {
    final status = _normalizarStatus(_fila?.status);
    return status == 'chamando' || status == 'chamado';
  }

  bool get _estaEmAtendimento {
    final status = _normalizarStatus(_fila?.status);
    return status == 'em_atendimento' || status == 'atendendo';
  }

  bool _estaFinalizado(String? status) {
    return switch (_normalizarStatus(status)) {
      'finalizado' ||
      'finalizada' ||
      'realizado' ||
      'realizada' ||
      'atendido' ||
      'atendida' ||
      'concluido' ||
      'concluida' => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    if (_deveConsultar) _iniciarAtualizacao();
  }

  @override
  void didUpdateWidget(covariant FilaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final estavaConsultando = oldWidget.isActive || oldWidget.keepPolling;
    if (estavaConsultando == _deveConsultar) return;

    if (_deveConsultar) {
      _iniciarAtualizacao();
    } else {
      _pararAtualizacao();
    }
  }

  @override
  void dispose() {
    _pararAtualizacao();
    _pararContagemChamada();
    super.dispose();
  }

  void _iniciarAtualizacao() {
    _pararAtualizacao();
    _consultar();
    _timer = Timer.periodic(_intervaloAtualizacao, (_) => _consultar());
  }

  void _pararAtualizacao() {
    _timer?.cancel();
    _timer = null;
  }

  void _iniciarContagemChamada() {
    if (_timerChamada != null || _entradaConfirmada) return;
    _tempoChamadaRestante = _duracaoChamada;
    _timerChamada = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_tempoChamadaRestante <= const Duration(seconds: 1)) {
        timer.cancel();
        _timerChamada = null;
        setState(() {
          _tempoChamadaRestante = Duration.zero;
          _entradaConfirmada = true;
        });
        return;
      }
      setState(() {
        _tempoChamadaRestante -= const Duration(seconds: 1);
      });
    });
  }

  void _pararContagemChamada() {
    _timerChamada?.cancel();
    _timerChamada = null;
    _tempoChamadaRestante = _duracaoChamada;
  }

  Future<void> _consultar() async {
    if (_consultando || !mounted || !_deveConsultar) return;
    _consultando = true;
    try {
      final resposta = await widget.service.minhaPosicao();
      if (!mounted) return;
      final estavaNaFila = _fila != null;
      final estavaSendoChamado = _estaSendoChamado;
      final estavaEmAtendimento = _estaEmAtendimento;
      final estavaComEntradaConfirmada = _entradaConfirmada;
      final finalizado = _estaFinalizado(resposta?.status);
      final fila = finalizado ? null : resposta;
      final consultaConcluida =
          finalizado ||
          (resposta == null &&
              (estavaEmAtendimento || estavaComEntradaConfirmada));
      final notificarConclusao =
          consultaConcluida && !_conclusaoNotificada;
      final aguardandoEntrada =
          fila != null &&
          (_normalizarStatus(fila.status) == 'chamando' ||
              _normalizarStatus(fila.status) == 'chamado' ||
              _normalizarStatus(fila.status) == 'em_atendimento' ||
              _normalizarStatus(fila.status) == 'atendendo');
      setState(() {
        _fila = fila;
        _erro = null;
        _carregando = false;
        if (!aguardandoEntrada && !_entradaConfirmada) {
          _pararContagemChamada();
        }
        if (fila == null) _entradaConfirmada = false;
        _conclusaoNotificada = fila == null
            ? _conclusaoNotificada || consultaConcluida
            : false;
      });
      if (aguardandoEntrada && !_entradaConfirmada) {
        _iniciarContagemChamada();
      }
      if (estavaNaFila != (fila != null)) {
        widget.onQueueStatusChanged?.call(fila != null);
      }
      if (estavaSendoChamado != _estaSendoChamado) {
        widget.onCalledStatusChanged?.call(_estaSendoChamado);
      }
      if (estavaEmAtendimento != _estaEmAtendimento) {
        widget.onInServiceStatusChanged?.call(_estaEmAtendimento);
      }
      if (notificarConclusao) {
        widget.onConsultationCompleted?.call();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } finally {
      _consultando = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = (screenWidth * 0.045).clamp(16.0, 32.0);
    final chamado =
        !_carregando &&
        !_entradaConfirmada &&
        (_estaSendoChamado || _estaEmAtendimento);
    final emAtendimento = !_carregando && _entradaConfirmada;

    return Scaffold(
      backgroundColor: chamado || emAtendimento
          ? Theme.of(context).colorScheme.primary
          : null,
      appBar: chamado || emAtendimento ? null : const AppBarWidget(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: emAtendimento
                ? _buildEmAtendimento(context, _fila!)
                : chamado
                ? _buildChamado(context, _fila!)
                : _carregando
                ? TickerMode(
                    enabled: widget.isActive,
                    child: const Center(child: CircularProgressIndicator()),
                  )
                : _erro != null && _fila == null
                ? _buildErro(context)
                : _fila == null
                ? _buildSemCheckin(context)
                : _buildFila(context, _fila!),
          ),
        ),
      ),
    );
  }

  Widget _buildChamado(BuildContext context, FilaPosicao fila) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;
    final codigoFontSize = (screenWidth * 0.17).clamp(54.0, 76.0);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CHAMANDO PACIENTE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.inversePrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fila.profissional,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fila.especialidade,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: (screenWidth - 48).clamp(220.0, 360.0),
                constraints: const BoxConstraints(minHeight: 108),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fila.codigoAtendimento,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: codigoFontSize,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: (screenWidth - 64).clamp(220.0, 360.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      key: const ValueKey('chamada-progress'),
                      value:
                          _tempoChamadaRestante.inMilliseconds /
                          _duracaoChamada.inMilliseconds,
                      minHeight: 8,
                      backgroundColor: scheme.onPrimary.withValues(alpha: 0.3),
                      color: scheme.inversePrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Iniciando atendimento em '
                      '${_tempoChamadaRestante.inSeconds}s',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmAtendimento(BuildContext context, FilaPosicao fila) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 52,
                color: scheme.inversePrimary,
              ),
              const SizedBox(height: 20),
              Text(
                'Em atendimento',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${fila.profissional}\n${fila.especialidade}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErro(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_erro!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _consultar,
            child: const Text('Tentar novamente'),
          ),
          const SizedBox(height: 8),
          Icon(Icons.error_outline, color: scheme.error),
        ],
      ),
    );
  }

  Widget _buildSemCheckin(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 44, color: primary),
          const SizedBox(height: 16),
          Text(
            'Você ainda não está na fila.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A recepção precisa registrar seu check-in para você acompanhar a fila.',
            textAlign: TextAlign.center,
            style: TextStyle(color: primary),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(
              'Não foi possível atualizar: $_erro',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFila(BuildContext context, FilaPosicao fila) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;
    final boxWidth = (screenWidth * 0.65).clamp(220.0, 260.0);
    final boxHeight = (screenWidth * 0.31).clamp(115.0, 125.0);
    final mainFontSize = (screenWidth * 0.15).clamp(48.0, 60.0);
    final titleFontSize = (screenWidth * 0.04).clamp(14.0, 16.0);
    final statusFontSize = (screenWidth * 0.035).clamp(13.0, 14.0);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fila.profissional,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fila.especialidade,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.primary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Container(
              width: boxWidth,
              constraints: BoxConstraints(minHeight: boxHeight),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SEU IDENTIFICADOR',
                    style: TextStyle(
                      color: scheme.inversePrimary,
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    fila.codigoAtendimento,
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: mainFontSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: (screenWidth * 0.06).clamp(20.0, 25.0)),
            Text(
              'POSIÇÃO NA FILA',
              style: TextStyle(
                color: scheme.primary,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${fila.posicao}',
              style: TextStyle(
                color: scheme.primary,
                fontSize: mainFontSize,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            SizedBox(height: (screenWidth * 0.07).clamp(24.0, 30.0)),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: screenWidth - 32),
              padding: EdgeInsets.symmetric(
                horizontal: (screenWidth * 0.045).clamp(16.0, 18.0),
                vertical: (screenWidth * 0.025).clamp(8.0, 10.0),
              ),
              decoration: BoxDecoration(
                color: _erro == null
                    ? scheme.tertiaryContainer
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.circle,
                    color: _erro == null ? scheme.tertiary : scheme.error,
                    size: 6,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _erro == null
                          ? 'Fila em tempo real'
                          : 'Falha ao atualizar; tentando novamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _erro == null
                            ? scheme.onTertiaryContainer
                            : scheme.onErrorContainer,
                        fontSize: statusFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
