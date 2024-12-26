# Kuddle

Kuddle is a [KDL v1 and v2](https://github.com/kdl-org/kdl) Encoder and Decoder library for Elixir.

## Installation (V2)

To add `kuddle` with v2 support to your project:

```elixir
defp deps do
  [
    {:kuddle, "~> 1.0.0"},
  ]
end
```

## Installation (legacy V1)

To add `kuddle` with original v1 to your project:

```elixir
defp deps do
  [
    {:kuddle, "~> 0.2.1"},
  ]
end
```

## Usage

```elixir
# Decode a KDL v2 document
{:ok, kdl_doc, []} = Kuddle.decode(kdl_blob)

# Encode a KDL v2 document
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

`test/fixtures/{v1,v2}/test_cases` contains a copy of the official language tests for their respective spec versions.

## Supports

* [x] Keywords

```elixir
{:ok, nodes, []} = Kuddle.decode("""
  node-true #true
  node-false #false
  node-null #null
  node-nan #nan
  node-inf #inf
  node--inf #-inf
  """
)

[
  %Kuddle.Node{
    name: "node-true",
    attributes: [
      %Kuddle.Value{
        type: :boolean,
        value: true
      }
    ]
  },
  %Kuddle.Node{
    name: "node-false",
    attributes: [
      %Kuddle.Value{
        type: :boolean,
        value: false
      }
    ]
  },
  %Kuddle.Node{
    name: "node-null",
    attributes: [
      %Kuddle.Value{
        type: :null,
        value: nil
      }
    ]
  },
  %Kuddle.Node{
    name: "node-nan",
    attributes: [
      %Kuddle.Value{
        type: :nan,
        value: :nan
      }
    ]
  },
  %Kuddle.Node{
    name: "node-inf",
    attributes: [
      %Kuddle.Value{
        type: :infinity,
        value: :infinity
      }
    ]
  },
  %Kuddle.Node{
    name: "node--inf",
    attributes: [
      %Kuddle.Value{
        type: :infinity,
        value: :'-infinity'
      }
    ]
  }
] = ndoes
```

* [x] Nodes

```elixir
{:ok, nodes, []} = Kuddle.decode("""
  node {
    node2 {
      node3
    }
  }
  """
)

[
  %Kuddle.Node{
    name: "node",
    children: [
      %Kuddle.Node{
        name: "node2",
        children: [
          %Kuddle.Node{
            name: "node3",
          }
        ]
      }
    ]
  }
] = ndoes
```

* [x] Annotations

```elixir
{:ok, nodes, []} = Kuddle.decode("""
  (root)node {
    node2 (u8)23 {
      node3
    }
  }
  """
)

[
  %Kuddle.Node{
    name: "node",
    annotations: ["root"],
    children: [
      %Kuddle.Node{
        name: "node2",
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
          }
        ]
      }
    ]
  }
] = nodes
```
