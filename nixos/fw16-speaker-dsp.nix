# Framework 16 speaker DSP — LV2 plugins (LSP + Calf) loaded natively via
# PipeWire filter-chain. Based on "Cab's_20Fav" EasyEffects preset, adapted
# for direct PipeWire gain staging (no EasyEffects virtual sink).
#
# Chain: HPF (+36 dB input stage) → Bass Enhancer → MB Compressor → Stereo → Limiter (g_out attenuates)
#
# The chain runs "hot" internally (+36 dB from the HPF) so the compressor and
# limiter thresholds are hit properly. The limiter's g_out attenuates ~34 dB
# before the signal reaches the speaker, replacing EasyEffects' output volume.
{ pkgs, lib, ... }:

{
  # LV2 plugin path for PipeWire filter-chain (bypasses broken extraLv2Packages)
  systemd.user.services.pipewire.environment.LV2_PATH =
    lib.mkForce "${pkgs.lsp-plugins}/lib/lv2:${pkgs.calf}/lib/lv2";

  # Rename the raw ALSA speaker node
  services.pipewire.wireplumber.extraConfig."50-fw16-speaker-rename" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "alsa_output.pci-0000_c2_00.6.HiFi__Speaker__sink"; }
        ];
        actions.update-props = {
          "node.description" = "Raw Laptop Speakers";
        };
      }
      {
        matches = [
          { "node.name" = "alsa_input.pci-0000_c2_00.6.HiFi__Mic1__source"; }
        ];
        actions.update-props = {
          "node.description" = "Framework 16 Microphone";
        };
      }
    ];
  };

  # Make DSP the default audio sink
  services.pipewire.wireplumber.extraConfig."50-fw16-speaker-default" = {
    "wireplumber.settings" = {
      "default.configured.audio.sink" = "effect_input.fw16_speaker_dsp";
    };
  };

  services.pipewire.extraConfig.pipewire."90-fw16-speaker-dsp" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Framework 16 Speakers";
          "media.name" = "Framework 16 Speakers";
          "filter.graph" = {
            nodes = [
              # 1. High-pass filter + input gain stage (+36 dB drives the chain hot)
              {
                type = "lv2";
                plugin = "http://lsp-plug.in/plugins/lv2/filter_stereo";
                name = "hpf";
                control = {
                  "ft" = 1;        # Hi-pass
                  "fm" = 0;        # RLC (BT)
                  "s" = 0;         # x1 slope
                  "f" = 90.0;      # frequency (Hz) — FW16 speakers can't reproduce below ~80 Hz
                  "g" = 36.0;      # gain (dB) — drives chain hot for compressor/limiter
                  "q" = 0.0;       # quality
                  "w" = 4.0;       # width
                  "bal" = 0.0;     # balance
                };
              }
              # 2. Bass enhancer — generates harmonics for perceived bass on small speakers
              {
                type = "lv2";
                plugin = "http://calf.sourceforge.net/plugins/BassEnhancer";
                name = "bass";
                control = {
                  "amount" = 8.0;
                  "drive" = 10.0;       # harmonics
                  "freq" = 200.0;       # scope
                  "floor" = 10.0;
                  "floor_active" = 1;
                  "blend" = 0.0;
                  "listen" = 0;
                };
              }
              # 3. Multiband compressor — dynamic per-band compression + makeup gain
              {
                type = "lv2";
                plugin = "http://lsp-plug.in/plugins/lv2/sc_mb_compressor_stereo";
                name = "mbcomp";
                control = {
                  # Global
                  "mode" = 1;             # Modern
                  "envb" = 0;             # None
                  "g_dry" = 0.00001;      # -100 dB (linear)
                  "g_wet" = 1.0;          # 0 dB (linear)

                  # Band 0: sub-bass (0–250 Hz)
                  "ce_0" = 1;             # compressor enable
                  "cm_0" = 0;             # Downward
                  "al_0" = -16.0;         # attack threshold (dB)
                  "at_0" = 150.0;         # attack time (ms)
                  "rrl_0" = -100.0;       # release threshold (dB)
                  "rt_0" = 300.0;         # release time (ms)
                  "cr_0" = 5.0;           # ratio
                  "kn_0" = -12.0;         # knee (dB)
                  "mk_0" = 8.0;           # makeup (dB)
                  "bth_0" = -72.0;        # boost threshold (dB)
                  "bsa_0" = 6.0;          # boost amount (dB)
                  "scs_0" = 0;            # sidechain source: Middle
                  "scm_0" = 1;            # sidechain mode: RMS
                  "scr_0" = 10.0;         # sidechain reactivity
                  "sla_0" = 0.0;          # sidechain lookahead

                  # Band 1: low-mid (250–1250 Hz)
                  "cbe_1" = 1;            # enable band
                  "sf_1" = 250.0;         # split frequency
                  "ce_1" = 1;
                  "cm_1" = 0;             # Downward
                  "al_1" = -24.0;
                  "at_1" = 150.0;
                  "rrl_1" = -100.0;
                  "rt_1" = 200.0;
                  "cr_1" = 3.0;
                  "kn_1" = -9.0;
                  "mk_1" = 4.0;           # makeup (dB)
                  "bth_1" = -72.0;
                  "bsa_1" = 6.0;
                  "scs_1" = 0;
                  "scm_1" = 1;
                  "scr_1" = 10.0;
                  "sla_1" = 0.0;

                  # Band 2: mid-presence (1250–5000 Hz) — tamed for belted vocal peaks
                  "cbe_2" = 1;
                  "sf_2" = 1250.0;
                  "ce_2" = 1;
                  "cm_2" = 0;             # Downward
                  "al_2" = -12.0;
                  "at_2" = 100.0;
                  "rrl_2" = -100.0;
                  "rt_2" = 150.0;
                  "cr_2" = 3.0;
                  "kn_2" = -9.0;
                  "mk_2" = 5.0;
                  "bth_2" = -72.0;
                  "bsa_2" = 6.0;
                  "scs_2" = 0;
                  "scm_2" = 1;
                  "scr_2" = 10.0;
                  "sla_2" = 0.0;

                  # Band 3: treble (5000+ Hz)
                  "cbe_3" = 1;
                  "sf_3" = 5000.0;
                  "ce_3" = 1;
                  "cm_3" = 0;             # Downward
                  "al_3" = -24.0;
                  "at_3" = 80.0;
                  "rrl_3" = -100.0;
                  "rt_3" = 120.0;
                  "cr_3" = 4.0;
                  "kn_3" = -9.0;
                  "mk_3" = 5.0;
                  "bth_3" = -72.0;
                  "bsa_3" = 6.0;
                  "scs_3" = 0;
                  "scm_3" = 1;
                  "scr_3" = 10.0;
                  "sla_3" = 0.0;

                  # Bands 4–7: disabled
                  "cbe_4" = 0; "cbe_5" = 0; "cbe_6" = 0; "cbe_7" = 0;
                };
              }
              # 4. Stereo tools — subtle stereo widening
              {
                type = "lv2";
                plugin = "http://calf.sourceforge.net/plugins/StereoTools";
                name = "stereo";
                control = {
                  "stereo_base" = 0.3;
                };
              }
              # 5. Limiter — speaker protection, prevents clipping
              {
                type = "lv2";
                plugin = "http://lsp-plug.in/plugins/lv2/sc_limiter_stereo";
                name = "limiter";
                control = {
                  "mode" = 0;         # Herm Thin
                  "ovs" = 6;          # Half x4/24 bit
                  "dith" = 0;         # None
                  "lk" = 4.0;         # lookahead (ms)
                  "at" = 2.0;         # attack (ms)
                  "rt" = 8.0;         # release (ms)
                  "boost" = 1;        # gain boost: on
                  "slink" = 100.0;    # stereo link (%)
                  "th" = 0.0;         # threshold (dB)
                  "g_out" = 0.03;     # output gain (linear) — attenuates ~30 dB
                  "scp" = 0.0;        # sidechain preamp (dB)
                  "alr" = 0;          # ALR: off
                  "extsc" = 0;        # external sidechain: off
                };
              }
            ];
            links = [
              { output = "hpf:out_l"; input = "bass:in_l"; }
              { output = "hpf:out_r"; input = "bass:in_r"; }
              { output = "bass:out_l"; input = "mbcomp:in_l"; }
              { output = "bass:out_r"; input = "mbcomp:in_r"; }
              { output = "mbcomp:out_l"; input = "stereo:in_l"; }
              { output = "mbcomp:out_r"; input = "stereo:in_r"; }
              { output = "stereo:out_l"; input = "limiter:in_l"; }
              { output = "stereo:out_r"; input = "limiter:in_r"; }
            ];
          };
          "capture.props" = {
            "node.name" = "effect_input.fw16_speaker_dsp";
            "media.class" = "Audio/Sink";
            "audio.channels" = 2;
            "audio.position" = [ "FL" "FR" ];
          };
          "playback.props" = {
            "node.name" = "effect_output.fw16_speaker_dsp";
            "node.passive" = true;
            "node.target" = "alsa_output.pci-0000_c2_00.6.HiFi__Speaker__sink";
            "audio.channels" = 2;
            "audio.position" = [ "FL" "FR" ];
          };
        };
      }
    ];
  };
}
