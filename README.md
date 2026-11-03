# MedLink (app do paciente)

Sistema de gerenciamento de agendamentos e filas em clínicas.

## Rodando

```
flutter pub get
flutter run
```

A URL padrão usa HTTPS e também é usada pelo perfil `Flutter Web` em Run and
Debug. Para apontar para outra API, passe `API_URL` ao executar:

```
flutter run --dart-define=API_URL=http://10.0.2.2:3000/api   # emulador Android -> backend local
```

## Estrutura de rede/sessão

- `core/network/api_client.dart` — cliente HTTP único (token, erros, timeout).
- `services/auth_service.dart` — login, logout e restauração da sessão.
- `services/perfil_service.dart` — dados do perfil e troca de senha.
- `services/fila_service.dart` — posição autenticada do paciente em
  `/fila/minha-posicao`; a aba consulta a API a cada 5 segundos enquanto aberta.
  O histórico da fila finalizada é obtido por `/fila/historico` e associado aos
  agendamentos pelo `id_agendamento`.
- Se a API responder 401, o app encerra a sessão e volta ao login.
