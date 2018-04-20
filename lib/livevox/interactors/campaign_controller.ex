defmodule Livevox.Interactors.CampaignContacts do
  require Logger
  import ShortMaps

  def check_for_updates do
    Logger.info("It's 1 after! Checking what to do")

    now = Timex.now("America/New_York")
    before = Timex.now() |> Timex.shift(minutes: -30)

    Livevox.CampaignControllerConfig.get_all()
    |> Enum.filter(&is_active_today/1)
    |> Enum.map(&should_run_now(&1, before))
    |> Enum.filter(&(&1 != :no_action))
    |> Enum.take(2)
    |> Enum.each(&run/1)
  end

  def is_active_today(~m(active_days)) do
    day = "#{Timex.now() |> Timex.weekday()}"
    String.split(active_days, ",") |> Enum.member?(day)
  end

  def should_run_now(~m(start_time end_time service_regex), before) do
    {start_hour, _} = Integer.parse(start_time)
    {end_hour, _} = Integer.parse(end_time)

    now = Timex.now("America/New_York")
    start_struct = now |> Timex.set(hour: start_hour, minute: 0)
    end_struct = now |> Timex.set(hour: end_hour, minute: 0)

    cond do
      Timex.after?(now, start_struct) and Timex.after?(start_struct, before) ->
        {:start, service_regex}

      Timex.after?(now, end_struct) and Timex.after?(end_struct, before) ->
        {:end, service_regex}

      true ->
        :no_action
    end
  end

  def run({:start, service}) do
    matching_services =
      Livevox.ServiceInfo.all_services()
      |> Enum.map(&{&1, Livevox.ServiceInfo.name_of(&1)})
      |> Enum.filter(fn {_, n} -> Regex.match?(service, String.downcase(n)) end)
      |> Enum.map(fn {id, _} -> ~m(id) end)

    %{body: ~m(campaign)} =
      Livevox.Api.post(
        "campaign/campaigns/search",
        body: %{
          service: %{service: matching_services},
          dateRange: %{
            from: Timex.now() |> Timex.shift(days: -5),
            to: Timex.now() |> Timex.shift(days: 5)
          },
          state: ~w(PAUSED)
        },
        query: %{offset: 0, count: 1000}
      )

    campaign
    |> Enum.map(fn ~m(id) -> id end)
    |> Enum.map(
      &Task.async(fn ->
        Livevox.Api.put("campaign/campaigns/#{&1}/state", body: %{state: "PLAY"})
      end)
    )
    |> Enum.map(&Task.await/1)
  end

  def run({:end, service}) do
    matching_services =
      Livevox.ServiceInfo.all_services()
      |> Enum.map(&{&1, Livevox.ServiceInfo.name_of(&1)})
      |> Enum.filter(fn {_, n} -> Regex.match?(service, String.downcase(n)) end)
      |> Enum.map(fn {id, _} -> ~m(id) end)

    %{body: ~m(campaign)} =
      Livevox.Api.post(
        "campaign/campaigns/search",
        body: %{
          service: %{service: matching_services},
          dateRange: %{
            from: Timex.now() |> Timex.shift(days: -5),
            to: Timex.now() |> Timex.shift(days: 5)
          },
          state: ~w(PLAYING)
        },
        query: %{offset: 0, count: 1000}
      )

    campaign
    |> IO.inspect()
    |> Enum.map(fn ~m(id) -> id end)
    |> Enum.map(
      &Task.async(fn ->
        Livevox.Api.get(
          "campaign/campaigns/#{&1}" |> IO.inspect()
          # body: %{state: "PAUSE"}
        )
        |> IO.inspect()

        Livevox.Api.put(
          "campaign/campaigns/#{&1}/state" |> IO.inspect(),
          body: %{state: "PAUSE"}
        )
        |> IO.inspect()

        Livevox.Api.put("campaign/campaigns/#{&1}/state", body: %{state: "STOP"})
        |> IO.inspect()
      end)
    )
    |> Enum.map(&Task.await/1)
    |> IO.inspect()
  end

  def run(:no_action) do
    Logger.info("No action")
  end
end
