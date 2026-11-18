# Android signing
You generate and keep the upload key; never commit it.

```
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
base64 -w0 upload-keystore.jks     # macOS: base64 -i upload-keystore.jks
```
Add these **repository secrets** (Settings > Secrets and variables > Actions):
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.

Local builds: copy `android_templates/key.properties.example` to `apps/<game>/android/key.properties`.

Enroll each app in **Play App Signing** when creating the first release; Google holds the app signing key, you keep the upload key. Back up the keystore and passwords in at least two safe places: losing the upload key requires a Play support reset.
One upload key may be shared by all games, or create one per game.
