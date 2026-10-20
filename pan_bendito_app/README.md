# 📱 Iglesia de Pan Bendito — App Móvil (Android & iOS)

Aplicación móvil nativa en **Flutter** para la **Iglesia de Pan Bendito**. Muestra las transmisiones en directo de YouTube y permite emitir el contenido fácilmente a televisores (Chromecast, Amazon Fire TV Stick, Smart TV y AirPlay).

---

## ✨ Características

- 🎥 **Reproductor de Directo Nativo**: Integración con YouTube con soporte para pantalla completa, calidad adaptativa y controles táctiles.
- 📺 **Botón Transmitir a la TV**:
  - **Amazon Fire TV Stick / Chromecast / AirPlay**: Apertura directa en la app de YouTube del móvil para emitir a la televisión con 1 toque.
  - **Smart TV (Samsung, LG, etc.)**: Enlace directo a `youtube.com/pair` para vincular con código de TV.
- ⚡ **Actualización Instantánea en Tiempo Real**:
  - Conectada al mismo canal SSE (`ntfy.sh`) y a la API de GitHub que la web.
  - Cuando el administrador pulsa **▶ Activar directo** o **⏹ Terminar directo** en `admin.html`, la app móvil cambia en menos de 0.1 segundos automáticamente sin que el usuario tenga que recargar.
- 🎨 **Diseño adaptado a la identidad**: Paleta azul marino (`#1A2740`) y plateado (`#C8D4E8`) con el logo oficial.

---

## 🚀 Compilación y Descarga Automática (GitHub Actions)

El proyecto incluye un flujo de trabajo en `.github/workflows/build-app.yml` que compila la aplicación automáticamente en la nube de GitHub sin necesidad de configurar entornos locales complejos:

1. **Android**: Genera el archivo instalable **`PanBendito-Android-APK`** (`app-release.apk`).
2. **iOS**: Compila la versión para iPhone/iPad en servidores macOS de GitHub.

### Para descargar el APK:
1. Ve a tu repositorio en GitHub > pestaña **Actions**.
2. Selecciona la ejecución de **Compilar App Android e iOS**.
3. En la sección **Artifacts**, descarga el archivo `PanBendito-Android-APK` e instálalo directamente en cualquier teléfono o tablet Android.

---

## 💻 Ejecución local (con Flutter SDK)

Si tienes Flutter instalado en tu equipo:

```bash
cd pan_bendito_app
flutter pub get
flutter run
```

Para generar el APK de producción:
```bash
flutter build apk --release
```
