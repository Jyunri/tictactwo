defmodule Tictactwo.Games do
  use Tictactwo.Types

  alias Tictactwo.Repo
  alias Tictactwo.Gobblers
  import Ecto.Query

  @spec new_game(player(), blue_username :: String.t(), orange_username :: String.t()) ::
          String.t()
  def new_game(player_turn, blue_username, orange_username) do
    new_gobblers = Gobblers.new_gobblers()

    attrs = %{
      blue: blue_username,
      orange: orange_username,
      player_turn: player_turn,
      cells: gen_empty_cells(),
      blue_gobblers: new_gobblers,
      orange_gobblers: new_gobblers
    }

    with {:ok, game} <- create_game(attrs) do
      game.slug
    end
  end

  @spec select_already_played_gobbler(
          game :: game(),
          gobbler_name :: gobbler_name(),
          coords :: coords()
        ) :: game()
  def select_already_played_gobbler(game, gobbler_name, {row, col}) do
    selected_gobbler = %{
      name: gobbler_name,
      played?: {row, col}
    }

    game
    |> pop_first_gobbler_from_cell({row, col})
    |> set_selected_gobbler(selected_gobbler)
    |> update_gobbler_status(gobbler_name, :selected)
  end

  @spec select_unplayed_gobbler(game :: game(), gobbler_name :: gobbler_name()) :: game()
  def select_unplayed_gobbler(game, gobbler_name) do
    selected_gobbler = %{
      name: gobbler_name,
      played?: nil
    }

    game
    |> set_selected_gobbler(selected_gobbler)
    |> update_gobbler_status(gobbler_name, :selected)
  end

  @spec deselect_gobbler(game :: game()) :: game()
  def deselect_gobbler(game) do
    case game.selected_gobbler.played? do
      nil -> deselect_unplayed_gobbler(game)
      {row, col} -> deselect_played_gobbler(game, {row, col})
    end
  end

  @spec play_gobbler(game :: game(), coords :: coords()) :: game()
  def play_gobbler(game, coords) do
    selected_gobbler = game.selected_gobbler
    gobbler_name = selected_gobbler.name

    game
    |> push_gobbler_to_cell(coords)
    |> update_gobbler_status(gobbler_name, {:played, coords})
    |> set_selected_gobbler(nil)
    |> update_game_status()
    |> toggle_player_turn()
  end

  # --------------------------------------------------------------
  # --------------------- PRIVATE FUNCTIONS ----------------------
  # --------------------------------------------------------------

  @spec gen_empty_cells() :: [cell()]
  defp gen_empty_cells() do
    Enum.flat_map(0..2, fn row ->
      Enum.map(0..2, fn col ->
        gen_empty_cell(row, col)
      end)
    end)
  end

  @spec pop_first_gobbler_from_cell(game :: game(), coords :: coords()) :: game()
  def pop_first_gobbler_from_cell(game, {row, col}) do
    Map.put(
      game,
      :cells,
      game.cells
      |> Enum.map(fn cell ->
        case cell.coords do
          {^row, ^col} -> Map.update!(cell, :gobblers, &Enum.drop(&1, 1))
          _ -> cell
        end
      end)
    )
  end

  @spec push_gobbler_to_cell(game :: game(), coords :: coords()) :: game()
  def push_gobbler_to_cell(game, {row, col}) do
    Map.put(
      game,
      :cells,
      game.cells
      |> Enum.map(fn cell ->
        case cell.coords do
          {^row, ^col} ->
            Map.update!(cell, :gobblers, fn gs ->
              [{game.player_turn, game.selected_gobbler.name} | gs]
            end)

          _ ->
            cell
        end
      end)
    )
  end

  @spec set_selected_gobbler(game :: game(), selected_gobbler :: selected_gobbler()) :: game()
  def set_selected_gobbler(game, selected_gobbler) do
    game
    |> Map.put(:selected_gobbler, selected_gobbler)
  end

  @spec update_gobbler_status(
          game :: game(),
          gobbler_name :: gobbler_name(),
          status :: gobbler_status()
        ) :: game()
  def update_gobbler_status(game, gobbler_name, status) do
    game
    |> Map.update!(
      game.player_turn,
      fn player ->
        %{player | gobblers: set_gobbler_status(player.gobblers, gobbler_name, status)}
      end
    )
  end

  @spec deselect_played_gobbler(game :: game(), coords :: coords()) :: game()
  defp deselect_played_gobbler(game, coords) do
    game
    |> push_gobbler_to_cell(coords)
    |> update_gobbler_status(game.selected_gobbler.name, {:played, coords})
    |> set_selected_gobbler(nil)
  end

  @spec deselect_unplayed_gobbler(game :: game()) :: game()
  defp deselect_unplayed_gobbler(game) do
    game
    |> update_gobbler_status(game.selected_gobbler.name, :not_selected)
    |> set_selected_gobbler(nil)
  end

  @spec set_gobbler_status(
          gobblers :: [gobbler()],
          gobbler_name :: gobbler_name(),
          status :: gobbler_status()
        ) :: [gobbler()]
  defp set_gobbler_status(gobblers, gobbler, status) do
    gobblers
    |> Enum.map(fn g ->
      if g.name == gobbler do
        %{name: g.name, status: status}
      else
        g
      end
    end)
  end

  @spec toggle_player_turn(game :: game()) :: game()
  def toggle_player_turn(game) do
    case game.status do
      :in_play ->
        game
        |> Map.update!(:player_turn, &toggle_player/1)

      _ ->
        game
    end
  end

  @spec game_status(game :: game()) :: game_status()
  def game_status(game) do
    with :in_play <- check_rows(game.cells),
         :in_play <- check_cols(game.cells),
         :in_play <- check_falling_diag(game.cells) do
      check_rising_diag(game.cells)
    else
      v -> v
    end
  end

  @spec update_game_status(game :: game()) :: game()
  defp update_game_status(game) do
    Map.put(game, :status, game_status(game))
  end

  @spec check_rising_diag(cells :: cells()) :: game_status()
  defp check_rising_diag(cells) do
    diag =
      cells
      |> Enum.filter(fn
        %{coords: {2, 0}} -> true
        %{coords: {0, 2}} -> true
        %{coords: {2, 2}} -> true
        _ -> false
      end)

    check_win(diag)
  end

  @spec check_falling_diag(cells :: cells()) :: game_status()
  defp check_falling_diag(cells) do
    diag =
      cells
      |> Enum.filter(fn %{coords: {row, col}} -> row == col end)

    check_win(diag)
  end

  @spec check_rows(cells :: cells()) :: game_status()
  defp check_rows(cells) do
    first_row =
      cells
      |> Enum.filter(fn %{coords: {row, _col}} -> row == 0 end)

    second_row =
      cells
      |> Enum.filter(fn %{coords: {row, _col}} -> row == 1 end)

    third_row =
      cells
      |> Enum.filter(fn %{coords: {row, _col}} -> row == 2 end)

    with :in_play <- check_win(first_row),
         :in_play <- check_win(second_row) do
      check_win(third_row)
    else
      v -> v
    end
  end

  @spec check_cols(cells :: cells()) :: game_status()
  defp check_cols(cells) do
    first_col =
      cells
      |> Enum.filter(fn %{coords: {_row, col}} -> col == 0 end)

    second_col =
      cells
      |> Enum.filter(fn %{coords: {_row, col}} -> col == 1 end)

    third_col =
      cells
      |> Enum.filter(fn %{coords: {_row, col}} -> col == 2 end)

    with :in_play <- check_win(first_col),
         :in_play <- check_win(second_col) do
      check_win(third_col)
    else
      v -> v
    end
  end

  @spec check_win(cells :: cells) :: game_status()
  defp check_win(cells) do
    cells
    |> Enum.map(fn cell -> cell.gobblers |> List.first() end)
    |> then(fn
      [{p, _}, {p, _}, {p, _}] ->
        {:won, p}

      _ ->
        :in_play
    end)
  end

  @spec toggle_player(player()) :: player()
  defp toggle_player(:blue), do: :orange
  defp toggle_player(:orange), do: :blue

  @spec gen_empty_cell(row :: pos_integer(), col :: pos_integer()) :: cell()
  defp gen_empty_cell(row, col) do
    %{coords: {row, col}, gobblers: []}
  end

  def move_allowed?(game, gobblers) do
    gobblers
    |> List.first()
    |> then(fn
      {_, name} ->
        case Gobblers.compare(game.selected_gobbler.name, name) do
          :lt -> false
          :eq -> false
          _ -> true
        end

      _ ->
        true
    end)
  end

  alias Tictactwo.Games.Game

  @doc """
  Returns the list of games.

  ## Examples

      iex> list_games()
      [%Game{}, ...]

  """
  def list_games do
    Repo.all(Game)
  end

  @doc """
  Gets a single game.

  Raises `Ecto.NoResultsError` if the Game does not exist.

  ## Examples

      iex> get_game!(123)
      %Game{}

      iex> get_game!(456)
      ** (Ecto.NoResultsError)

  """
  def get_game!(id), do: Repo.get!(Game, id)

  @doc """
  Creates a game.

  ## Examples

      iex> create_game(%{field: value})
      {:ok, %Game{}}

      iex> create_game(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_game(attrs \\ %{}) do
    %Game{}
    |> Game.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a game.

  ## Examples

      iex> update_game(game, %{field: new_value})
      {:ok, %Game{}}

      iex> update_game(game, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_game(%Game{} = game, attrs) do
    game
    |> Game.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a game.

  ## Examples

      iex> delete_game(game)
      {:ok, %Game{}}

      iex> delete_game(game)
      {:error, %Ecto.Changeset{}}

  """
  def delete_game(%Game{} = game) do
    Repo.delete(game)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking game changes.

  ## Examples

      iex> change_game(game)
      %Ecto.Changeset{data: %Game{}}

  """
  def change_game(%Game{} = game, attrs \\ %{}) do
    Game.changeset(game, attrs)
  end

  def fetch_players(slug) do
    from(g in Game, select: {g.blue, g.orange}, where: g.slug == ^slug)
    |> Repo.one()
  end

  def get_game_by_slug!(slug) do
    from(g in Game, where: g.slug == ^slug)
    |> Repo.one!()
    |> Map.put(:selected_gobbler, nil)
  end
end
