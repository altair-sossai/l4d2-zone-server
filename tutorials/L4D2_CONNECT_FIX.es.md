# <img src="https://cdn.jsdelivr.net/gh/hjnilsson/country-flags/svg/es.svg" width="40"/> Left 4 Dead 2 — Solución para el Error de Reintento de Conexión UDP

- [<img src="https://cdn.jsdelivr.net/gh/hjnilsson/country-flags/svg/us.svg" width="20"/> README in English](./L4D2_CONNECT_FIX.en.md)
- [<img src="https://cdn.jsdelivr.net/gh/hjnilsson/country-flags/svg/br.svg" width="20"/> README em Português](./L4D2_CONNECT_FIX.pt.md)

Si recibes el siguiente error al intentar conectarte al servidor:

```
Retrying public(181.214.221.198:27015)
Sending UDP connect to public IP 181.214.221.198:27015
```

<p align="center">
  <img src="/tutorials/assets/connection-failed.jpg?raw=true" alt="Fallo de conexión tras 30 intentos"/>
</p>

Sigue estos pasos para solucionarlo:

## ✅ Solución

1. **Cierra el juego.**
2. **Abre Steam**, haz clic derecho en **Left 4 Dead 2** en tu Biblioteca y selecciona **Propiedades**.

<p align="center">
  <img src="/tutorials/assets/l4d2-properties.png?raw=true" alt="Propiedades de Left 4 Dead 2"/>
</p>

3. En **Opciones de lanzamiento**, añade el siguiente parámetro:

   ```
   +clientport 27666
   ```

<p align="center">
  <img src="/tutorials/assets/l4d2-launch-options.png?raw=true" alt="Opciones de lanzamiento de Left 4 Dead 2"/>
</p>

* `27666` puede ser cualquier número **dentro del rango 27005–27032**.
* Si el problema persiste, prueba otro puerto — a veces cambiarlo ayuda a resolver conflictos con otras aplicaciones.

## ⚙️ Ejemplo de Opciones de Lanzamiento

Así se ven mis Opciones de Lanzamiento:

```
-lv +precache_all_survivors 1 -novid -console -nojoy -noforcemaccel -noforcemparms -noforcemspd +clientport 27666
```

### ¿Qué significa cada parámetro?

* `-lv` — Activa el modo de baja violencia (puede reducir los efectos de sangre).
* `+precache_all_survivors 1` — Precarga todos los modelos de los supervivientes para evitar tirones al cambiar de personaje.
* `-novid` — Omite el video de introducción.
* `-console` — Activa la consola de desarrollador al iniciar.
* `-nojoy` — Desactiva el soporte para joystick (libera recursos del sistema).
* `-noforcemaccel`, `-noforcemparms`, `-noforcemspd` — Aseguran que la configuración del ratón no sea modificada por el juego.
* `+clientport 27666` — Obliga al juego a usar un puerto local específico para evitar conflictos de conexión.

---

## 📞 ¿Necesitas ayuda?

Si el problema continúa, contáctame aquí: [https://steamcommunity.com/id/altairsossai/](https://steamcommunity.com/id/altairsossai/)

¡Buena suerte y diviértete!
