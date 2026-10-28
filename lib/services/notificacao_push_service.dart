import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:projeto_final/core/network/api_client.dart';

@pragma('vm:entry-point')
Future<void> tratarMensagemEmSegundoPlano(RemoteMessage mensagem) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();

  // Mensagens com bloco `notification` são exibidas pelo próprio sistema
  // quando o app está em segundo plano ou encerrado. Aqui tratamos somente
  // mensagens data-only para não duplicar o alerta do sistema.
  if (mensagem.notification != null) return;

  final titulo = _textoNaoVazio(
    mensagem.data['titulo'] ?? mensagem.data['title'],
    fallback: 'MedLink',
  );
  final corpo = _textoNaoVazio(
    mensagem.data['mensagem'] ?? mensagem.data['body'],
    fallback: 'Você recebeu uma notificação.',
  );
  final plugin = FlutterLocalNotificationsPlugin();
  await _inicializarNotificacoesLocais(plugin);
  await _mostrarNotificacaoLocal(
    plugin,
    id: mensagem.messageId?.hashCode ?? mensagem.hashCode,
    title: titulo,
    body: corpo,
    payload: mensagem.data['idNotificacao']?.toString(),
  );
}

String _textoNaoVazio(Object? valor, {required String fallback}) {
  final texto = valor?.toString().trim() ?? '';
  return texto.isEmpty ? fallback : texto;
}

const _canalId = 'medlink_alertas';
const _canalNome = 'Alertas do MedLink';
const _descricaoCanal = 'Lembretes e atualizações de consultas.';

Future<void> _inicializarNotificacoesLocais(
  FlutterLocalNotificationsPlugin plugin,
) async {
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
  await _criarCanalAndroid(plugin);
}

Future<void> _criarCanalAndroid(FlutterLocalNotificationsPlugin plugin) async {
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _canalId,
          _canalNome,
          description: _descricaoCanal,
          importance: Importance.high,
        ),
      );
}

Future<void> _mostrarNotificacaoLocal(
  FlutterLocalNotificationsPlugin plugin, {
  required int id,
  required String title,
  required String body,
  String? payload,
}) {
  return plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _canalId,
        _canalNome,
        channelDescription: _descricaoCanal,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: payload,
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static bool get suportaPush =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  final FirebaseMessaging _mensageria = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificacoesLocais =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;
  bool _notificacaoLocalInicial = false;
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
    final detalhesInicializacao = await _notificacoesLocais
        .getNotificationAppLaunchDetails();
    _notificacaoLocalInicial =
        detalhesInicializacao?.didNotificationLaunchApp ?? false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      await _criarCanalAndroid(_notificacoesLocais);
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
    if (_mensagemInicial == null && !_notificacaoLocalInicial) return;

    _mensagemInicial = null;
    _notificacaoLocalInicial = false;
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

    final title = _textoNaoVazio(
      mensagem.notification?.title ??
          mensagem.data['titulo'] ??
          mensagem.data['title'],
      fallback: 'MedLink',
    );
    final body = _textoNaoVazio(
      mensagem.notification?.body ??
          mensagem.data['mensagem'] ??
          mensagem.data['body'],
      fallback: 'Você recebeu uma notificação.',
    );

    await _mostrarNotificacaoLocal(
      _notificacoesLocais,
      id: mensagem.messageId?.hashCode ?? mensagem.hashCode,
      title: title,
      body: body,
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
