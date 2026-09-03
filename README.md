# Assistify IPTV

App **novo, do zero**, estilo Netflix (preto + roxo) com login de painel **Xtream Codes** (usuário + senha).

## O que tem

- Tela de login (servidor + usuário + senha)
- Ao Vivo / Filmes / Séries / Favoritos
- Categorias do painel
- Busca
- Player nativo (media_kit / ExoPlayer)
- Tema Assistify (`#9B4DFF` + preto)
- Logos inclusas

## Como gerar o APK no seu computador

### 1. Instalar Flutter (uma vez)

- Site: https://docs.flutter.dev/get-started/install
- Windows / macOS / Linux

Depois confira:

```bash
flutter doctor
```

### 2. Abrir o projeto

```bash
cd assistify_flutter
flutter pub get
```

### 3. Gerar APK instalável

```bash
flutter build apk --release
```

O arquivo sai em:

```
build/app/outputs/flutter-apk/app-release.apk
```

Esse `.apk` você manda para o celular e instala.

### 4. (Opcional) Ícone do app

```bash
dart run flutter_launcher_icons
```

## Login no app

No campo **Servidor**, use a URL base do painel, por exemplo:

```
http://telaplay.lat
```

**Não** precisa colar o `get.php?...`  
Só o domínio + usuário + senha (igual no app antigo).

## Estrutura

```
lib/
  main.dart
  theme/app_theme.dart
  models/models.dart
  services/
    xtream_service.dart   ← API do painel
    storage_service.dart
  screens/
    login_screen.dart
    home_screen.dart
    player_screen.dart
assets/
  logo-icon.png
  logo-full.png
```

## Não quer instalar Flutter?

Use um serviço online gratuito que compila por você:

1. Suba este projeto no **GitHub** (repositório privado ou público)
2. Entre em https://codemagic.io
3. Conecte o repositório e rode o build Android
4. Baixe o APK pronto

---

Assistify IPTV v1.0 — feito do zero, estilo Netflix.
