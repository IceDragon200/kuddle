defmodule Kuddle.Path do
  @moduledoc """
  Utility module for looking up nodes in a document.

  Usage:

      nodes = Kuddle.select(document, path)

      [{:node, "node", attrs, children}] = Kuddle.select(document, ["node"])

  """
  alias Kuddle.Value
  alias Kuddle.Node

  @typedoc """
  A Kuddle document is a list of nodes, nothing fancy.
  """
  @type document :: Kuddle.Decoder.document()

  @typedoc """
  A single node in a document
  """
  @type document_node :: Kuddle.Decoder.document_node()

  @typedoc """
  Node names are strings
  """
  @type node_name :: String.t()

  @typedoc """
  An attribute key (i.e. %Value{}) can be anything, normally it will be an id or string though
  """
  @type attr_key :: any()

  @typedoc """
  An attribute value can be anything
  """
  @type attr_value :: any()

  @type attribute_path :: {:attr, attr_key()}
                        | {:attr, attr_key(), attr_value()}
                        | {:value, attr_value()}

  @typedoc """
  In addition to the attribute_path, node attributes can also use shorthands for
  `{:attr, key, value}` and `{:value, value}`, as `{key, value}` and `value` respectively.
  """
  @type node_attributes :: [attribute_path() | {any(), any()} | any()]

  @typedoc """
  Any single path selector
  """
  @type selector :: node_name()
                  | attribute_path()
                  | {:node, node_name()}
                  | {:node, node_name(), node_attributes()}

  @typedoc """
  A path is a list of selectors that should be used when matching against the document.

  It allows different fragments which can be used to match different properties of the node.

  Fragments:
  * `node_name` - the node name can be passed as a plain string in the path to select a node based on its name

    Example:

        [%Kuddle.Node{name: "node"}] = Kuddle.select(document, ["node"])
        [] = Kuddle.select(document, ["doesnt_exist"])

  * `{:attr, key}` - a node with an attribute key can be looked up as well, this will ignore the
                     value and only look for key value pairs with the key

    Example:

        [%Kuddle.Node{attributes: [{%{value: "id"}, _value}]}] = Kuddle.select(document, [{:attr, "id"}])
        [] = Kuddle.select(document, [{:attr, "cid"}])

  * `{:attr, key, value}` - an attribute of key and value can be looked up as well

    Example:

        [%Kuddle.Node{attributes: [{%{value: "id"}, %{value: "egg"}}]}] = Kuddle.select(document, [{:attr, "id", "egg"}])
        [] = Kuddle.select(document, [{:attr, "cid", "8847"}])

  * `{:value, value}` - for nodes with normal values, the loose value can be looked up as well

    Example:

        [%Kuddle.Node{attributes: [%{value: 1}]}] = Kuddle.select(document, [{:value, 1}])
        [] = Kuddle.select(document, [{:value, 2}])

  * `{:node, node_name}` - equivalent to just providing the `node_name`

    Example:

        [%Kuddle.Node{name: "node"}] = Kuddle.select(document, [{:node, "node"}])
        [] = Kuddle.select(document, [{:node, "doesnt_exist"}])

  * `{:node, node_name, attrs}` - lookup a node with attributes

    Example:

        [%Kuddle.Node{name: "node", attributes: [1]}] = Kuddle.select(document, [{:node, "node", [1]}])
        [%Kuddle.Node{name: "node", attributes: [1]}] = Kuddle.select(document, [{:node, "node", [{:value, 1}]}])
        [%Kuddle.Node{name: "node2", attributes: [{%{value: "id"}, _value}]}] = Kuddle.select(document, [{:node, "node2", [{:attr, "id"}]}])
        [%Kuddle.Node{name: "node3", attributes: [{%{value: "id"}, %{value: "bacon"}}]}] = Kuddle.select(document, [{:node, "node3", [{:attr, "id", "bacon"}]}])
        [%Kuddle.Node{name: "node3", attributes: [{%{value: "id"}, %{value: "bacon"}}]}] = Kuddle.select(document, [{:node, "node3", [{"id", "bacon"}]}])
        [] = Kuddle.select(document, [{:node, "node3", [{"id", "fries"}]}])

  """
  @type path :: [selector()]

  @doc """
  Select nodes from the given kuddle document, see the path type for the supported selectors

  Args:
  * `document` - the document to lookup, or nil
  * `path` - the selectors to use when looking up the nodes
  * `acc` - the current accumulator, defaults to an empty list
  """
  @spec select(nil | document(), path(), list()) :: document()
  def select(document, path, acc \\ [])

  def select(nil, _, acc) do
    Enum.reverse(acc)
  end

  def select([], [], acc) do
    Enum.reverse(acc)
  end

  def select([item | rest], [] = path, acc) do
    select(rest, path, [item | acc])
  end

  def select([%Node{children: children} = node | rest], [expected | _path] = path, acc) do
    acc =
      if match_node?(node, expected) do
        [node | acc]
      else
        acc
      end

    acc = select(children, [expected], acc)

    select(rest, path, acc)
  end

  def select([], [_expected | path], acc) do
    select(Enum.reverse(acc), path, [])
  end

  @spec match_node?(document_node(), selector()) :: boolean()
  defp match_node?(%Node{attributes: attrs}, {:attr, _key} = attr) do
    Enum.any?(attrs, &match_attr?(&1, attr))
  end

  defp match_node?(%Node{attributes: attrs}, {:attr, _key, _value} = attr) do
    Enum.any?(attrs, &match_attr?(&1, attr))
  end

  defp match_node?(%Node{name: name}, {:node, name}) do
    true
  end

  defp match_node?(%Node{name: name} = node, {:node, name, expected_attrs}) do
    Enum.all?(expected_attrs, fn
      {:attr, _} = attr ->
        match_node?(node, attr)

      {:attr, _, _} = attr ->
        match_node?(node, attr)

      {:value, _} = attr ->
        match_node?(node, attr)

      {key, value} ->
        match_node?(node, {:attr, key, value})

      value ->
        match_node?(node, {:value, value})
    end)
  end

  defp match_node?(%Node{attributes: attrs}, {:value, _value} = attr) do
    Enum.any?(attrs, &match_attr?(&1, attr))
  end

  defp match_node?(%Node{name: name}, name) do
    true
  end

  defp match_node?(%Node{}, _) do
    false
  end

  defp match_attr?(%Value{}, {:attr, _key}) do
    false
  end

  defp match_attr?(%Value{}, {:attr, _key, _value}) do
    false
  end

  defp match_attr?(%Value{value: value}, {:value, value}) do
    true
  end

  defp match_attr?(%Value{}, {:value, _}) do
    false
  end

  defp match_attr?({_key, _value}, {:value, _}) do
    false
  end

  defp match_attr?({%Value{value: key}, _value}, {:attr, expected_key}) do
    key == expected_key
  end

  defp match_attr?({%Value{value: key}, %Value{value: value}}, {:attr, expected_key, expected_value}) do
    key == expected_key and
    value == expected_value
  end
end
