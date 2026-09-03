# Passo a passo rápido (Windows / Mac / Linux)

## 1. Instalar Flutter

https://docs.flutter.dev/get-started/install

## 2. Gerar pastas Android

Dentro da pasta `assistify_flutter`:

```bash
flutter create . --project-name assistify --org com.assistify
flutter pub get
```

Isso cria a pasta `android/` automaticamente **sem apagar** o código em `lib/`.

## 3. Permissões de internet (Android)

Abra `android/app/src/main/AndroidManifest.xml` e confira se existe:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

E dentro de `<application>`:

```xml
android:usesCleartextTraffic="true"
```

(necessário para painéis `http://`)

## 4. Build do APK

```bash
flutter build apk --release
```

APK final:

`build/app/outputs/flutter-apk/app-release.apk`

## Login

- **Servidor:** só a URL base, ex: `http://telaplay.lat`
- **Usuário** e **Senha** do painel
