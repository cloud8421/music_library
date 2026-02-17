%{
  configs: [
    %{
      name: "default",
      checks: %{
        disabled: [
          {Credo.Check.Refactor.CyclomaticComplexity, []},
          {Credo.Check.Refactor.Nesting, []},
          {Credo.Check.Readability.ModuleDoc, []}
        ]
      }
      # files etc.
    }
  ]
}
