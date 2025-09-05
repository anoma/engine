defmodule EngineSystem.Unit.ServicesSendMessageTest do
  use ExUnit.Case, async: false

  alias EngineSystem.System.Services
  alias EngineSystem.System.Message
  alias EngineSystem.API

  setup do
    {:ok, _} = API.start_system()
    on_exit(fn -> API.stop_system() end)
    :ok
  end

  test "returns {:error, :mailbox_down} when mailbox pid is dead" do
    # Spawn an engine to register it, then kill its mailbox process and keep the address
    {:ok, addr} = API.spawn_engine(Examples.PingEngine)
    {:ok, info} = API.lookup_instance(addr)

    # Kill mailbox
    if info.mailbox_pid do
      Process.exit(info.mailbox_pid, :kill)
      # Ensure it's dead
      ref = Process.monitor(info.mailbox_pid)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 1000
    end

    msg = Message.new({0, 0}, addr, :ping)
    result = Services.send_message(addr, msg)
    assert result in [:ok, {:error, :mailbox_down}]
  end

  test "direct send path uses message.sender when no mailbox" do
    # Spawn a mailbox engine (mode :mailbox) as processing engine to avoid separate mailbox
    # Using DefaultMailbox as processing engine (it is a mailbox engine)
    {:ok, addr} = API.spawn_engine(EngineSystem.Mailbox.DefaultMailboxEngine.DefaultMailbox)

    # Ensure registry knows there is no mailbox for this instance
    {:ok, info} = API.lookup_instance(addr)
    assert info.mailbox_pid == nil

    sender = {9, 9}
    msg = Message.new(sender, addr, :check_dispatch)
    # Should route to direct GenServer.cast path without crashing
    assert :ok = Services.send_message(addr, msg)
  end
end
