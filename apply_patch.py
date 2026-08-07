from pathlib import Path

# Patch workmanager_android gradle.properties
path = Path('patched_plugins/workmanager_android/android/gradle.properties')
text = path.read_text()
if 'android.builtInKotlin=true' not in text:
    text = text.replace('android.enableJetifier=false\n', 'android.enableJetifier=false\nandroid.builtInKotlin=true\n')
    path.write_text(text)

# Patch pubspec.yaml
path = Path('pubspec.yaml')
text = path.read_text()
old = '''  permission_handler: ^12.0.3
  telephony: ^0.2.0
  supabase_flutter: ^2.15.4
  url_launcher: ^6.3.2
  workmanager: ^0.9.0+3
  shared_preferences: ^2.5.5
  flutter_phone_direct_caller: ^2.2.1
  intl: ^0.19.0
  flutter_local_notifications: ^17.2.2


flutter:
  uses-material-design: true
'''
new = '''  permission_handler: ^12.0.3
  telephony:
    path: patched_plugins/telephony
  supabase_flutter: ^2.15.4
  url_launcher: ^6.3.2
  workmanager: ^0.9.0+3
  shared_preferences: ^2.5.5
  flutter_phone_direct_caller:
    path: patched_plugins/flutter_phone_direct_caller
  intl: ^0.19.0
  flutter_local_notifications: ^17.2.2

dependency_overrides:
  workmanager_android:
    path: patched_plugins/workmanager_android

flutter:
  uses-material-design: true
'''
if old not in text:
    print('PUBSPEC old block not found')
    print(text)
    raise SystemExit(1)
path.write_text(text.replace(old, new))
print('patched successfully')
