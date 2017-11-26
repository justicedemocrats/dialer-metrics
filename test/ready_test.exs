defmodule ReadyText do
  use ExUnit.Case
  alias Livevox.{AgentHandler}

  test "increments ready count" do
    Enum.each(
      [
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_011_435,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713162812:seq=180",
          "eventType" => "LOGON",
          "seqNum" => 180,
          "timestamp" => 1_511_713_162_812
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_008_452,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713355835:seq=189",
          "eventType" => "NOT_READY",
          "lineNumber" => "DIRECT",
          "seqNum" => 189,
          "timestamp" => 1_511_713_355_835
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_011_435,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713162812:seq=181",
          "eventType" => "NOT_READY",
          "lineNumber" => "ACD",
          "seqNum" => 181,
          "timestamp" => 1_511_713_162_812
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_008_452,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713358850:seq=190",
          "eventType" => "READY",
          "lineNumber" => "DIRECT",
          "seqNum" => 190,
          "timestamp" => 1_511_713_358_850
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_008_452,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713358850:seq=190",
          "eventType" => "READY",
          "lineNumber" => "ACD",
          "seqNum" => 190,
          "timestamp" => 1_511_713_358_850
        }
      ],
      &AgentHandler.handle_agent_event/1
    )

    assert Livevox.AgentState.ready_count() == 1
    Livevox.AgentState.reset()
  end

  test "ignoring direct in ready count" do
    Enum.each(
      [
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_011_435,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713162812:seq=180",
          "eventType" => "LOGON",
          "seqNum" => 180,
          "timestamp" => 1_511_713_162_812
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_008_452,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713355835:seq=189",
          "eventType" => "NOT_READY",
          "lineNumber" => "DIRECT",
          "seqNum" => 189,
          "timestamp" => 1_511_713_355_835
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_011_435,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713162812:seq=181",
          "eventType" => "NOT_READY",
          "lineNumber" => "ACD",
          "seqNum" => 181,
          "timestamp" => 1_511_713_162_812
        },
        %{
          "agentId" => 1_035_672,
          "agentServiceId" => 1_008_452,
          "agentTeamId" => 1_011_482,
          "clientId" => 1_007_808,
          "eventId" => "cid=1007808:aid=1035672:time=1511713358850:seq=190",
          "eventType" => "READY",
          "lineNumber" => "DIRECT",
          "seqNum" => 190,
          "timestamp" => 1_511_713_358_850
        }
      ],
      &AgentHandler.handle_agent_event/1
    )

    assert Livevox.AgentState.ready_count() == 0
    Livevox.AgentState.reset()
  end
end
