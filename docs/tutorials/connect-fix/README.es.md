# Left 4 Dead 2 — Solución para el Error de Reintento de Conexión UDP

🌐 [English](README.md) | [Português](README.pt.md) | **Español**

Si recibes el siguiente error al intentar conectarte al servidor (tu consola muestra la dirección del servidor en lugar de `<server IP>`):

```
Retrying public(<server IP>:27015)
Sending UDP connect to public IP <server IP>:27015
```

<p align="center">
  <img src="assets/connection-failed.jpg" alt="Fallo de conexión tras 30 intentos"/>
</p>

Sigue estos pasos para solucionarlo:

## ✅ Solución

1. **Cierra el juego.**
2. **Abre Steam**, haz clic derecho en **Left 4 Dead 2** en tu Biblioteca y selecciona **Propiedades**.

   <p align="center">
     <img src="assets/l4d2-properties.png" alt="Propiedades de Left 4 Dead 2"/>
   </p>

3. En **Opciones de lanzamiento**, añade el siguiente parámetro:

   ```
   +clientport 27666
   ```

   <p align="center">
     <img src="assets/l4d2-launch-options.png" alt="Opciones de lanzamiento de Left 4 Dead 2"/>
   </p>

   - `27666` puede ser cualquier número **dentro del rango 27005–27032**.
   - Si todavía tienes problemas de conexión, usa otro puerto — a veces cambiar el puerto resuelve conflictos con otras aplicaciones.

## ✅ Nota Importante

Para que las opciones de lanzamiento funcionen, **siempre inicia el juego desde Steam**.

Si abres el juego desde un **acceso directo en el escritorio**, debes agregar los mismos parámetros de lanzamiento en las propiedades del acceso directo:

1. Haz clic derecho en el **acceso directo del juego** y selecciona **Propiedades**.
2. En el campo **Destino**, añade los parámetros **después de las comillas**, por ejemplo:

   ```plaintext
   "E:\Steam\steamapps\common\Left 4 Dead 2\left4dead2.exe" -console +clientport 27666
   ```

## ⚙️ Ejemplo de Opciones de Lanzamiento

Así se ven mis Opciones de lanzamiento:

```
-lv +precache_all_survivors 1 -novid -console -nojoy -noforcemaccel -noforcemparms -noforcemspd +clientport 27666
```

### ¿Qué significa cada parámetro?

- `-lv` — Activa el modo de baja violencia (puede reducir los efectos de sangre).
- `+precache_all_survivors 1` — Precarga todos los modelos de los supervivientes para evitar tirones al cambiar de personaje.
- `-novid` — Omite el video de introducción.
- `-console` — Activa la consola de desarrollador al iniciar.
- `-nojoy` — Desactiva el soporte para joystick (libera recursos del sistema).
- `-noforcemaccel`, `-noforcemparms`, `-noforcemspd` — Aseguran que la configuración del ratón no sea modificada por el juego.
- `+clientport 27666` — Obliga al juego a usar un puerto local específico para evitar conflictos de conexión.

---

## 📞 ¿Necesitas ayuda?

Si el problema continúa, contáctame aquí: [https://steamcommunity.com/id/altairsossai/](https://steamcommunity.com/id/altairsossai/)

¡Buena suerte y diviértete!
