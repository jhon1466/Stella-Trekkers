# Stella Trekkers

Aplicación Android nativa (Flutter) para jugadores de **Stella Sora**: base de datos completa del juego en español, calendario de eventos y gachas, rankings y un widget de energía para la pantalla de inicio vinculado a tu cuenta oficial.

Los datos del juego provienen de [StellaBase](https://stella.ennead.cc) y su diseño (colores, tipografías y estructura) sigue el de esa web.

## Funciones

### Base de datos
- **Trekkers**: ficha completa con ilustración, habilidades, potenciales, talentos, estadísticas por nivel, materiales de ascensión y mejora, trajes, citas y regalos favoritos.
- **Discos**: efectos principales y secundarios, estadísticas e ilustración.
- **Enemigos**, **Emblemas**, respuestas del **Monolito** y **Cumpleaños**.

### Calendario
- **Panel** con gachas destacados y cuenta atrás, eventos (en curso, próximos y archivo), tablón de noticias oficiales, modos de juego, próximos cumpleaños y calendario de gachas.
- Detalle de cada **evento** (recompensas, objetivos y tienda con precios) y de cada **noticia**.

### Combate
- **Joint Drill**: temporadas, dificultades, jefes, afijos, misiones, títulos y tienda.
- **Boss Blitz**: rotaciones, debilidades, mecánicas y vida por nivel.
- **Jefe mundial**: objetivos, estrellas, niveles de asedio y tienda.
- **Rankings** de Boss Blitz y Joint Drill por región (EN, JP, KR, TW), con los trekkers y discos más usados y los equipos de cada jugador.

### Equipos
- **Creador de equipos** y **builds de la comunidad**.

### Cuenta oficial y widget
- Vinculación con la cuenta oficial de Yostar mediante código OTP por correo (no se piden ni guardan contraseñas).
- La sesión se renueva sola: cuando el token de juego caduca, la app obtiene uno nuevo sin volver a pedir el código.
- **Widget de energía** para la pantalla de inicio:
  - cuenta atrás en vivo y energía que sube sola;
  - botón de recarga que sincroniza en segundo plano sin abrir la app;
  - más información según el tamaño (perfil, nivel, UID, colección y hora a la que se llena);
  - se vacía al cerrar sesión.

## Traducción al español

Los textos del juego se traducen automáticamente con [Argos Translate](https://github.com/argosopentech/argos-translate), un traductor libre que funciona en local: **sin API, sin claves y sin coste**.

- La GitHub Action [`traducir-datos.yml`](.github/workflows/traducir-datos.yml) se ejecuta cada 6 horas, traduce solo los textos nuevos y publica el resultado en GitHub Pages.
- La app lee primero esa versión traducida y, si no está disponible, usa los datos originales en inglés.
- Las traducciones se guardan en [`tools/translate/cache.json`](tools/translate/cache.json), así que cada ejecución solo procesa lo que haya cambiado.

### Traducir en local con GPU

Para traducir muchos textos de golpe (por ejemplo, tras una actualización grande del juego), puedes hacerlo en tu ordenador con una GPU NVIDIA y subir la caché:

```bash
pip install argostranslate nvidia-cublas-cu12
TRANSLATE_DEVICE=cuda python tools/translate/build_es.py
git add tools/translate/cache.json && git commit -m "Actualizar traducciones" && git push
```

Al subir la caché, la Action publica las traducciones en pocos minutos. Sin GPU también funciona con `TRANSLATE_DEVICE=cpu`, aunque tarda más.

## Compilar

```bash
flutter pub get
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/` (también se copia como `Stella-Trekkers-release.apk`).

## Aviso

Proyecto de fans, no oficial y sin ánimo de lucro. Stella Sora y todo su contenido pertenecen a Yostar. Los datos del juego se obtienen de StellaBase.
