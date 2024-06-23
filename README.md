# Ecto.PolyEmbeds

<img src="assets/logo-min-512.png"
      alt="Ecto PolyEmbeds Logo"
      align="left"
      width="56"
      height="56">
<p>
  <sub>
    A [non-official] Ecto library for using polymorphic
    <br/>
    embeds in Ecto Schemas and Changesets.
  </sub>
</p>
<br/>

See the complete documentation [at hexdocs](https://hexdocs.pm/ecto_poly_embeds).

## Installation

The package can be installed by adding `ecto_poly_embeds` to your list
of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_poly_embeds, "~> 0.0.1"}
  ]
end
```

## Getting started

### Accepting structs of a predefined set of schemas

Supose you have the embedded schemas `Circle` and `Rectangle` which
can be used as a `format` in an `Shape` schema. Both `Circle` and
`Rectangle` are just regular Ecto embedded schemas:

```elixir
defmodule Circle do
  use Ecto.Schema

  embedded_schema do
    field :radius, :decimal
  end
end

defmodule Rectangle do
  use Ecto.Schema

  embedded_schema do
    field :width, :decimal
    field :height, :decimal
  end
end
```

You can define the `Shape` schema as usual. Except, to make `format` a
polymorphic field, you need to `use Ecto.PolyEmbeds` in you're module
and then use `embeds_one` macro with some special options:

```elixir
defmodule Shape do
  use Ecto.Schema
  use Ecto.PolyEmbeds

  schema "shapes" do
    embeds_one :format, as: {:either, [Circle, Rectagle]}
    field :hexcolor, :string, default: "#000000"
  end
end
```

Notice the unfamiliar option `:as` provided to `embeds_one` macro.

`Ecto.PolyEmbeds` overrides Ecto Schema's `embeds_one` and `embeds_many`
macros. Whenever one of those is called with the option `as`,
`Ecto.PolyEmbeds` knowns you're defining a polymrphic embedded field.
Otherwise, if `as` isn't provided, then PolyEmbeds will defer to
`Ecto.Schema` to create the field.

Actually, in both cases `Ecto.PolyEmbeds` defers to `Ecto.Schema` for
defining the field, but if the `as` is provided then we'll add some
extra metadata to it.

> [!IMPORTANT]
> It's unlikely that `Ecto.PolyEmbeds` will break due to updating
> Ecto, but it is possible that a new major version of Ecto could
> break compatibility in the API for defining fields.

For the purpose of being more declarative, the given example value for
the `:as` field is a tuple where its first element is `:either`.

```elixir
embeds_one :format, as: {:either, [Circle, Rectagle]}
```

That makes it clear that the field `format` can only be either a
`Circle` or a `Rectangle`. Providing a value of a different schema
will raise an error.

Unfortunately, for now, the error will raise at runtime. So consider
this as an "let it crash" situation. Then you can either update your
parent schema to include the new shape, or make sure you only provide
one of the expected shapes. As the research for the Elixir typesystem
evolves, it might be possible to make this a compile-time error in the
future.

### Accepting many polymorphic structs in a field

As expected, `embeds_many` works exactly the same `embeds_one`, the
difference being that `embeds_many` will accept a list of structs.

```elixir
defmodule Shapeshifter do
  use Ecto.Schema
  use Ecto.PolyEmbeds

  schema "shapeshifters" do
    embeds_many :formats, as: {:either, [Circle, Rectangle]}
    field :hexcolor, :string, default: "#000000"
  end
end
```

### Accepting any schema

We've seen that's possible to constrain which schemas a polymorphic
field can accept, but it's also possible to accept any schema:

```elixir
defmodule Object do
  use Ecto.Schema
  use Ecto.PolyEmbeds

  schema "objects" do
    embeds_one :format, as: :any
    field :hexcolor, :string, default: "#000000"
  end
end
```

By settings `:as` to `:any`, the field `format` can accept a struct of
any `Ecto.Schema.t()`, be it an embedded schema or a regular schema.

```elixir
embeds_one :format, as: :any
```

For PolyEmbeds, it doesn't really matter if you constrain the field to
a set of schemas or not. It's possible though so that your code is
more declarative and less error-prone.

### Casting polymorphic fields in a Changeset

When using Changesets, you'll need to cast the polymorphic value of an
embedded field to its corresponding schema module and cast function.

That's easier for regular embeds because Ecto already known what the
schema module is, but you still need to point to the schema's cast
function when calling `cast_embedded/3` in your changeset. See example
below:

```elixir
defmodule Event do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :type, Ecto.Enum, values: [:login]
    field :data, :map, default: %{}
    field :timestamp, :utc_datetime_usec
  end

  def changeset(record \\ %Event{}, params)

  def changeset(%Event{} = record, %{} = params) do
    record
    |> cast(params, [:type, :data, :timestamp])
    |> validate_required([:type, :timestamp])
  end
end

defmodule ActivityLog do
  use Ecto.Schema

  import Ecto.Changeset

  schema "activity_logs" do
    belongs_to :user, User
    embeds_one :event, Event
    field :timestamp, :utc_datetime_usec
  end

  def changeset(record \\ %ActivityLog, params)

  def changeset(%ActivityLog{} = record, %{} = params) do
    record
    |> cast(params, [:user_id, :timestamp])
    |> cast_embedded(:event, with: &Event.changeset/2)
    |> validate_required([:user_id, :event, :timestamp])
  end
end
```

For polymorphic embeds though, you need to map the value to both its
corresponding schema and to its corresponding cast function. Next up
we'll see some ways to do that.

#### Mapping by a discriminator field

The simplest way to do that is by having a discriminator field in the
parent schema. For example, the `type` field:

```elixir
defmodule UserLoggedIn do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    belongs_to :user, User
    field :timestamp, :utc_datetime_usec
  end

  def changeset(record \\ %UserLoggedIn{}, params)

  def changeset(%UserLoggedIn{} = record, params) do
    record
    |> cast(params, [:user_id, :timestamp])
    |> validate_required([:user_id, :timestamp])
  end
end

defmodule UserEmailUpdated do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    belongs_to :user, User
    field :old_email, :string
    field :new_email, :string
    field :timestamp, :utc_datetime_usec
  end

  def changeset(record \\ %UserEmailUpdated{}, params)

  def changeset(%UserEmailUpdated{} = record, params) do
    record
    |> cast(params, [:user_id, :old_email, :new_email, :timestamp])
    |> validate_required([:user_id, :old_email, :new_email, :timestamp])
  end
end

defmodule ActivityLog do
  use Ecto.Schema
  use Ecto.PolyEmbeds

  schema "activity_logs" do
    belongs_to :user, User
    field :type, Ecto.Enum, values: [:user_logged_in, :user_email_updated]

    embeds_one :event,
      as: {:either, [UserLoggedIn, UserEmailUpdated]},
      with: mapped_by(:type, [
        user_logged_in: UserLoggedIn,
        user_email_updated: UserEmailUpdated
      ])

    field :timestamp, :utc_datetime_usec
  end

  def changeset(record \\ %ActivityLog{}, params)

  def changeset(%ActivityLog{} = record, %{} = params) do
    record
    |> cast(params, [:user_id, :type, :timestamp])
    # ...
    |> cast_embedded(:event)
  end
end
```

The default cast function is `changeset/2` that should be defined in
the polymorphic embedded's schema module. If that convention works for
you, then you only need to map the `type` to its corresponding
schema module using the `mapped_by/2` macro like in the example.

```elixir
embeds_one :event,
  as: {:either, [UserLoggedIn, UserEmailUpdated]},
  with: mapped_by(:type, [
    user_logged_in: UserLoggedIn,
    user_email_updated: UserEmailUpdated
  ])
```

But if your function is named differently or if it's in a different
module, then you'll need to map both the schema module and the cast
function:

```elixir
embeds_one :event,
  as: {:either, [UserLoggedIn, UserEmailUpdated]},
  with: mapped_by(:type, [
    user_logged_in: {UserLoggedIn, &UserLoggedIn.changeset/2},
    user_email_updated: {UserEmailUpdated, &UserEmailUpdated.changeset/2}
  ])
```

Alternatively, you can provide a resolver function that maps the
`type` to its corresponding schema module and cast function:

```elixir
defp resolve_by_type(:user_logged_in), do: {:ok, UserLoggedIn}
defp resolve_by_type(:user_email_updated), do: {:ok, {UserEmailUpdated, &UserEmailUpdated.changeset/2}}
defp resolve_by_type(_type), do: {:error, "unknown event type"}

# ...

embeds_one :event,
  as: {:either, [UserLoggedIn, UserEmailUpdated]},
  with: mapped_by(:type, &resolve_by_type/1)
```

Your resolver function must return an `:ok|:error` result tuple. Don't
forget to handle the case where the `type` doesn't match any of the
expected values, returning an error tuple with an error message. This
error message will be made available in the changeset errors for the
polymorphic field.

```elixir
def resolve_by_type(_type), do: {:error, "unknown event type"}
```

#### Mapping by value

Another way of mapping the schema module and cast function is using a
custom function that, for example, can pattern match on the inputted
value of the polymorphic field:

```elixir
defmodule Circle do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_scheam do
    field :radius, :decimal
  end

  def changeset(record \\ %Circle{}, params)

  def changeset(%Circle{} = record, %{} = params) do
    record
    |> cast(params, [:radius])
    # ...
  end
end

defmodule Rectangle do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :width, :decimal
    field :height, :decimal
  end

  def changeset(record \\ %Rectangle{}, params)

  def changeset(%Rectangle{} = record, %{} = params) do
    record
    |> cast(params, [:width, :height])
    # ...
  end
end

defmodule Shape do
  use Ecto.Schema

  import Ecto.Changeset

  defp resolve_shape(%{radius: _}), do: {:ok, Circle}
  defp resolve_shape(%{width: _, height: _}), do: {:ok, {Rectangle, &Rectangle.changeset/2}}
  defp resolve_shape(_shape), do: {:error, "unknown shape"}

  embedded_schema do
    field :hexcolor, :string, default: "#000000"
    embeds_one :format, as: :any, with: custom_resolver(&resolve_shape/1)
  end

  def changeset(record \\ %Shape{}, params)

  def changeset(%Shape{} = record, %{} = params) do
    record
    |> cast(params, [:hexcolor])
    # ...
    |> cast_embedded(:format)
    # ...
  end
end
```

Just like when using a discriminator field, if your cast function is
named `changeset/2` and it's defined in the schema module, your custom
resolver function could return just the schema module:

```elixir
def resolve_shape(%{radius: _}), do: {:ok, Circle}
```

Otherwise, you must return both the schema module and the cast
function:

```elixir
def resolve_shape(%{width: _, height: _}), do: {:ok, {Rectangle, &Rectangle.changeset/2}}
```

And don't forget to handle the case where the shape doesn't match any
of the expected patterns, returning an error tuple with an error
message:

```elixir
def resolve_shape(_shape), do: {:error, "unknown shape"}
```

If your custom resolver function has arity 2, then you'll have access
to both the polymorphic embedded field's inputted value and its parent
changeset:

```elixir
defmodule Shape do
  use Ecto.Schema

  defp resolve_shape(%{radius: _}, _changeset), do: {:ok, Circle}
  defp resolve_shape(%{width: _, height: _}, _changeset), do: {:ok, {Rectangle, &Rectangle.changeset/2}}
  defp resolve_shape(_shape, _changeset), do: {:error, "unknown shape"}

  embedded_schema do
    field :hexcolor, :string, default: "#000000"
    embeds_one :format, as: :any, with: custom_resolver(&resolve_shape/2)
  end
end
```

#### Dynamically mapping

Alternativelly to mapping the polymorphic value to its schema and cast
function when defining the schema, you can also map/override the
mapping when calling `cast_embedded/3` in the changeset.

In the keyword list options, at the 3rd argument to `cast_embedded/3`,
you can provide the `with`. It accepts the same values as the `with`
option we've seen in the schema definition.

This is the intended place the use the `definitely/1` function, that
we haven't seen yet. It's useful when you resolve the schema somewhere
else, then you explicitly tells PolyEmbeds which schema is it:

```elixir
def changeset_circle(%Shape{} = record, %{} = params) do
  record
  |> cast(params, [:hexcolor])
  # ...
  |> cast_embedded(:format, with: definitely(Circle))
end

# OR

def changeset_rectangle(%Shape{} = record, %{} = params) do
  record
  |> cast(params, [:hexcolor])
  # ...
  |> cast_embedded(:format, with: definitely({Rectangle, &Rectangle.changeset/2}))
end
```

Here's some examples using the values for `with` option that we've
seen before.

Using `mapped_by/2` with a discriminator field:

```elixir
changeset
# ...
|> cast_embedded(:format, with: mapped_by(:type, [
  user_logged_in: UserLoggedIn,
  user_email_updated: {UserEmailUpdated, &UserEmailUpdated.changeset/2}
]))
```

Using `mapped_by/2` with a discriminator field and a custom resolver
function:

```elixir
def changeset(%Shape{} = record, %{} = params) do
  record
  |> cast(params, [:type, :hexcolor])
  # ...
  |> cast_embedded(:format, with: mapped_by(:type, &resolve_by_type/1))
end

defp resolve_by_type(:user_logged_in), do: {:ok, UserLoggedIn}
defp resolve_by_type(:user_email_updated), do: {:ok, {UserEmailUpdated, &UserEmailUpdated.changeset/2}}
defp resolve_by_type(_type), do: {:error, "unknown event type"}
```

Using `custom_resolver/1` macro with an arity 1 function:

```elixir
def changeset(%Shape{} = record, params) do
  record
  |> cast(params, [:hexcolor])
  # ...
  |> cast_embedded(:format, with: custom_resolver(&resolve_shape/1))
end

defp resolve_shape(%{radius: _}), do: {:ok, Circle}
defp resolve_shape(%{width: _, height: _}), do: {:ok, {Rectangle, &Rectangle.changeset/2}}
defp resolve_shape(_shape), do: {:error, "unknown shape"}
```

And with `custom_resolver/1` with an arity 2 function which will
have access to both the polymorphic field's inputted value and its
parent changeset:

```elixir
def changeset(%Shape{} = record, params) do
  record
  |> cast(params, [:hexcolor])
  # ...
  |> cast_embedded(:format, with: custom_resolver(&resolve_shape/2))
end

defp resolve_shape(%{radius: _}, _changeset), do: {:ok, Circle}
defp resolve_shape(%{width: _, height: _}, _changeset), do: {:ok, {Rectangle, &Rectangle.changeset/2}}
defp resolve_shape(_shape, _changeset), do: {:error, "unknown shape"}
```

---

For more details, please defer to the full documentation [at hexdocs](https://hexdocs.pm/ecto_poly_embeds).
