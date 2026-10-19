# 🎥 Live Stream Site

Página web para mostrar directos de YouTube en GitHub Pages, con panel de administración local.

## Archivos

| Archivo | Descripción |
|---|---|
| `index.html` | Web pública (GitHub Pages) — muestra el directo o pantalla de espera |
| `admin.html` | Panel local — para activar/desactivar el directo |
| `config.json` | Configuración — indica si hay directo activo y el ID del vídeo |

## Cómo usarlo

### 1. Subir a GitHub
1. Crea un repositorio en GitHub (puede ser público o privado)
2. Sube los tres archivos (`index.html`, `admin.html`, `config.json`)
3. Ve a **Settings → Pages** y activa GitHub Pages desde la rama `main`

### 2. Configurar el panel admin
Abre `admin.html` en tu navegador (doble clic) y rellena:
- Tu usuario de GitHub
- Nombre del repositorio
- Token personal con permisos de escritura

#### Crear el token:
1. Ve a https://github.com/settings/tokens/new
2. Nombre: `live-stream-admin`
3. Expiration: la que quieras
4. Scope: activa **`repo`** (o solo `public_repo` si el repo es público)
5. Click "Generate token" y cópialo

### 3. Cada día de directo
1. Abre `admin.html` en tu navegador
2. Pega el enlace del directo de YouTube
3. Pulsa **▶ Activar directo**
4. La web pública se actualiza automáticamente en ~30 segundos

### 4. Cuando termina el directo
1. En `admin.html`, pulsa **⏹ Terminar directo**
2. La web mostrará "No hay directo disponible"

## Personalización de index.html

Edita estas líneas en `index.html` para personalizar el nombre:
```html
<div class="logo">🎥 Mi <span>Canal</span></div>
```
