# Kuddle

A KDL encoder and decoder for elixir.

## Installation

To add `kuddle` to your project:

```elixir
defp deps do
  [
    {:kuddle, "~> 0.1.0"},
  ]
end
```

## Usage

```elixir
# Decode a KDL document
{:ok, kdl_doc, _rest} = Kuddle.decode(kdl_blob)

# Encode a KDL document
{:ok, kdl_blob} = Kuddle.encode(kdl_doc)

# Lookup nodes in a document
nodes = Kuddle.select(kdl_doc, ["node name"])
nodes = Kuddle.select(kdl_doc, [{:attr, "attribute name"}])
nodes = Kuddle.select(kdl_doc, [{:attr, "attribute name", "attribute value"}])
nodes = Kuddle.select(kdl_doc, [{:value, "value"}])
```

## Test Cases

`test/fixtures/test_cases` contains a copy of the official language tests

## Known Issues

Some of the tests are still failing, mostly around parsing invalid values, since the parser is quite lax about the format of terms (the default value from the tokenizer)

## Supports

* [x] Node

```elixir
Kuddle.decode("""
node {
  node2 {
    node3
  }
}
""")
```
