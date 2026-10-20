import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:projeto_final/app/navigation.dart';
import 'package:projeto_final/core/network/api_client.dart';
import 'package:projeto_final/services/notificacao_push_service.dart';

import 'app/app.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Mantém o splash nativo na tela até o splash do Flutter estar desenhado
  // (a remoção acontece em SplashScreen), evitando "piscar" entre os dois.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (PushNotificationService.suportaPush) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(tratarMensagemEmSegundoPlano);
    await PushNotificationService.instance.inicializar(
      aoAbrirNotificacao: AppNavigator.abrirNotificacoes,
    );
  }

  // Token vencido/inválido em qualquer requisição => volta ao login.
  ApiClient.instance.onSessaoExpirada = AppNavigator.sessaoExpirada;

  runApp(const MainApp());
}
