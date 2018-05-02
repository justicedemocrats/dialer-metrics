defmodule ScreenBoard.Jobs do
  import ShortMaps

  def revoke_and_share_all do
    [327_102]
    |> Enum.each(&revoke_and_share/1)
  end

  def revoke_and_share(board_id) do
    Dog.Api.delete("screen/share/#{board_id}")
    %{body: ~m(public_url)} = Dog.Api.post("screen/share/#{board_id}")

    HTTPotion.post(
      Application.get_env(:livevox, :on_new_dashboard_webhook),
      body: Poison.encode!(~m(public_url))
    )
  end

  def reconstruct_manager do
    ScreenBoard.Constructor.fill()
  end
end
