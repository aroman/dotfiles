# ChatGPT desktop (Linux preview) from OpenAI's prebuilt package. It's an
# Electron 42 bundle with its own codex, rg, tectonic and a node runtime for
# computer use under resources/, all autoPatchelf'd in place.
#
# Bump: the version list is in
#   curl -sL https://persistent.oaistatic.com/codex-app-prod/linux/install-arch.sh | grep versions=
# (first entry is newest). Set `version`, refresh `hash`. The Arch package is
# used over the .deb because only its URL is versioned; deb/latest/ moves.
#
# Wayland is on unconditionally (upstream calls it experimental). If the
# window misbehaves, run `chatgpt --ozone-platform=x11` to compare.
{ lib, stdenv, fetchurl, zstd, perl, autoPatchelfHook, makeWrapper, addDriverRunpath
, alsa-lib, at-spi2-atk, at-spi2-core, cairo, cups, dbus, expat, gdk-pixbuf
, glib, gtk3, libdrm, libgbm, libGL, libnotify, libpulseaudio, libsecret
, libusb1, libxkbcommon, nspr, nss, openssl, pango, systemd, tpm2-tss
, vulkan-loader, xdg-utils, libxcb, libx11, libxcomposite, libxdamage
, libxext, libxfixes, libxrandr }:

stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt-bin";
  version = "26.928.21956";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/arch/${finalAttrs.version}/x86_64/chatgpt-bin-${finalAttrs.version}-1-x86_64.pkg.tar.zst";
    hash = "sha256-qE2GhxPR655nMEXDDaCXq7zzHglQkghFtsfMtMUBfb4=";
  };

  nativeBuildInputs = [ zstd autoPatchelfHook makeWrapper perl ];

  buildInputs = [
    stdenv.cc.cc.lib alsa-lib at-spi2-atk at-spi2-core cairo cups dbus expat
    gdk-pixbuf glib gtk3 libdrm libgbm libnotify libusb1 libxkbcommon nspr nss
    openssl pango systemd tpm2-tss libxcb
    libx11 libxcomposite libxdamage libxext libxfixes libxrandr
  ];

  # Chromium's optional Qt theme shims; we never load them.
  autoPatchelfIgnoreMissingDeps = [ "libQt5*.so*" "libQt6*.so*" ];

  unpackPhase = ''
    runHook preUnpack
    mkdir root
    tar --zstd -xf $src -C root usr
    runHook postUnpack
  '';

  # Stripping a 300 MB Electron binary and the bundled codex gains nothing.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib
    cp -r root/usr/lib/chatgpt $out/lib/chatgpt
    cp -r root/usr/share $out/share

    # On Linux the windows use Electron's titleBarOverlay, which draws
    # min/max/close over the content; niri doesn't need them. The app also
    # calls setTitleBarOverlay() on Linux (on window creation for theming,
    # and on zoom), which throws once the overlay is off and aborts startup
    # ("Desktop bootstrap failed ... bootstrap-import-main"), so those
    # Linux branches are turned off too. Each edit swaps an expression for
    # a same-length constant (space-padded) so asar offsets stay valid,
    # and dies if its pattern stops matching. (Asar per-file hashes go
    # stale, but this Electron doesn't check them on Linux.)
    perl -0777 -i -pe '
      sub pad { $_[0] . (" " x ($_[1] - length $_[0])) }
      my $lin = q{process.platform!==`linux`};
      my $lineq = q{process.platform===`linux`};
      s/(titleBarStyle:`hidden`,titleBarOverlay:)([\w\$]+\(\w\))/$1 . pad("!1", length $2)/ge
        or die "chatgpt: titleBarOverlay pattern not found\n";
      s/(installApplicationMenuTitleBarOverlaySync\(\w,\w\)\{if\(process\.platform!==`win32`&&)\Q$lin\E/$1 . pad("!0", length $lin)/e
        or die "chatgpt: overlay theme-sync pattern not found\n";
      s/(\(process\.platform===`win32`\|\|)\Q$lineq\E(\)&&\(this\.windowZooms\.set\()/$1 . pad("!1", length $lineq) . $2/e
        or die "chatgpt: overlay zoom pattern not found\n";
    ' $out/lib/chatgpt/resources/app.asar
    # node-hid/serialport ship musl alternates next to the glibc ones.
    find $out/lib/chatgpt -path '*musl*' -name '*.node' -delete

    makeWrapper $out/lib/chatgpt/ChatGPT $out/bin/chatgpt \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libGL libpulseaudio libsecret vulkan-loader ]}:${addDriverRunpath.driverLink}/lib \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags "--ozone-platform=wayland --enable-wayland-ime"

    # Upstream claims http(s) (handlr owns those here) plus csv/xlsx/docx/pptx;
    # keep only its own codex:// scheme.
    sed -i "s|^MimeType=.*|MimeType=x-scheme-handler/codex;|" $out/share/applications/chatgpt.desktop
    runHook postInstall
  '';

  meta = {
    description = "ChatGPT desktop app by OpenAI (Linux preview)";
    homepage = "https://learn.chatgpt.com/docs/linux/linux-app";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
})
