defmodule TictactwoWeb.RoomView do
  use TictactwoWeb, :view

  use Tictactwo.Types

  alias Tictactwo.Games
  alias TictactwoWeb.Components.GameStatus
  alias TictactwoWeb.Components.Board
  alias TictactwoWeb.Components.Gobbler
  alias TictactwoWeb.Components.Player
  alias TictactwoWeb.Components.Controls
  alias TictactwoWeb.Components.View

  @spec my_turn?(game :: game(), user_type :: viewer_type(), remaining_time :: integer) :: boolean()
  def my_turn?(_, :spectator, _), do: false

  def my_turn?(game, user_type, remaining_time \\ 30) do
    game.player_turn == user_type && remaining_time > 0
  end

  @spec game_not_ended?(game :: game()) :: boolean()
  def game_not_ended?(game) do
    game_ready?(game) || game_in_play?(game)
  end

  @spec game_ended?(game :: game()) :: boolean()
  def game_ended?(game) do
    not game_not_ended?(game)
  end

  @spec game_in_play?(game :: game()) :: boolean()
  def game_in_play?(%{status: :in_play}), do: true
  def game_in_play?(_game), do: false

  @spec game_ready?(game :: game()) :: boolean()
  def game_ready?(%{status: :ready}), do: true
  def game_ready?(_game), do: false

  @spec game_aborted?(game :: game()) :: boolean()
  def game_aborted?(%{status: {:aborted, _}}), do: true
  def game_aborted?(_game), do: false

  def winning_player(%{status: :blue_won}) do
    "blue"
  end

  def winning_player(%{status: :orange_won}) do
    "orange"
  end

  def gobbler_class(color) do
    "w-20 h-10 py-2 px-4 border-2 border-#{color |> to_string()}-500 bg-#{color |> to_string()}-500"
  end

  def not_selected_gobblers(game, :spectator) do
    not_selected_gobblers(game, :blue)
  end

  def not_selected_gobblers(game, user_type) do
    game
    |> Map.get(user_type)
    |> Enum.filter(&(&1.status == :not_selected))
  end

  def played_gobbler_text(gobblers) do
    gobblers
    |> List.first({" ", " "})
    |> elem(1)
  end

  def played_gobbler_color(gobblers) do
    gobblers
    |> List.first({" ", " "})
    |> elem(0)
    |> to_string()
    |> then(fn color -> "bg-#{color}-500" end)
  end

  def can_select?(gobblers, player) do
    gobblers
    |> List.first()
    |> then(fn
      {^player, _name} -> true
      _ -> false
    end)
  end

  def first_gobbler_name(gobblers) do
    gobblers
    |> List.first()
    |> then(fn
      {_, name} -> name
      _ -> " "
    end)
  end

  def first_gobbler_selected?(gobblers, selected_gobbler, player_turn) do
    gobblers
    |> List.first()
    |> then(fn
      {^player_turn, name} when name == selected_gobbler.name ->
        true

      _ ->
        false
    end)
  end

  def get_current_user_color_type(:orange), do: "secondary"
  def get_current_user_color_type(_), do: "primary"

  def toggle_player_turn(:blue), do: :orange
  def toggle_player_turn(:orange), do: :blue

  def toggle_user_type(:spectator), do: :spectator
  def toggle_user_type(x), do: toggle_player_turn(x)

  def hide_last_gobbler(game, cell_coords) do
    selected_gobbler = game.selected_gobbler

    if not is_nil(selected_gobbler.played?) and selected_gobbler.played? == cell_coords do
      "hidden"
    else
      ""
    end
  end

  @spec is_player?(viewer_type) :: boolean()
  def is_player?(:spectator), do: false
  def is_player?(_), do: true

  @spec show_player_name(game :: game(), color :: String.t()) :: String.t()
  def show_player_name(game, color) do
    atom = "#{color}_username" |> String.to_atom()
    Map.get(game, atom)
  end

  @spec game_status_to_player(game_status :: game_status()) :: String.t()
  def game_status_to_player(:blue_won), do: "Blue"
  def game_status_to_player(_), do: "Orange"

  def rematch_offered?(game, current_user, user_type) do
    user_type != :spectator and not is_nil(game.rematch_offered_by) and
      game.rematch_offered_by.username != current_user.username
  end

end
