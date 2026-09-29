# Voxtype from upstream's release binaries. The flake's source build (Rust +
# whisper.cpp Vulkan) is uncached, so it recompiled on every bump.
#
# Bump: set `version`, refresh each hash (`nix hash file --sri <asset>`, check
# against the release's SHA256SUMS.txt), and move the `voxtype` flake input
# to the same tag, since it supplies the home-manager module.
#
# There's no release binary for the native OSD, so we use the GTK4 one.
{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, wrapGAppsHook4
, alsa-lib, vulkan-loader, gtk4, gtk4-layer-shell, cairo, glib
, wtype, wl-clipboard, libnotify }:

let
  version = "1.1.0";
  asset = name: hash: fetchurl {
    url = "https://github.com/peteonrails/voxtype/releases/download/v${version}/voxtype-${version}-linux-x86_64-${name}";
    inherit hash;
  };
in
stdenv.mkDerivation {
  pname = "voxtype-bin";
  inherit version;

  srcs = [
    (asset "vulkan" "sha256-2yx5ODkv8I7ItQuK+5D4vT0BEezPWUPfL1HECgNo/sI=")
    (asset "osd" "sha256-DJrER7wjZyjzVdJbfFAK/UZBhqRZHMwY9IL8yYsWqSg=")
    (asset "osd-gtk4" "sha256-GVNfY8aXSECBmfP7/iuy94b1v0+qVNU5CJXuyuRgPcc=")
  ];
  fishCompletion = fetchurl {
    url = "https://raw.githubusercontent.com/peteonrails/voxtype/v${version}/packaging/completions/voxtype.fish";
    hash = "sha256-9yDd0k7pfBBbRIMjiZw2vKfGPQDC1CxKPacMPRV9zLs=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ autoPatchelfHook makeWrapper wrapGAppsHook4 ];
  buildInputs = [ stdenv.cc.cc.lib alsa-lib vulkan-loader gtk4 gtk4-layer-shell cairo glib ];
  # Only the GTK4 frontend needs the GApps environment; wrapped by hand below.
  dontWrapGApps = true;

  # All three binaries share bin/: the daemon finds `voxtype-osd` next to its
  # own executable, and the launcher finds `voxtype-osd-gtk4` the same way.
  installPhase = ''
    runHook preInstall
    srcs=($srcs)
    install -Dm755 ''${srcs[0]} $out/bin/voxtype
    install -Dm755 ''${srcs[1]} $out/bin/voxtype-osd
    install -Dm755 ''${srcs[2]} $out/bin/voxtype-osd-gtk4
    install -Dm644 $fishCompletion $out/share/fish/vendor_completions.d/voxtype.fish
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram $out/bin/voxtype \
      --prefix PATH : ${lib.makeBinPath [ wtype wl-clipboard libnotify ]}
    wrapProgram $out/bin/voxtype-osd-gtk4 "''${gappsWrapperArgs[@]}"
  '';

  meta = {
    description = "Push-to-talk voice-to-text for Linux (upstream release binaries)";
    homepage = "https://voxtype.io";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "voxtype";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
