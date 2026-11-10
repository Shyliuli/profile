-- ShyProject coding profile.
--
-- Plain Neovim: no plugin manager, no downloaded plugins. Startup is a few
-- milliseconds and nothing parses the buffer except the ShyC language server,
-- which is why this profile is comfortable on battery.
require("shycode").setup()
