# Conectar Google Calendar a ombu

ombu puede leer **y escribir** en tu Google Calendar por la API oficial. Lo que anotes en ombu aparece en tu celular, y lo que tengas en Google (clases de Meet incluidas) aparece en la barra. Se hace una sola vez, son unos 10 minutos y es gratis.

Si solo querés *ver* tus eventos, hay una alternativa más simple: pegar la «dirección secreta en formato iCal» en el calendario de ombu (botón del calendario, arriba a la derecha).

## 1. Crear las credenciales en Google

1. Entrá a <https://console.cloud.google.com> con tu cuenta de Google.
2. Arriba, al lado del logo, elegí **Proyecto → Proyecto nuevo**. Ponele `ombu` y creá.
3. Con ese proyecto elegido, abrí **APIs y servicios → Biblioteca**, buscá **Google Calendar API** y tocá **Habilitar**.
4. Abrí **APIs y servicios → Pantalla de consentimiento de OAuth** (en la consola nueva se llama **Google Auth Platform**) y completá:
   - Tipo de usuario: **Externo**.
   - Nombre de la app: `ombu`. Correo de asistencia y de contacto: el tuyo.
   - En **Público** (Audiencia), agregá tu correo como **usuario de prueba**.
   - En **Acceso a los datos**, agregá estos permisos si te los deja elegir: `.../auth/calendar.events` y `.../auth/calendar.calendarlist.readonly`.
5. Abrí **Credenciales → Crear credenciales → ID de cliente de OAuth**. Tipo de aplicación: **Aplicación de escritorio**. Nombre: `ombu`. Crear.
6. En la ventana que aparece tocá **Descargar JSON**.
7. Guardá ese archivo como `~/.local/share/ombu/google-client.json` y dejalo legible solo para vos:

   ```sh
   mv ~/Descargas/client_secret_*.json ~/.local/share/ombu/google-client.json
   chmod 600 ~/.local/share/ombu/google-client.json
   ```

## 2. Dar el permiso

1. En ombu, abrí el calendario (clic en la fecha del reloj) y tocá el botón del calendario de arriba a la derecha.
2. Tocá **Conectar con Google**. Se abre el navegador.
3. Elegí tu cuenta. Google va a decir **«Google no ha verificado esta app»**: es normal, la app es tuya. Tocá **Configuración avanzada → Ir a ombu (no seguro)** y aceptá los permisos.
4. Cuando el navegador diga «Listo, ya podés cerrar esta pestaña», volvé a ombu: el panel dice **Google Calendar conectado**.

## Si se desconecta a la semana (modo Prueba)

Mientras la app esté en **modo Prueba**, Google vence el permiso a los **7 días**. No pasa nada grave: ombu avisa con una notificación («Google Calendar se desconectó») y el botón **Conectar con Google** del calendario vuelve a aparecer; son dos clics y no hay que tocar nada más.

Si preferís que no venza, en la pantalla de consentimiento de OAuth podés tocar **Publicar la app** (pasar a **En producción**). No la hace comercial ni pública, no se verifica y no cuesta nada; solo vas a ver el aviso de «app no verificada» al conectar. Es opcional.

## Cómo se usa

- Al anotar un evento, el botón de la nube junto a la hora elige si va a **Google** (se ve en el celular) o se queda **solo en ombu**.
- Los eventos de Google se actualizan cada 5 minutos. El botón de flechas del encabezado fuerza una actualización.
- La cámara en un evento abre su reunión de Meet.
- ombu solo borra los eventos que creó él mismo; los demás se borran desde Google Calendar.
- Los recordatorios suenan 10 minutos antes (los propios, a la hora).

## Seguridad

- `google-client.json` y `google-token.json` (el token que se guarda al dar el permiso) quedan en `~/.local/share/ombu` con permisos `600` y **nunca van al repositorio**.
- El token permite ver y editar los eventos de tu calendario. Si creés que se filtró, revocá el acceso de ombu en <https://myaccount.google.com/permissions> y volvé a conectar.
- Para desconectar: botón **Desconectar** en el panel. Borra el token y lo revoca en Google.
