# Left 4 Dead 2 — Fix for the UDP Connect Retry Issue

🌐 **English** | [Português](README.pt.md) | [Español](README.es.md)

If you get the following connection error when trying to join the server (your console shows the server's address in place of `<server IP>`):

```
Retrying public(<server IP>:27015)
Sending UDP connect to public IP <server IP>:27015
```

<p align="center">
  <img src="assets/connection-failed.jpg" alt="Connection failed after 30 retries"/>
</p>

Follow these steps to solve it:

## ✅ Solution

1. **Close the game.**
2. **Open Steam**, right-click **Left 4 Dead 2** in your Library and select **Properties**.

   <p align="center">
     <img src="assets/l4d2-properties.png" alt="Left 4 Dead 2 properties"/>
   </p>

3. In **Launch Options**, add the following parameter:

   ```
   +clientport 27666
   ```

   <p align="center">
     <img src="assets/l4d2-launch-options.png" alt="Left 4 Dead 2 launch options"/>
   </p>

   - `27666` can be any number **within the range 27005–27032**.
   - If you still have connection issues, use a different port — sometimes changing the port solves conflicts with other applications.

## ✅ Important Note

To make sure the launch options work, **always start the game through Steam**.

If you launch the game using a **desktop shortcut**, you must add the same launch parameters to the shortcut's properties:

1. Right-click the **game shortcut** and select **Properties**.
2. In the **Target** field, add the parameters **after the quotes**, for example:

   ```plaintext
   "E:\Steam\steamapps\common\Left 4 Dead 2\left4dead2.exe" -console +clientport 27666
   ```

## ⚙️ Example Launch Options

Here is an example of what my Launch Options look like:

```
-lv +precache_all_survivors 1 -novid -console -nojoy -noforcemaccel -noforcemparms -noforcemspd +clientport 27666
```

### What do these mean?

- `-lv` — Enables Low Violence mode (may reduce gore effects).
- `+precache_all_survivors 1` — Preloads all survivor models to avoid stutters when switching characters.
- `-novid` — Skips the intro video.
- `-console` — Enables the developer console on startup.
- `-nojoy` — Disables joystick support (frees up system resources).
- `-noforcemaccel`, `-noforcemparms`, `-noforcemspd` — Make sure your mouse settings are not overridden by the game.
- `+clientport 27666` — Forces the game to use a specific local port to avoid connection conflicts.

---

## 📞 Need Help?

If the issue persists, feel free to reach out here: [https://steamcommunity.com/id/altairsossai/](https://steamcommunity.com/id/altairsossai/)

Good luck and have fun!
