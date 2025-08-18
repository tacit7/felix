[
  import_deps: [:ecto, :ecto_sql, :phoenix],
  subdirectories: ["priv/repo/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],

  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}", "priv/repo/migrations/*.{ex,exs}"],
    line_length: 98,
    # Enable custom formatting options
    locals_without_parens: [
      # Config alignment
      config: 2,
      config: 3,
      # Other Phoenix-specific formatting
      plug: 1,
      plug: 2,
      get: 2,
      get: 3,
      post: 2,
      post: 3,
      put: 2,
      put: 3,
      delete: 2,
      delete: 3
    ]
  ]
]
