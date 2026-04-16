return {
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        providers = {
          lsp = {
            override = {
              get_trigger_characters = function(self)
                local trigger_characters = self:get_trigger_characters()

                if not vim.tbl_contains(trigger_characters, ".") then
                  table.insert(trigger_characters, ".")
                end

                return trigger_characters
              end,
            },
          },
        },
      },
    },
  },
}
