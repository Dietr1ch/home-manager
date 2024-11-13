{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.programs.zellij;
  yamlFormat = pkgs.formats.yaml { };
  zellijCmd = getExe cfg.package;

in {
  meta.maintainers = [ hm.maintainers.mainrs ];

  options.programs.zellij = {
    enable = mkEnableOption "zellij";

    package = mkOption {
      type = types.package;
      default = pkgs.zellij;
      defaultText = literalExpression "pkgs.zellij";
      description = ''
        The zellij package to install.
      '';
    };

    settings = mkOption {
      type = yamlFormat.type;
      default = { };
      example = literalExpression ''
        {
          theme = "custom";
          themes.custom.fg = "#ffffff";
        }
      '';
      description = ''
        Configuration written to
        {file}`$XDG_CONFIG_HOME/zellij/config.kdl`.

        See <https://zellij.dev/documentation> for the full
        list of options.
      '';
    };
    extraConfig = lib.mkOption {
      description = ''
        Extra configuration lines to add to `$XDG_CONFIG_HOME/zellij/config.kdl`.

        This does not support zellij.yaml and it's mostly a workaround for https://github.com/nix-community/home-manager/issues/4659.
      '';
      type = lib.types.lines;
      default = "";
      example = ''
        keybinds {
            // keybinds are divided into modes
            normal {
                // bind instructions can include one or more keys (both keys will be bound separately)
                // bind keys can include one or more actions (all actions will be performed with no sequential guarantees)
                bind "Ctrl g" { SwitchToMode "locked"; }
                bind "Ctrl p" { SwitchToMode "pane"; }
                bind "Alt n" { NewPane; }
                bind "Alt h" "Alt Left" { MoveFocusOrTab "Left"; }
            }
            pane {
                bind "h" "Left" { MoveFocus "Left"; }
                bind "l" "Right" { MoveFocus "Right"; }
                bind "j" "Down" { MoveFocus "Down"; }
                bind "k" "Up" { MoveFocus "Up"; }
                bind "p" { SwitchFocus; }
            }
            locked {
                bind "Ctrl g" { SwitchToMode "normal"; }
            }
        }
      '';
    };

    enableBashIntegration = mkEnableOption "Bash integration" // {
      default = false;
    };

    enableZshIntegration = mkEnableOption "Zsh integration" // {
      default = false;
    };

    enableFishIntegration = mkEnableOption "Fish integration" // {
      default = false;
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Zellij switched from yaml to KDL in version 0.32.0:
    # https://github.com/zellij-org/zellij/releases/tag/v0.32.0
    xdg.configFile."zellij/config.yaml" = mkIf
      (cfg.settings != { } && (versionOlder cfg.package.version "0.32.0")) {
        source = (yamlFormat.generate "zellij.yaml" cfg.settings);
      };

    xdg.configFile."zellij/config.kdl" = mkIf
      (cfg.settings != { } && (versionAtLeast cfg.package.version "0.32.0")) {
        text = (lib.hm.generators.toKDL { } cfg.settings)
          + lib.optionalString (cfg.extraConfig != "") (''

            // extraConfig

          '' + cfg.extraConfig);
      };

    programs.bash.initExtra = mkIf cfg.enableBashIntegration (mkOrder 200 ''
      eval "$(${zellijCmd} setup --generate-auto-start bash)"
    '');

    programs.zsh.initExtra = mkIf cfg.enableZshIntegration (mkOrder 200 ''
      eval "$(${zellijCmd} setup --generate-auto-start zsh)"
    '');

    programs.fish.interactiveShellInit = mkIf cfg.enableFishIntegration
      (mkOrder 200 ''
        eval (${zellijCmd} setup --generate-auto-start fish | string collect)
      '');
  };
}
