defmodule EngineSystem.System.Spawner.ValidatorTest do
  use ExUnit.Case, async: true

  alias EngineSystem.System.Spawner.Validator
  alias EngineSystem.Engine.Spec

  describe "validate_address/1" do
    test "accepts valid address format" do
      assert :ok = Validator.validate_address({1, 123})
      assert :ok = Validator.validate_address({0, 0})
      assert :ok = Validator.validate_address({999, 999_999})
    end

    test "rejects nil address" do
      assert {:error, :address_is_nil} = Validator.validate_address(nil)
    end

    test "rejects invalid address formats" do
      assert {:error, :invalid_address_format} = Validator.validate_address("invalid")
      assert {:error, :invalid_address_format} = Validator.validate_address({1})
      assert {:error, :invalid_address_format} = Validator.validate_address({1, 2, 3})
      assert {:error, :invalid_address_format} = Validator.validate_address({-1, 123})
      assert {:error, :invalid_address_format} = Validator.validate_address({1, -123})
      assert {:error, :invalid_address_format} = Validator.validate_address({"1", 123})
    end
  end

  describe "validate_spec/1" do
    test "accepts valid spec" do
      spec = Spec.new(:test_engine)
      assert :ok = Validator.validate_spec(spec)
    end

    test "rejects nil spec" do
      assert {:error, :spec_is_nil} = Validator.validate_spec(nil)
    end

    test "rejects non-spec structs" do
      assert {:error, :invalid_spec_type} = Validator.validate_spec(%{name: :test})
      assert {:error, :invalid_spec_type} = Validator.validate_spec("spec")
    end

    test "rejects spec with missing name" do
      spec = Spec.new(:test_engine)
      spec_with_nil_name = %{spec | name: nil}
      assert {:error, :spec_missing_name} = Validator.validate_spec(spec_with_nil_name)
    end

    test "rejects spec with missing version" do
      spec = Spec.new(:test_engine)
      spec_with_nil_version = %{spec | version: nil}
      assert {:error, :spec_missing_version} = Validator.validate_spec(spec_with_nil_version)
    end
  end

  describe "validate_engine_pid/1" do
    test "accepts valid alive process" do
      pid = spawn(fn -> :timer.sleep(100) end)
      assert :ok = Validator.validate_engine_pid(pid)
      Process.exit(pid, :kill)
    end

    test "rejects nil pid" do
      assert {:error, :engine_pid_is_nil} = Validator.validate_engine_pid(nil)
    end

    test "rejects non-pid values" do
      assert {:error, :invalid_engine_pid_type} = Validator.validate_engine_pid("not_a_pid")
      assert {:error, :invalid_engine_pid_type} = Validator.validate_engine_pid(123)
    end

    test "rejects dead process" do
      pid = spawn(fn -> :ok end)
      # Let process die
      :timer.sleep(10)
      assert {:error, :engine_process_dead} = Validator.validate_engine_pid(pid)
    end
  end

  describe "validate_mailbox_pid/1" do
    test "accepts nil (optional mailbox)" do
      assert :ok = Validator.validate_mailbox_pid(nil)
    end

    test "accepts valid alive process" do
      pid = spawn(fn -> :timer.sleep(100) end)
      assert :ok = Validator.validate_mailbox_pid(pid)
      Process.exit(pid, :kill)
    end

    test "rejects non-pid values" do
      assert {:error, :invalid_mailbox_pid_type} = Validator.validate_mailbox_pid("not_a_pid")
      assert {:error, :invalid_mailbox_pid_type} = Validator.validate_mailbox_pid(123)
    end

    test "rejects dead process" do
      pid = spawn(fn -> :ok end)
      # Let process die
      :timer.sleep(10)
      assert {:error, :mailbox_process_dead} = Validator.validate_mailbox_pid(pid)
    end
  end

  describe "validate_instance_name/1" do
    test "accepts nil (unnamed instance)" do
      assert :ok = Validator.validate_instance_name(nil)
    end

    test "accepts valid atom names" do
      assert :ok = Validator.validate_instance_name(:my_engine)
      assert :ok = Validator.validate_instance_name(:test)
    end

    test "rejects non-atom names" do
      assert {:error, :invalid_name_type} = Validator.validate_instance_name("string_name")
      assert {:error, :invalid_name_type} = Validator.validate_instance_name(123)
    end
  end

  describe "validate_registration_inputs/4" do
    test "accepts all valid inputs" do
      address = {1, 123}
      spec = Spec.new(:test_engine)
      engine_pid = spawn(fn -> :timer.sleep(100) end)
      mailbox_pid = spawn(fn -> :timer.sleep(100) end)

      assert :ok = Validator.validate_registration_inputs(address, spec, engine_pid, mailbox_pid)

      Process.exit(engine_pid, :kill)
      Process.exit(mailbox_pid, :kill)
    end

    test "accepts valid inputs with nil mailbox" do
      address = {1, 123}
      spec = Spec.new(:test_engine)
      engine_pid = spawn(fn -> :timer.sleep(100) end)

      assert :ok = Validator.validate_registration_inputs(address, spec, engine_pid, nil)

      Process.exit(engine_pid, :kill)
    end

    test "fails on first invalid input" do
      # Invalid address should fail first
      spec = Spec.new(:test_engine)
      engine_pid = spawn(fn -> :timer.sleep(100) end)

      assert {:error, :address_is_nil} =
               Validator.validate_registration_inputs(nil, spec, engine_pid, nil)

      Process.exit(engine_pid, :kill)
    end
  end

  describe "describe_error/1" do
    test "provides human-readable descriptions" do
      assert "Address is nil" = Validator.describe_error(:address_is_nil)

      assert "Address must be {node_id, engine_id} tuple" =
               Validator.describe_error(:invalid_address_format)

      assert "Instance name is already in use" =
               Validator.describe_error(:name_already_taken)
    end

    test "handles unknown errors" do
      assert ":unknown_error" = Validator.describe_error(:unknown_error)
    end
  end
end
