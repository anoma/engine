defmodule EngineSystem.Examples.TopicEngineTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Tests for the example topic engine.

  TODO
  """

  setup do
    {:ok, _} = EngineSystem.start()
    :ok
  end

  describe "Pub/Sub Topic Engine" do
    test "spawns successfully" do
      {:ok, t_addr} = EngineSystem.spawn_engine(Examples.TopicEngine)
      {:ok, t_inst} = EngineSystem.lookup_t_instance(t_addr)

      assert t_inst.status == :running
      assert t_inst.engine_pid != nil
      assert t_inst.mailbox_pid != nil
    end

    test "can send & receive message" do
      {:ok, t_addr} = EngineSystem.spawn_engine(Examples.TopicEngine)

      :ok = EngineSystem.send_message(t_addr, {:new, %{}})
      :ok = EngineSystem.send_message(t_addr, {:pub, %{msg: {:test_msg}}})
      :ok = EngineSystem.send_message(t_addr, {:unsub, %{}})
      :ok = EngineSystem.send_message(t_addr, {:sub, %{}})
      :ok = EngineSystem.send_message(t_addr, {:pub, %{msg: {:test_msg}}})
      # Wait for processing
      Process.sleep(200)

      # Verify message was processed
      {:ok, t_inst} = EngineSystem.lookup_instance(t_addr)
      t_mbox = EngineSystem.Mailbox.MailboxRuntime.get_info(t_inst.mailbox_pid)

      assert t_mbox.environment.total_received == 5
      assert t_mbox.environment.total_delivered == 5
    end

    test "Replicated key-value store" do
      {:ok, t_addr} = EngineSystem.spawn_engine(Examples.TopicEngine)
      {:ok, s1_addr} = EngineSystem.spawn_engine(Examples.KVStoreEngine)
      {:ok, s2_addr} = EngineSystem.spawn_engine(Examples.KVStoreEngine)
      {:ok, s3_addr} = EngineSystem.spawn_engine(Examples.KVStoreEngine)

      :ok = EngineSystem.send_message(t_addr, {:new, %{}}, s1_addr)
      :ok = EngineSystem.send_message(t_addr, {:sub, %{}}, s2_addr)
      :ok = EngineSystem.send_message(t_addr, {:sub, %{}}, s3_addr)

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{key: :one, value: "foo"}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{key: :two, value: "bar"}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{key: :three, value: "baz"}}}},
          s2_addr
        )

      :ok = EngineSystem.send_message(s1_addr, {:get, %{key: :one}})
      :ok = EngineSystem.send_message(s1_addr, {:get, %{key: :two}})
      :ok = EngineSystem.send_message(s1_addr, {:get, %{key: :three}})

      :ok = EngineSystem.send_message(s2_addr, {:get, %{key: :one}})
      :ok = EngineSystem.send_message(s2_addr, {:get, %{key: :two}})
      :ok = EngineSystem.send_message(s2_addr, {:get, %{key: :three}})

      :ok = EngineSystem.send_message(s3_addr, {:get, %{key: :one}})
      :ok = EngineSystem.send_message(s3_addr, {:get, %{key: :two}})
      :ok = EngineSystem.send_message(s3_addr, {:get, %{key: :three}})

      Process.sleep(200)

      # Verify state of KV stores

      {:ok, s1_inst} = EngineSystem.lookup_instance(s1_addr)
      {:ok, s2_inst} = EngineSystem.lookup_instance(s2_addr)
      {:ok, s3_inst} = EngineSystem.lookup_instance(s3_addr)

      s1_state = EngineSystem.Engine.Instance.get_state(s1_inst.engine_pid)
      s2_state = EngineSystem.Engine.Instance.get_state(s2_inst.engine_pid)
      s3_state = EngineSystem.Engine.Instance.get_state(s3_inst.engine_pid)

      # Verify KV store content
      store = s1_state.environment.local_state.store
      assert Map.get(store, :one) == "foo"
      assert Map.get(store, :two) == "bar"
      assert Map.get(store, :three) == nil

      # Make sure all store contents are equal
      assert s1_state.environment.local_state == s2_state.environment.local_state
      assert s1_state.environment.local_state == s3_state.environment.local_state
    end

    test "Name store" do
      {:ok, t_addr} = EngineSystem.spawn_engine(Examples.TopicEngine)
      {:ok, s1_addr} = EngineSystem.spawn_engine(Examples.NameStoreEngine)
      {:ok, s2_addr} = EngineSystem.spawn_engine(Examples.NameStoreEngine)
      {:ok, s3_addr} = EngineSystem.spawn_engine(Examples.NameStoreEngine)

      :ok = EngineSystem.send_message(t_addr, {:new, %{}}, s1_addr)
      :ok = EngineSystem.send_message(t_addr, {:sub, %{}}, s2_addr)
      :ok = EngineSystem.send_message(t_addr, {:sub, %{}}, s3_addr)

      rec__a_0 =
         Examples.NameStoreEngine.Record.new("a", 0, "foo", 1, DateTime.utc_now(), "sig1")

      rec_x_a_1 =
        Examples.NameStoreEngine.Record.new("a", 1, "bar", 2, DateTime.utc_now(), "sig2")

      rec_x_a_2a =
        Examples.NameStoreEngine.Record.new("a", 2, "baaz", 2, DateTime.utc_now(), "sig3")

      rec_x_a_2 =
        Examples.NameStoreEngine.Record.new("a", 2, "baz", 2, DateTime.utc_now(), "sig3")

      rec_x_a_2c =
        Examples.NameStoreEngine.Record.new("a", 2, "buzz", 2, DateTime.utc_now(), "sig3")

      rec_y_b_1 =
        Examples.NameStoreEngine.Record.new("b", 1, "xxx", 4, DateTime.utc_now(), "sig4")

      rec_y_b_2 =
        Examples.NameStoreEngine.Record.new("b", 2, "yyy", 6, DateTime.utc_now(), "sig5")

      rec_z_b_0 =
        Examples.NameStoreEngine.Record.new("b", 0, "zzz", 3, DateTime.utc_now(), "sig6")

      zone = :test_zone

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "", record: rec__a_0}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "x", record: rec_x_a_1}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "x", record: rec_x_a_2a}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "x", record: rec_x_a_2}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "x", record: rec_x_a_2c}}}},
          s2_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "y", record: rec_y_b_1}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "y", record: rec_y_b_2}}}},
          s1_addr
        )

      :ok =
        EngineSystem.send_message(
          t_addr,
          {:pub, %{msg: {:put, %{zone: zone, label: "z", record: rec_z_b_0}}}},
          s1_addr
        )

      :ok = EngineSystem.send_message(s1_addr, {:get, %{zone: zone, label: "", type: "a"}})
      :ok = EngineSystem.send_message(s2_addr, {:get, %{zone: zone, label: "x", type: "a"}})
      :ok = EngineSystem.send_message(s3_addr, {:get, %{zone: zone, label: "y", type: "a"}})

      :ok =
        EngineSystem.send_message(t_addr, {:delete, %{zone: zone, label: "z", type: "b", id: 0}}, s1_addr)

      :ok =
        EngineSystem.send_message(t_addr, {:delete, %{zone: zone, label: "z", type: "b", id: 1}}, s1_addr)

      Process.sleep(200)

      # Verify state of KV stores
      {:ok, s1_inst} = EngineSystem.lookup_instance(s1_addr)
      {:ok, s2_inst} = EngineSystem.lookup_instance(s2_addr)
      {:ok, s3_inst} = EngineSystem.lookup_instance(s3_addr)

      s1_state = EngineSystem.Engine.Instance.get_state(s1_inst.engine_pid)
      s2_state = EngineSystem.Engine.Instance.get_state(s2_inst.engine_pid)
      s3_state = EngineSystem.Engine.Instance.get_state(s3_inst.engine_pid)

      # Verify KV store content
      store = s1_state.environment.local_state.store
      assert Map.get(store, "#{zone}||a|0") == rec__a_0
      assert Map.get(store, "#{zone}|x|a|1") == rec_x_a_1
      assert Map.get(store, "#{zone}|x|a|2") == rec_x_a_2
      assert Map.get(store, "#{zone}|y|b|1") == rec_y_b_1
      assert Map.get(store, "#{zone}|y|b|2") == rec_y_b_2
      assert Map.get(store, "#{zone}|z|b|0") == nil

      # Make sure all store contents are equal
      assert s1_state.environment.local_state == s2_state.environment.local_state
      assert s1_state.environment.local_state == s3_state.environment.local_state
    end
  end
end
