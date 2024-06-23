local_without_parens = [
  #
]

[
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}", "priv/repo/seeds.exs"],
  subdirectories: ["priv/repo/migrations"],
  import_deps: [:ecto],
  line_length: 100,
  locals_without_parens: local_without_parens,
  export: [local_without_parens: local_without_parens]
]
