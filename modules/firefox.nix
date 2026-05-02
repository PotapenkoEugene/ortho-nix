{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    profiles."qc3gx0i7.default" = {
      id = 0;
      isDefault = true;
      settings = {
        "browser.startup.page" = 3;
        "privacy.sanitize.sanitizeOnShutdown" = false;
        "browser.startup.homepage_override.mstone" = "ignore";
      };
    };
  };
}
