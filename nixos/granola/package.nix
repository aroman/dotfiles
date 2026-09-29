# Granola (granola.ai) has no Linux build, but it's an Electron app: the
# macOS bundle's app.asar is portable JS. This grafts it onto nixpkgs'
# Linux Electron, patches it for Linux (see patch_app.py), and
# rebuilds Granola's forked encrypted-SQLite addon from the C++ source that
# ships inside the bundle — its fork adds an updateHook() no npm build has.
#
# Bumping: `nix build .#nixosConfigurations.moonbinder.pkgs.granola` after
# taking `version` from
#   curl -sL https://api.granola.ai/v1/check-for-update/latest-mac.yml
# then fix `hash`. The build fails loudly if Granola moves to an Electron
# major nixpkgs doesn't match, or if a patch marker stops matching.
{
  lib,
  stdenv,
  fetchurl,
  unzip,
  python3,
  asar,
  nodejs,
  node-gyp,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  imagemagick,
  electron_44,
}:

let
  electron = electron_44;

  # Only binding.gyp is missing from the addon source in the bundle.
  sqliteBindingSrc = fetchurl {
    url = "https://registry.npmjs.org/better-sqlite3-multiple-ciphers/-/better-sqlite3-multiple-ciphers-12.9.0.tgz";
    hash = "sha256-rYzrLP5ofgwQZUf90oHw0gtAaIIA0E9AuxY6/R8QJgk=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "granola";
  version = "7.595.3";

  src = fetchurl {
    url = "https://dr2v7l5emb758.cloudfront.net/${finalAttrs.version}/Granola-${finalAttrs.version}-mac-universal.zip";
    hash = "sha256-wYt2texanh+lGc2eZNd7uA2qVWi26aAn7t8oFwTEmVg=";
  };

  nativeBuildInputs = [
    unzip
    python3
    asar
    nodejs
    node-gyp # source only; see buildPhase
    makeWrapper
    copyDesktopItems
    imagemagick
  ];

  # Leave the prebuilt ELFs exactly as shipped. Granola's main process
  # require()s electron-click-drag-plugin's linux-x64 drag.node at startup;
  # it finds libstdc++ fine inside electron, but after autoPatchelf rewrites
  # it the whole app segfaults before logging anything. The copied electron
  # binary is already patched by nixpkgs and gains nothing from a re-strip.
  dontStrip = true;
  dontPatchELF = true;

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src \
      'Granola.app/Contents/Info.plist' \
      'Granola.app/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist' \
      'Granola.app/Contents/Resources/app.asar' \
      'Granola.app/Contents/Resources/app.asar.unpacked/*' \
      'Granola.app/Contents/Resources/icons/*'
    runHook postUnpack
  '';

  sourceRoot = "Granola.app/Contents";

  buildPhase = ''
    runHook preBuild

    plist() { sed -n "/<key>$1<\/key>/{n;s/.*<string>\([^<]*\)<\/string>.*/\1/p;q}" "$2"; }

    appVersion=$(plist CFBundleShortVersionString Info.plist)
    [[ "$appVersion" == "${finalAttrs.version}" ]] \
      || { echo "bundle is Granola $appVersion, expected ${finalAttrs.version}"; exit 1; }

    bundledElectron=$(plist CFBundleVersion "Frameworks/Electron Framework.framework/Versions/A/Resources/Info.plist")
    [[ "''${bundledElectron%%.*}" == "${lib.versions.major electron.version}" ]] \
      || { echo "Granola bundles Electron $bundledElectron; switch electron_* to match"; exit 1; }

    # The renderer claims the macOS version the app was built against.
    sdk=$(plist DTSDKName Info.plist)
    macosVersion=''${sdk#macosx}
    [[ "$macosVersion" == *.*.* ]] || macosVersion=$macosVersion.0

    # Electron loads resources/app/ in place of app.asar, so ship the bundle
    # extracted (this also folds app.asar.unpacked back in) and patch plain
    # files instead of editing the archive in place.
    asar extract Resources/app.asar app
    python3 ${./patch_app.py} app --macos-version "$macosVersion"

    pushd app/node_modules/better-sqlite3-multiple-ciphers
    tar xzf ${sqliteBindingSrc} --strip-components=1 package/binding.gyp
    # Not bin/node-gyp: nixpkgs' wrapper exports npm_config_nodedir=<nodejs>,
    # which beats --nodedir and silently builds against Node's ABI (and
    # Node's stock sqlite3.h) instead of Electron's.
    npm_config_nodedir=${electron.headers} node ${node-gyp}/lib/node_modules/node-gyp/bin/node-gyp.js \
      rebuild --release --jobs="$NIX_BUILD_CORES"
    # Ship only the addon itself: the sources are ~28 MB, and build/'s
    # Makefiles would drag node-gyp, python3 and the headers into the closure.
    mv build/Release/better_sqlite3.node "$TMPDIR"
    rm -rf build deps src binding.gyp
    install -D "$TMPDIR/better_sqlite3.node" build/Release/better_sqlite3.node
    popd

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Electron derives process.resourcesPath from its own executable's real
    # path, and Granola looks up its icons and helpers there. So the binary
    # has to be a real file beside our resources/, not a symlink back into
    # the electron store path; the rest of the runtime can be symlinks.
    # It also must not be called "electron": app.isPackaged is decided by the
    # executable's name, and when false Granola runs as a dev build that looks
    # for its tray icon and native helpers inside the app (tray shows blank).
    app=$out/lib/granola
    mkdir -p $app/resources
    for f in ${electron.dist}/*; do
      [[ "$(basename "$f")" == resources ]] || ln -s "$f" "$app/"
    done
    rm $app/electron
    cp ${electron.dist}/electron $app/granola
    cp -r app Resources/icons $app/resources/

    # Reuse nixpkgs' electron wrapper (GIO modules, gsettings schemas, …),
    # pointed at our copy of the binary.
    sed "s|${electron.dist}/electron|$app/granola|" ${electron}/bin/electron > $app/granola-env
    chmod +x $app/granola-env
    grep -q "$app/granola" $app/granola-env  # fail if the sed target moved
    makeWrapper $app/granola-env $out/bin/granola \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WebRTCPipeWireCapturer"

    # The tray uses iconTemplate.png on Linux too: a black macOS "template"
    # image that macOS recolours to suit the menu bar. Linux shows it as-is,
    # i.e. black on a dark bar. Make it white, and base it on the 48px @3x
    # rendition so it stays sharp when the bar scales it up.
    icons=$app/resources/icons
    magick Resources/icons/iconTemplate@3x.png -fill white -colorize 100 $icons/iconTemplate.png
    cp $icons/iconTemplate.png $icons/iconTemplate@2x.png
    cp $icons/iconTemplate.png $icons/iconTemplate@3x.png

    # hicolor stops at 512x512; a 1024 icon is invisible to theme lookup.
    for size in 16 32 48 64 128 256 512; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      magick Resources/icons/mac-icon.png -resize ''${size}x''${size} \
        $out/share/icons/hicolor/''${size}x''${size}/apps/granola.png
    done

    runHook postInstall
  '';

  # Build tools that a stray path in the output would pin at runtime.
  disallowedReferences = [ python3 node-gyp electron.headers ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # The addon is what fails to load if the build went wrong, and the app
    # only surfaces that as a blank window. Exercise encryption + updateHook.
    ELECTRON_RUN_AS_NODE=1 $out/lib/granola/granola -e "
      const Database = require('$out/lib/granola/resources/app/node_modules/better-sqlite3-multiple-ciphers');
      const db = new Database('$TMPDIR/smoke.db');
      db.pragma(\"cipher='sqlcipher'\");
      db.pragma(\"key='smoke'\");
      db.exec('CREATE TABLE t(v)');
      let fired = false;
      db.updateHook(() => { fired = true; });
      db.prepare('INSERT INTO t VALUES (42)').run();
      if (db.prepare('SELECT v FROM t').get().v !== 42) throw new Error('insert failed');
      if (!fired) throw new Error('updateHook did not fire');
      db.close();
      if (require('fs').readFileSync('$TMPDIR/smoke.db').subarray(0, 15).toString() === 'SQLite format 3')
        throw new Error('database is not encrypted');
    "
    runHook postInstallCheck
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "granola";
      desktopName = "Granola";
      comment = "AI notepad for meetings";
      exec = "granola %U";
      icon = "granola";
      categories = [ "Office" ];
      keywords = [ "meeting" "notes" "transcription" ];
      mimeTypes = [ "x-scheme-handler/granola" ];
      startupWMClass = "granola";
    })
  ];

  meta = {
    description = "Granola's macOS Electron app run on Linux Electron";
    homepage = "https://www.granola.ai";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "granola";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
