import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:projeto_final/core/network/api_client.dart';

@pragma('vm:entry-point')
Future<void> tratarMensagemEmSegundoPlano(RemoteMessage _) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _canalId = 'medlink_alertas';
  static const _canalNome = 'Alertas do MedLink';

  static bool get suportaPush =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  final FirebaseMessaging _mensageria = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificacoesLocais =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;
  VoidCallback? _aoAbrirNotificacao;
  RemoteMessage? _mensagemInicial;
  StreamSubscription<RemoteMessage>? _mensagensSubscription;
  StreamSubscription<RemoteMessage>? _aberturaSubscription;
  StreamSubscription<String>? _tokenSubscription;

  Future<void> inicializar({required VoidCallback aoAbrirNotificacao}) async {
    if (!suportaPush || _inicializado) return;

    _aoAbrirNotificacao = aoAbrirNotificacao;
    await _notificacoesLocais.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _aoAbrirNotificacao?.call(),
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _notificacoesLocais
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _canalId,
              _canalNome,
              description: 'Lembretes e atualizações de consultas.',
              importance: Importance.high,
            ),
          );
    } else {
      await _mensageria.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    _mensagensSubscription = FirebaseMessaging.onMessage.listen(
      _mostrarMensagemEmPrimeiroPlano,
    );
    _aberturaSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (_) => _aoAbrirNotificacao?.call(),
    );
    _mensagemInicial = await _mensageria.getInitialMessage();
    _tokenSubscription = _mensageria.onTokenRefresh.listen(
      _sincronizarTokenAtualizado,
    );
    _inicializado = true;
  }

  void abrirNotificacaoInicialSeNecessario() {
    if (_mensagemInicial == null) return;

    _mensagemInicial = null;
    _aoAbrirNotificacao?.call();
  }

  Future<void> registrarDispositivo() async {
    if (!suportaPush) return;

    final permissao = await _mensageria.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (permissao.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _mensageria.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('O Firebase não retornou o token deste dispositivo.');
    }

    await _enviarToken(token);
  }

  Future<void> removerDispositivo() async {
    if (!suportaPush || !_inicializado || ApiClient.instance.token == null) {
      return;
    }

    final token = await _mensageria.getToken();
    if (token == null || token.isEmpty) return;

    await ApiClient.instance.delete(
      '/notificacoes/dispositivos',
      corpo: {'token': token},
      tratarSessaoExpirada: false,
    );
  }

  Future<void> _sincronizarTokenAtualizado(String token) async {
    if (ApiClient.instance.token == null) return;

    try {
      await _enviarToken(token);
    } catch (erro, stackTrace) {
      debugPrint('Falha ao atualizar o token de push no servidor: $erro');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _enviarToken(String token) async {
    final plataforma = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => throw UnsupportedError('Plataforma sem suporte a push.'),
    };

    await ApiClient.instance.post(
      '/notificacoes/dispositivos',
      corpo: {'token': token, 'plataforma': plataforma},
    );
  }

  Future<void> _mostrarMensagemEmPrimeiroPlano(RemoteMessage mensagem) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final notificacao = mensagem.notification;
    if (notificacao == null) return;

    await _notificacoesLocais.show(
      id: mensagem.messageId?.hashCode ?? mensagem.hashCode,
      title: notificacao.title ?? 'MedLink',
      body: notificacao.body ?? 'Você recebeu uma notificação.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          _canalNome,
          channelDescription: 'Lembretes e atualizações de consultas.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: mensagem.data['idNotificacao']?.toString(),
    );
  }

  Future<void> dispose() async {
    await _mensagensSubscription?.cancel();
    await _aberturaSubscription?.cancel();
    await _tokenSubscription?.cancel();
    _inicializado = false;
  }
}
