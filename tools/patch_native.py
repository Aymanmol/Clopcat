"""Applies the native settings that `flutter create` does not: Media3 deps, minSdk, iOS photo permissions."""
import pathlib, plistlib, re, sys
root = pathlib.Path(sys.argv[1])
deps = ['media3-transformer', 'media3-effect', 'media3-common']
kts, grv = root/'android/app/build.gradle.kts', root/'android/app/build.gradle'
if kts.exists():
    s = kts.read_text()
    s = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', s)
    s += '\ndependencies {\n' + ''.join(f'    implementation("androidx.media3:{d}:1.3.1")\n' for d in deps) + '}\n'
    kts.write_text(s)
elif grv.exists():
    s = grv.read_text()
    s = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', s)
    s += '\ndependencies {\n' + ''.join(f'    implementation "androidx.media3:{d}:1.3.1"\n' for d in deps) + '}\n'
    grv.write_text(s)
else:
    sys.exit('No android/app/build.gradle(.kts) found')
pl = root/'ios/Runner/Info.plist'
d = plistlib.loads(pl.read_bytes())
d['NSPhotoLibraryUsageDescription'] = 'Choose videos to edit.'
d['NSPhotoLibraryAddUsageDescription'] = 'Save exported videos to your photo library.'
pl.write_bytes(plistlib.dumps(d))
print('native settings patched')
