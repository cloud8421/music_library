%{
  configs: [
    %{
      name: "default",
      checks: %{
        extra: [
          {ExSlop.Check.Warning.BlanketRescue, []},
          {ExSlop.Check.Warning.RescueWithoutReraise, []},
          {ExSlop.Check.Warning.RepoAllThenFilter, []},
          {ExSlop.Check.Warning.QueryInEnumMap, []},
          {ExSlop.Check.Warning.GenserverAsKvStore, []},
          {ExSlop.Check.Warning.PathExpandPriv, []},
          {ExSlop.Check.Warning.DualKeyAccess, []},
          {ExSlop.Check.Refactor.FilterNil, []},
          {ExSlop.Check.Refactor.RejectNil, []},
          {ExSlop.Check.Refactor.ReduceAsMap, []},
          {ExSlop.Check.Refactor.MapIntoLiteral, []},
          {ExSlop.Check.Refactor.IdentityPassthrough, []},
          {ExSlop.Check.Refactor.IdentityMap, []},
          {ExSlop.Check.Refactor.CaseTrueFalse, []},
          {ExSlop.Check.Refactor.TryRescueWithSafeAlternative, []},
          {ExSlop.Check.Refactor.WithIdentityElse, []},
          {ExSlop.Check.Refactor.WithIdentityDo, []},
          {ExSlop.Check.Refactor.SortThenReverse, []},
          {ExSlop.Check.Refactor.StringConcatInReduce, []},
          {ExSlop.Check.Refactor.ReduceMapPut, []},
          {ExSlop.Check.Refactor.RedundantBooleanIf, []},
          {ExSlop.Check.Refactor.FlatMapFilter, []},
          {ExSlop.Check.Refactor.RedundantEnumJoinSeparator, []},
          {ExSlop.Check.Refactor.UseMapJoin, []},
          {ExSlop.Check.Refactor.PreferEnumSlice, []},
          {ExSlop.Check.Refactor.GraphemesLength, []},
          {ExSlop.Check.Refactor.ManualStringReverse, []},
          {ExSlop.Check.Refactor.SortThenAt, []},
          {ExSlop.Check.Refactor.SortForTopK, []},
          {ExSlop.Check.Refactor.ListFold, []},
          {ExSlop.Check.Refactor.LengthInGuard, []},
          {ExSlop.Check.Refactor.ExplicitSumReduce, []},
          {ExSlop.Check.Readability.NarratorDoc, []},
          {ExSlop.Check.Readability.DocFalseOnPublicFunction, []},
          {ExSlop.Check.Readability.BoilerplateDocParams, []},
          {ExSlop.Check.Readability.ObviousComment, [additional_keywords: []]},
          {ExSlop.Check.Readability.StepComment, []},
          {ExSlop.Check.Readability.NarratorComment, []},
          {ExSlop.Check.Readability.UnaliasedModuleUse, []},
          {Credo.Check.Refactor.Nesting, max_nesting: 3},
          {Credo.Check.Readability.ModuleDoc,
           ignore_names: [
             # Credo defaults
             ~r/(\.\w+Controller|\.Endpoint|\.\w+Live(\.\w+)?|\.Repo|\.Router|\.\w+Socket|\.\w+View|\.\w+HTML|\.\w+JSON|\.Telemetry|\.Layouts|\.Mailer)$/,
             # Custom: external API internals follow a three-module pattern
             # where only the facade needs documentation
             ~r/\.API(\..*)?$/,
             ~r/\.Config$/,
             # Custom: test support modules
             ~r/Fixtures/,
             # Custom: mix tasks
             ~r/^Mix\.Tasks\./
           ],
           ignore_modules_using: [
             # Credo defaults
             Credo.Check,
             Ecto.Schema,
             Phoenix.LiveView,
             ~r/\.Web$/,
             # Custom: LiveComponents and Oban workers are self-documenting
             Oban.Worker,
             # Matches `use MusicLibraryWeb, :live_component` etc.
             MusicLibraryWeb
           ]},
          {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 12}
        ],
        disabled: []
      }
      # files etc.
    }
  ]
}
