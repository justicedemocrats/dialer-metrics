defmodule ScreenBoard.Constructor do
  import ShortMaps
  require Logger

  @x_base 40
  @x_step 27

  @y_base 18
  @y_step 36

  @row_length 8

  def fill do
    active_services =
      Livevox.CampaignControllerConfig.get_all()
      |> Enum.filter(fn ~m(start_time end_time) ->
        current_est_hours = Timex.now("America/New_York").hour
        current_est_hours >= start_time and current_est_hours <= end_time
      end)

    board =
      base()
      |> Map.update!("widgets", fn widgets ->
        active_services
        |> Enum.with_index()
        |> Enum.reduce(widgets, fn {~m(candidate service_name), n}, acc ->
          x = rem(n, @row_length)
          y = Float.floor(n / @row_length)

          Enum.concat(
            acc,
            widget_group(%{
              y: @y_base + @y_step * y,
              x: @x_base + @x_step * x,
              service_base: service_name,
              title: "#{String.upcase(service_name)}: #{candidate}"
            })
          )
        end)
      end)

    Dog.Api.put("screen/327102", body: board)
    Logger.info("Updated dialer managers board")
  end

  def base do
    %{
      "board_bgtype" => "board_graph",
      "board_title" => "Dialer Managers Auto-Fill",
      "disableCog" => false,
      "disableEditing" => false,
      "templated" => true,
      "title_edited" => false,
      "widgets" => [
        %{
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "requests" => [
              %{
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_green", "value" => 0}
                ],
                "q" => "top(sum:count_logged_on{*} by {service}, 5, 'last', 'desc')",
                "style" => %{"palette" => "dog_classic"}
              }
            ],
            "viz" => "toplist"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "Agents Logged In",
          "type" => "toplist",
          "width" => 28,
          "x" => 1,
          "y" => 4
        },
        %{
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "requests" => [
              %{
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_red", "value" => 120},
                  %{"comparator" => ">", "palette" => "white_on_yellow", "value" => 120},
                  %{"comparator" => "<", "palette" => "white_on_green", "value" => 120}
                ],
                "q" => "top(avg:wait_time{*} by {service}, 50, 'mean', 'desc')",
                "style" => %{"palette" => "dog_classic"}
              }
            ],
            "viz" => "toplist"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "Live Avg Wait Time",
          "type" => "toplist",
          "width" => 28,
          "x" => 136,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 5,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "custom_unit" => "%",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                  %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                  %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
                ],
                "q" =>
                  "(sum:call_count_5{dropped}/(sum:call_count_5{contact}+sum:call_count_5{dropped}))*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "5m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 13,
          "title_text" => "5m",
          "type" => "query_value",
          "width" => 12,
          "x" => 53,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "yellow_on_white", "value" => "0"},
                  %{"comparator" => "<=", "palette" => "red_on_white", "value" => "0"}
                ],
                "q" => "sum:count_ready{service:dialer_monitor}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "Monitors",
          "type" => "query_value",
          "width" => 9,
          "x" => 21,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 5,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "custom_unit" => "%",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                  %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                  %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
                ],
                "q" =>
                  "(sum:call_count_60{dropped}/(sum:call_count_60{contact}+sum:call_count_60{dropped}))*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1h",
          "title" => true,
          "title_align" => "left",
          "title_size" => 13,
          "title_text" => "1hr",
          "type" => "query_value",
          "width" => 12,
          "x" => 53,
          "y" => 11
        },
        %{
          "board_id" => 288_880,
          "color" => "#4d4d4d",
          "font_size" => "36",
          "height" => 3,
          "isShared" => false,
          "text" => "Agents",
          "text_align" => "left",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "",
          "type" => "free_text",
          "width" => 14,
          "x" => 1,
          "y" => 1
        },
        %{
          "board_id" => 288_880,
          "color" => "#4d4d4d",
          "font_size" => "36",
          "height" => 4,
          "isShared" => false,
          "text" => "Drop Rate",
          "text_align" => "left",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "",
          "type" => "free_text",
          "width" => 17,
          "x" => 40,
          "y" => 0
        },
        %{
          "board_id" => 288_880,
          "color" => "#4d4d4d",
          "font_size" => "36",
          "height" => 4,
          "isShared" => false,
          "text" => " Calls in Progress  ",
          "text_align" => "left",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "",
          "type" => "free_text",
          "width" => 29,
          "x" => 202,
          "y" => 0
        },
        %{
          "board_id" => 288_880,
          "color" => "#4d4d4d",
          "font_size" => "36",
          "height" => 4,
          "isShared" => false,
          "text" => "Wait Time ",
          "text_align" => "left",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "",
          "type" => "free_text",
          "width" => 20,
          "x" => 126,
          "y" => 0
        },
        %{
          "board_id" => 288_880,
          "height" => 21,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "requests" => [
              %{
                "aggregator" => "avg",
                "conditional_formats" => [],
                "q" =>
                  "(sum:call_count_today{dropped} by {service_name}/(sum:call_count_today{contact}+sum:call_count_today{dropped} by {service_name}))*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => "area"
              }
            ],
            "viz" => "timeseries"
          },
          "timeframe" => "4h",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "Drops/Contacted (daily percentage)",
          "type" => "timeseries",
          "width" => 38,
          "x" => 0,
          "y" => 21
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 5,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "custom_unit" => "%",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                  %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                  %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
                ],
                "q" =>
                  "(sum:call_count_30{dropped}/(sum:call_count_30{contact}+sum:call_count_30{dropped}))*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "30m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 13,
          "title_text" => "30m",
          "type" => "query_value",
          "width" => 13,
          "x" => 40,
          "y" => 11
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 5,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "custom_unit" => "%",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                  %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                  %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
                ],
                "q" =>
                  "(sum:call_count_1{dropped}/(sum:call_count_1{contact}+sum:call_count_1{dropped}))*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 13,
          "title_text" => "1m",
          "type" => "query_value",
          "width" => 13,
          "x" => 40,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 5,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "custom_unit" => "",
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">=", "palette" => "white_on_green", "value" => "0"}
                ],
                "q" => "(sum:count_active{*}-sum:count_active{service:dialer_monitor})",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "Active",
          "type" => "query_value",
          "width" => 8,
          "x" => 30,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 5,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "custom_unit" => "",
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">=", "palette" => "white_on_red", "value" => "0"}
                ],
                "q" => "(sum:count_not_ready{*}-sum:count_not_ready{service:dialer_monitor})",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "Not Ready",
          "type" => "query_value",
          "width" => 8,
          "x" => 30,
          "y" => 11
        },
        %{
          "board_id" => 288_880,
          "color" => "#4d4d4d",
          "font_size" => "16",
          "height" => 3,
          "isShared" => false,
          "text" => "Available Agents",
          "text_align" => "left",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "",
          "type" => "free_text",
          "width" => 10,
          "x" => 30,
          "y" => 1
        },
        %{
          "board_id" => 288_880,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "requests" => [
              %{
                "aggregator" => "avg",
                "conditional_formats" => [],
                "q" => "sum:cip{*} by {service}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => "area"
              }
            ],
            "viz" => "timeseries"
          },
          "timeframe" => "4h",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "(4hrs x # calls in progress by service)",
          "type" => "timeseries",
          "width" => 38,
          "x" => 202,
          "y" => 4
        },
        %{
          "board_id" => 288_880,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "markers" => [
              %{
                "dim" => "y",
                "max" => 180,
                "min" => 120,
                "type" => "warning dashed",
                "value" => "120 < y < 180"
              },
              %{
                "dim" => "y",
                "max" => nil,
                "min" => 180,
                "type" => "error dashed",
                "value" => "y > 180"
              }
            ],
            "requests" => [
              %{
                "aggregator" => "avg",
                "conditional_formats" => [],
                "q" => "avg:wait_time{*} by {service}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => "line"
              }
            ],
            "viz" => "timeseries"
          },
          "timeframe" => "1h",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "Avg Wait Time per Service",
          "type" => "timeseries",
          "width" => 36,
          "x" => 164,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "avg",
                "conditional_formats" => [
                  %{"comparator" => "<=", "palette" => "green_on_white", "value" => "60"},
                  %{"comparator" => ">=", "palette" => "red_on_white", "value" => "120"},
                  %{"comparator" => ">", "palette" => "yellow_on_white", "value" => "90"}
                ],
                "q" => "avg:wait_time{*}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "Wait (Avg)",
          "type" => "query_value",
          "width" => 10,
          "x" => 126,
          "y" => 4
        },
        %{
          "autoscale" => true,
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "custom_unit" => "%",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                  %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                  %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
                ],
                "q" =>
                  "(sum:call_count_today{dropped}/(sum:call_count_today{contact}+sum:call_count_today{dropped}))*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 13,
          "title_text" => "Total Today",
          "type" => "query_value",
          "width" => 31,
          "x" => 65,
          "y" => 4
        },
        %{
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "requests" => [
              %{
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_yellow", "value" => 0}
                ],
                "q" => "top(sum:call_count_5{dropped} by {service_name}, 5, 'last', 'desc')",
                "style" => %{"palette" => "dog_classic"}
              }
            ],
            "viz" => "toplist"
          },
          "timeframe" => "5m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "5m Dropped",
          "type" => "toplist",
          "width" => 28,
          "x" => 96,
          "y" => 4
        },
        %{
          "board_id" => 260_348,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "requests" => [
              %{
                "conditional_formats" => [
                  %{"comparator" => ">", "palette" => "white_on_green", "value" => 0}
                ],
                "q" => "top(avg:cip{*} by {service}, 5, 'last', 'desc')",
                "style" => %{"palette" => "dog_classic"}
              }
            ],
            "viz" => "toplist"
          },
          "timeframe" => "5m",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "CIP",
          "type" => "toplist",
          "width" => 38,
          "x" => 240,
          "y" => 4
        },
        %{
          "board_id" => 325_115,
          "height" => 21,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => true,
            "requests" => [
              %{
                "conditional_formats" => [],
                "q" => "sum:call_count_today{*} by {service_name}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => "area"
              }
            ],
            "viz" => "timeseries"
          },
          "timeframe" => "4h",
          "title" => true,
          "title_align" => "left",
          "title_size" => 16,
          "title_text" => "Total Calls",
          "type" => "timeseries",
          "width" => 38,
          "x" => 0,
          "y" => 45
        },
        %{
          "autoscale" => true,
          "board_id" => 325_115,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [],
                "q" => "sum:call_count_today{*}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "Total Calls",
          "type" => "query_value",
          "width" => 38,
          "x" => 0,
          "y" => 68
        },
        %{
          "autoscale" => true,
          "board_id" => 325_115,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "custom_unit" => "%",
            "precision" => "2",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [],
                "q" =>
                  "((sum:call_count_today{van_result:strong_support}+sum:call_count_today{van_result:lean_support})/sum:call_count_today{canvass})*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "1s/2s % of IDs",
          "type" => "query_value",
          "width" => 38,
          "x" => 1,
          "y" => 111
        },
        %{
          "autoscale" => true,
          "board_id" => 325_115,
          "height" => 13,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [],
                "q" => "sum:call_count_today{canvass}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "IDs",
          "type" => "query_value",
          "width" => 20,
          "x" => 0,
          "y" => 96
        },
        %{
          "autoscale" => true,
          "board_id" => 325_115,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "custom_unit" => "%",
            "precision" => "2",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [],
                "q" => "(sum:call_count_today{contact}/sum:call_count_today{dialed})*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "Contact % (of dialed)",
          "type" => "query_value",
          "width" => 18,
          "x" => 20,
          "y" => 82
        },
        %{
          "autoscale" => true,
          "board_id" => 325_115,
          "height" => 12,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "precision" => "0",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [],
                "q" => "sum:call_count_today{contact}",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "Contacts",
          "type" => "query_value",
          "width" => 20,
          "x" => 0,
          "y" => 82
        },
        %{
          "autoscale" => true,
          "board_id" => 325_115,
          "height" => 13,
          "isShared" => false,
          "legend" => false,
          "legend_size" => "0",
          "tile_def" => %{
            "autoscale" => false,
            "custom_unit" => "%",
            "precision" => "2",
            "requests" => [
              %{
                "aggregator" => "last",
                "conditional_formats" => [],
                "q" => "(sum:call_count_today{canvass}/sum:call_count_today{dialed})*100",
                "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
                "type" => nil
              }
            ],
            "viz" => "query_value"
          },
          "timeframe" => "1d",
          "title" => true,
          "title_align" => "left",
          "title_size" => 20,
          "title_text" => "IDs % (of dialed)",
          "type" => "query_value",
          "width" => 18,
          "x" => 20,
          "y" => 96
        }
      ],
      "width" => "100%"
    }
  end

  def widget_group(~m(x y service_base title)a) do
    [
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "custom_unit" => nil,
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => ">", "palette" => "white_on_red", "value" => nil},
                %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => nil},
                %{"comparator" => "<", "palette" => "white_on_green", "value" => nil}
              ],
              "q" => "sum:throttle{service:#{service_base}_monitor}",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1h",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "cell",
        "type" => "query_value",
        "width" => 8,
        "x" => x,
        "y" => y + 15
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => "<=", "palette" => "red_on_white", "value" => "1000"},
                %{"comparator" => "<=", "palette" => "yellow_on_white", "value" => "5000"},
                %{"comparator" => ">", "palette" => "green_on_white", "value" => "5000"}
              ],
              "q" => "sum:remaining{service:#{service_base}_monitor}",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1h",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "",
        "type" => "query_value",
        "width" => 8,
        "x" => x + 8,
        "y" => y + 15
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "custom_unit" => nil,
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [],
              "q" => "sum:throttle{service:#{service_base}_callers}",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1h",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "lands",
        "type" => "query_value",
        "width" => 8,
        "x" => x,
        "y" => y + 9
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => "<=", "palette" => "red_on_white", "value" => "1000"},
                %{"comparator" => "<=", "palette" => "yellow_on_white", "value" => "5000"},
                %{"comparator" => ">", "palette" => "green_on_white", "value" => "5000"}
              ],
              "q" => "sum:remaining{service:#{service_base}_callers}",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1h",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "",
        "type" => "query_value",
        "width" => 8,
        "x" => x + 8,
        "y" => y + 9
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "custom_unit" => "%",
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
              ],
              "q" =>
                "(sum:call_count_5{dropped,service_name:#{service_base}}/(sum:call_count_5{dropped,service_name:#{
                  service_base
                }}+sum:call_count_5{service_name:#{service_base},contact}))*100",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "5m",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "5m",
        "type" => "query_value",
        "width" => 8,
        "x" => x + 16,
        "y" => y + 9
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => false,
          "custom_unit" => "%",
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
              ],
              "q" =>
                "(sum:call_count_today{dropped,service_name:#{service_base}}/(sum:call_count_today{contact,service_name:#{
                  service_base
                }}+sum:call_count_today{dropped,service_name:#{service_base}}))*100",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1d",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "Today",
        "type" => "query_value",
        "width" => 8,
        "x" => x + 16,
        "y" => y + 15
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "precision" => "0",
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => ">", "palette" => "white_on_green", "value" => "0"},
                %{"comparator" => "<=", "palette" => "yellow_on_white", "value" => "0"}
              ],
              "q" => "sum:count_active{service:#{service_base}_callers}",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1m",
        "title" => true,
        "title_align" => "left",
        "title_size" => 16,
        "title_text" => "Active",
        "type" => "query_value",
        "width" => 8,
        "x" => x,
        "y" => y + 3
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "precision" => "0",
          "requests" => [
            %{
              "aggregator" => "avg",
              "conditional_formats" => [
                %{"comparator" => "<", "palette" => "green_on_white", "value" => "60"},
                %{"comparator" => "<", "palette" => "yellow_on_white", "value" => "120"},
                %{"comparator" => "<", "palette" => "red_on_white", "value" => "180"},
                %{"comparator" => ">=", "palette" => "white_on_red", "value" => "180"}
              ],
              "q" => "avg:wait_time{service:#{service_base}_callers}",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1m",
        "title" => true,
        "title_align" => "left",
        "title_size" => 16,
        "title_text" => "Wait (Avg)",
        "type" => "query_value",
        "width" => 8,
        "x" => x + 8,
        "y" => y + 3
      },
      %{
        "board_id" => 288_880,
        "height" => 12,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "16",
        "tile_def" => %{
          "autoscale" => true,
          "requests" => [
            %{
              "aggregator" => "avg",
              "conditional_formats" => [],
              "q" =>
                "(sum:call_count_today{dropped,service_name:#{service_base}} by {service_name}/(sum:call_count_today{contact,service_name:#{
                  service_base
                }}+sum:call_count_today{dropped,service_name:#{service_base}} by {service_name}))*100",
              "style" => %{"palette" => "purple", "type" => "solid", "width" => "normal"},
              "type" => "area"
            }
          ],
          "viz" => "timeseries"
        },
        "timeframe" => "4h",
        "title" => true,
        "title_align" => "left",
        "title_size" => 20,
        "title_text" => "Daily Drop Rate",
        "type" => "timeseries",
        "width" => 24,
        "x" => x,
        "y" => y + 21
      },
      %{
        "autoscale" => true,
        "board_id" => 260_348,
        "height" => 4,
        "isShared" => false,
        "legend" => false,
        "legend_size" => "0",
        "tile_def" => %{
          "autoscale" => true,
          "custom_unit" => "%",
          "requests" => [
            %{
              "aggregator" => "last",
              "conditional_formats" => [
                %{"comparator" => ">", "palette" => "white_on_red", "value" => "3"},
                %{"comparator" => ">=", "palette" => "white_on_yellow", "value" => "2"},
                %{"comparator" => "<", "palette" => "white_on_green", "value" => "2"}
              ],
              "q" =>
                "(sum:call_count_1{dropped,service_name:#{service_base}}/(sum:call_count_1{dropped,service_name:#{
                  service_base
                }}+sum:call_count_1{service_name:#{service_base},contact}))*100",
              "style" => %{"palette" => "dog_classic", "type" => "solid", "width" => "normal"},
              "type" => nil
            }
          ],
          "viz" => "query_value"
        },
        "timeframe" => "1m",
        "title" => true,
        "title_align" => "left",
        "title_size" => 13,
        "title_text" => "1m",
        "type" => "query_value",
        "width" => 8,
        "x" => x + 16,
        "y" => y + 3
      },
      %{
        "board_id" => 260_348,
        "color" => "#000",
        "font_size" => "24",
        "height" => 3,
        "isShared" => false,
        "text" => title,
        "text_align" => "left",
        "title" => true,
        "title_align" => "left",
        "title_size" => 16,
        "title_text" => "",
        "type" => "free_text",
        "width" => 23,
        "x" => x,
        "y" => y
      }
    ]
  end
end
