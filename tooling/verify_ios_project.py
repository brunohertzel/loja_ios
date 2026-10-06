#!/usr/bin/env python3
"""Apply API branding without changing signing credentials; validate native iOS files."""
import argparse, json, os, plistlib, re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
cfg = json.loads((root/'tooling/mobile_app_config_ios.json').read_text())
bundle = cfg['ios_bundle_id']
if not re.fullmatch(r'[A-Za-z0-9]+(?:\.[A-Za-z0-9-]+)+', bundle):
    raise SystemExit('Bundle ID iOS inválido.')
pbx = root/'ios/Runner.xcodeproj/project.pbxproj'
info = root/'ios/Runner/Info.plist'
if args.apply:
    text = pbx.read_text()
    text = re.sub(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);',
                  lambda m: 'PRODUCT_BUNDLE_IDENTIFIER = '+bundle+('.RunnerTests' if 'RunnerTests' in m[1] else '')+';', text)
    text = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [^;]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.5;', text)
    team = os.environ.get('SOFT_IOS_TEAM_ID', '').strip()
    if team:
        if not re.fullmatch(r'[A-Z0-9]{10}', team): raise SystemExit('Team ID Apple inválido.')
        if 'DEVELOPMENT_TEAM = ' in text:
            text = re.sub(r'DEVELOPMENT_TEAM = [^;]+;', 'DEVELOPMENT_TEAM = '+team+';', text)
        else:
            text = text.replace('PRODUCT_BUNDLE_IDENTIFIER = ', 'DEVELOPMENT_TEAM = '+team+';\n\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = ')
    pbx.write_text(text)
    data = plistlib.loads(info.read_bytes())
    data['CFBundleDisplayName'] = cfg['app_name']
    data['NSCameraUsageDescription'] = 'Use a câmera para ler códigos de barras e enviar imagens ao suporte.'
    data['NSPhotoLibraryUsageDescription'] = 'Escolha imagens para enviar ao suporte.'
    data['NSFaceIDUsageDescription'] = 'Entre na sua conta com Face ID.'
    if cfg['api_base_url'].startswith('https://'):
        data.pop('NSAppTransportSecurity', None)
    else:
        raise SystemExit('A API de produção deve usar HTTPS.')
    google_client = os.environ.get('SOFT_GOOGLE_IOS_CLIENT_ID', '').strip()
    if google_client: data['GIDClientID'] = google_client
    scheme = os.environ.get('SOFT_GOOGLE_IOS_REVERSED_CLIENT_ID', '').strip()
    if not scheme and google_client: scheme = '.'.join(reversed(google_client.split('.')))
    if scheme:
        data['CFBundleURLTypes'] = [{'CFBundleTypeRole':'Editor','CFBundleURLSchemes':[scheme]}]
    info.write_bytes(plistlib.dumps(data, sort_keys=False))
text = pbx.read_text()
assert '{{' not in text, 'Template iOS não renderizado'
assert bundle in text and bundle+'.RunnerTests' in text
assert 'Generated.xcconfig' in text
data = plistlib.loads(info.read_bytes())
assert data['CFBundleDisplayName'] == cfg['app_name']
assert data['CFBundleVersion'] == '$(FLUTTER_BUILD_NUMBER)'
assert data['CFBundleShortVersionString'] == '$(FLUTTER_BUILD_NAME)'
assert all(data.get(k) for k in ['NSCameraUsageDescription','NSPhotoLibraryUsageDescription','NSFaceIDUsageDescription'])
for rel in ['ios/Podfile','ios/Runner/AppDelegate.swift','ios/Runner.xcworkspace/contents.xcworkspacedata','ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme']:
    assert (root/rel).is_file(), rel
assert 'platform :ios' in (root/'ios/Podfile').read_text()
print('Projeto iOS, identidade, versão e permissões conferidos.')
