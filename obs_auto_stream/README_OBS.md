# 🎥 Pan Bendito — Monitor Automático de Directo para OBS

Aplicación nativa e independiente para Windows diseñada específicamente para la retransmisión de cultos con **OBS Studio** de la **Iglesia Evangélica Pan Bendito**.

---

## 🚀 ¿Cómo Funciona?

1. **Lectura Inteligente del Fichero**:
   - Monitorea continuamente el archivo de texto generado por OBS (por defecto `directo_obs.txt` o cualquier ruta que configures con el botón **"Examinar..."**).
   - El archivo puede contener la URL completa de YouTube (ej: `https://www.youtube.com/watch?v=1Qm3vRe8iJg`, `https://youtu.be/...`, `https://youtube.com/live/...`) o simplemente el ID del vídeo (11 caracteres).

2. **Inicio Automático del Directo**:
   - En cuanto OBS (o el operador) escribe la URL en el archivo:
     - 🔴 La app detecta el enlace automáticamente.
     - 📡 Envía la notificación Push en tiempo real a todos los móviles con la app instalada (**"🔴 ¡Estamos EN DIRECTO!"**).
     - 💾 Actualiza `config.json` en GitHub automáticamente.
     - 📱 La web y la app de Android pasan de inmediato a modo retransmisión con el reproductor activo.

3. **Fin Automático y Guardado como "Culto Anterior"**:
   - Cuando el directo termina en OBS y la URL se elimina del archivo (o el archivo se borra o se vacía):
     - ⏱ La app activa una cuenta atrás de seguridad (por defecto 5 segundos) para asegurar que la emisión ha concluido.
     - ⏹ Pone la app y la web en modo **"Sin directo"** (pantalla de espera).
     - 💾 **Guarda el enlace de este culto que acaba de terminar como "Culto Anterior"**. En la app de Android y en la web, el botón **"Ver culto anterior"** ahora reproducirá automáticamente este culto.
     - 📡 Envía la notificación Push de fin de culto (**"⏹ Culto finalizado"**).

4. **100% Independiente**:
   - No modifica el código de la web ni de la app de Android.
   - Trabaja de forma transparente mediante la misma infraestructura en la nube (GitHub API + ntfy push servers).

---

## 🖥️ Cómo Abrir la Aplicación

Tienes 3 formas sencillas de abrirla:

1. **Desde el Escritorio de Windows**:
   - Haz doble clic en el acceso directo **"Pan Bendito AutoStream OBS"**.
2. **Con el lanzador silencioso (sin ventana negra de CMD)**:
   - Haz doble clic en `Iniciar_AutoStream_Silencioso.vbs`.
3. **Con el archivo por lotes tradicional**:
   - Haz doble clic en `Iniciar_AutoStream.bat`.

> **Nota:** Al minimizar la ventana, se ocultará en la **bandeja del sistema (junto al reloj)** para no estorbar durante el culto mientras usas OBS. Al hacer doble clic en el icono junto al reloj, la ventana volverá a abrirse.

---

## 🧪 Cómo Probarlo en 1 Minuto

1. Abre la aplicación.
2. Pulsa en el botón **"📝 Abrir Fichero"**. Se abrirá el archivo en el Bloc de Notas.
3. Pega una URL de YouTube (ejemplo: `https://www.youtube.com/watch?v=1Qm3vRe8iJg`) y guarda el archivo (**Ctrl + G**).
   - Observarás que en 1 segundo la app pasa a **🔴 ¡EN DIRECTO!**, envía la notificación y actualiza la web.
4. Ahora borra el texto en el Bloc de Notas (déjalo vacío) y vuelve a guardar (**Ctrl + G**).
   - Observarás la cuenta atrás: *"Finalizando directo en 5s..."*.
   - Al finalizar, pasa a **⚪ SIN DIRECTO** y ese vídeo queda guardado como **Culto Anterior**.

---

## ⚙️ Generación Automática desde OBS Studio

Para que OBS escriba la URL automáticamente al pulsar **"Iniciar transmisión"**, puedes usar cualquiera de estos métodos habituales:

### Opción A (Recomendada con OBS - Script Lua o Python):
En OBS Studio ve a **Herramientas → Scripts**, añade un script que en el evento `obs.OBS_FRONTEND_EVENT_STREAMING_STARTED` escriba la URL en `directo_obs.txt`, y en `obs.OBS_FRONTEND_EVENT_STREAMING_STOPPED` vacíe el archivo.

### Opción B (Con Advanced Scene Switcher o archivo de texto):
Configura una macro o acción que escriba la URL al iniciar streaming y la borre al terminar.

### Opción C (Sencilla y directa):
El encargado de medios de la iglesia simplemente pega la URL en `directo_obs.txt` (o en el campo **URL Manual** de la app y pulsa **"🔴 Forzar Inicio"**), y al terminar el culto simplemente vacía el archivo o pulsa **"⏹ Forzar Fin"**.
