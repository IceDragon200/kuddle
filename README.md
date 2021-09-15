# Kuddle

A KDL encoder and decoder for elixir.

## Version 1 when?

* When I feel the documentation is complete
* When I finally add line numbers for debugging
* When I finally add proper errors

Only then will I annoint kuddle with version 1.0.0.

## Installation

To add `kuddle` to your project:

```elixir
defp deps do
  [
    {:kuddle, "~> 0.2.1"},
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

Want to use KDL to configure your elixir next project?

Check out [kuddle_config](https://github.com/IceDragon200/kuddle_config)

## Test Cases

`test/fixtures/test_cases` contains a copy of the official language tests

## Known Issues

Some of the tests are still failing, mostly around parsing invalid values, since the parser is quite lax about the format of terms (the default value from the tokenizer)

## Supports

* [x] Nodes

```elixir
%Kuddle.Node{
  name: "node",
  annotations: [],
  attributes: [],
  children: [
    %Kuddle.Node{
      name: "node2",
      annotations: [],
      attributes: [],
      children: [
        %Kuddle.Node{
          name: "node3",
          annotations: [],
          attributes: [],
          children: nil,
        }
      ]
    }
  ]
} = Kuddle.decode("""
    node {
      node2 {
        node3
      }
    }
    """
  )
```

* [x] Annotations

```elixir
%Kuddle.Node{
  name: "node",
  annotations: ["root"],
  attributes: [],
  children: [
    %Kuddle.Node{
      name: "node2",
      annotations: [],
      attributes: [
        %Kuddle.Value{
          type: :integer,
          format: :dec,
          annotations: ["u8"],
          value: 23,
        }
      ],
      children: [
        %Kuddle.Node{
          name: "node3",
          annotations: [],
          attributes: [],
          children: nil,
        }
      ]
    }
  ]
} = Kuddle.decode("""
    (root)node {
      node2 (u8)23 {
        node3
      }
    }
    """
  )
```
