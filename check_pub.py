import json
import urllib.request
packages = ['flutter_phone_direct_caller', 'shared_preferences', 'telephony', 'url_launcher', 'workmanager']
for pkg in packages:
    url = f'https://pub.dev/api/packages/{pkg}'
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            data = json.load(r)
    except Exception as e:
        print('ERR', pkg, e)
        continue
    print('PACKAGE', pkg, 'latest', data['latest']['version'])
    print('  recent', [v['version'] for v in data['versions'][:10]])
