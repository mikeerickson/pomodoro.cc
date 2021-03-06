defmodule Api.Repo.Test do
  use ExUnit.Case, async: false

  alias Api.Repo
  alias Api.Models.PomodoroTodo
  alias Api.Models.Pomodoro
  alias Api.Models.UserPomodoro
  alias Api.Models.Todo
  alias Api.Models.UserTodo

  @user_id "1"
  @pomodoro %Pomodoro{minutes: 5, type: "break", started_at: Ecto.DateTime.utc}
  @todo %Todo{text: "test todos"}
  @updated_text "Rephrasing the todo text"

  setup do
    Repo.delete_all(PomodoroTodo)
    Repo.delete_all(UserTodo)
    Repo.delete_all(Todo)
    Repo.delete_all(UserPomodoro)
    Repo.delete_all(Pomodoro)
    :ok
  end

  # pomodoro_todos
  test "#associate_todo_to_pomodoro" do
    {:ok, pomodoro} = create_pomodoro
    {:ok, todo} = create_todo
    {:ok, _} = Repo.associate_todo_to_pomodoro(@user_id, todo.id, pomodoro.id)
  end

  test "#fails to associate_todo_to_pomodoro if id does not exist" do
    unexisting_id = 0
    {:error, _} = Repo.associate_todo_to_pomodoro(@user_id, unexisting_id, unexisting_id)
  end

  @tag :skip
  test "#fails to associate_todo_to_pomodoro if already exists" do
    {:ok, pomodoro} = create_pomodoro
    {:ok, todo} = create_todo
    {:ok, _} = Repo.associate_todo_to_pomodoro(@user_id, todo.id, pomodoro.id)
    {:error, _} = Repo.associate_todo_to_pomodoro(@user_id, todo.id, pomodoro.id)
  end

  # todos
  test "#create_todo_for" do
    {:ok, _} = create_todo
  end

  test "#todos_for" do
    assert Repo.todos_for(@user_id) == []
    {:ok, todo} = create_todo
    assert Repo.todos_for(@user_id) == [todo]
  end

  test "#daily_completed_todos_for" do
    {today, tomorrow} = get_today_and_tomorrow
    assert Repo.daily_completed_todos_for(@user_id, today) == []

    {:ok, todo} = create_todo
    assert Repo.daily_completed_todos_for(@user_id, today) == []
    assert Repo.daily_completed_todos_for(@user_id, tomorrow) == []

    updated_todos = Todo.changeset(todo, %{"completed" => true})
    {:ok, todo} = Repo.update_todo_for(@user_id, updated_todos)
    assert Repo.daily_completed_todos_for(@user_id, today) == [todo]
    assert Repo.daily_completed_todos_for(@user_id, tomorrow) == []
  end

  test "#todo_for" do
    assert Repo.todo_for(@user_id, 0) == nil

    {:ok, todo} = create_todo

    assert Repo.todo_for(@user_id, todo.id) == todo
  end

  test "#update_todo_for" do
    {:ok, todo} = create_todo
    todo_changeset = Todo.changeset(todo, %{"text" => @updated_text, "completed" => true})

    Repo.update_todo_for(@user_id, todo_changeset)

    saved_todo = Repo.todo_for(@user_id, todo.id)
    assert saved_todo.text == @updated_text
    assert saved_todo.completed_at
  end



  # pomodoros
  test "#create_pomodoro_for" do
    {:ok, _todo} = create_pomodoro
  end

  test "#pomodoro_for" do
    assert Repo.pomodoro_for(@user_id, 0) == nil

    {:ok, pomodoro} = create_pomodoro

    assert Repo.pomodoro_for(@user_id, pomodoro.id) == pomodoro
  end

  test "#unfinished_pomodoro_for" do
    assert Repo.unfinished_pomodoro_for(@user_id) == nil

    {:ok, pomodoro} = create_pomodoro

    assert Repo.unfinished_pomodoro_for(@user_id) == pomodoro

    Repo.complete_pomodoro(pomodoro)

    assert Repo.unfinished_pomodoro_for(@user_id) == nil
  end

  test "#daily_pomodoros_for" do
    {today, tomorrow} = get_today_and_tomorrow
    assert Repo.daily_pomodoros_for(@user_id, today) == []

    {:ok, pomodoro} = create_pomodoro

    assert Repo.daily_pomodoros_for(@user_id, today) == [pomodoro]
    assert Repo.daily_pomodoros_for(@user_id, tomorrow) == []
  end

  test "#obsolete_pomodori" do
    assert Repo.obsolete_pomodori() == []

    {:ok, pomodoro} = create_pomodoro
    {:ok, obsolete_pomodoro} = create_obsolete_pomodoro

    assert Repo.obsolete_pomodori() == [obsolete_pomodoro]

    {:ok, _} = Repo.complete_pomodoro(pomodoro)
    {:ok, _} = Repo.complete_pomodoro(obsolete_pomodoro)

    assert Repo.obsolete_pomodori() == []
  end

  test "#complete_pomodoro" do
    {:ok, obsolete_pomodoro} = create_obsolete_pomodoro
    {:ok, completed_pomodoro} = Repo.complete_pomodoro(obsolete_pomodoro)
    assert completed_pomodoro.finished == true
  end

  @tag :skip
  test "#update_pomodoro_for" do
    {:ok, pomodoro} = create_pomodoro
    updated_pomodoro = Pomodoro.changeset(pomodoro, %{cancelled_at: Ecto.DateTime.utc})
    # fails because `cancelled_at` must be a timestamp after `started_at`
    {:ok, pomodoro} = Repo.update_pomodoro_for(@user_id, updated_pomodoro)
    updated_pomodoro_in_db = Repo.pomodoro_for(@user_id, pomodoro.id)
    assert updated_pomodoro_in_db.cancelled_at == pomodoro.started_at
  end

  test "preloads associated todos for a pomodoro" do
    {:ok, pomodoro} = create_pomodoro
    {:ok, todo1} = create_todo
    {:ok, todo2} = create_todo
    {:ok, _} = Repo.associate_todo_to_pomodoro(@user_id, todo1.id, pomodoro.id)
    {:ok, _} = Repo.associate_todo_to_pomodoro(@user_id, todo2.id, pomodoro.id)

    pomodoro = Repo.pomodoro_for(@user_id, pomodoro.id)
    assert pomodoro.todos == [todo1, todo2]
  end





  defp create_pomodoro do
    Repo.create_pomodoro_for(@user_id, @pomodoro)
  end

  defp create_todo do
    Repo.create_todo_for(@user_id, @todo)
  end

  def create_obsolete_pomodoro do
    pomodoro_minutes = @pomodoro.minutes
    {:ok, obsolete_started_at} = Timex.Date.subtract(Timex.Date.universal, {pomodoro_minutes*2*60/1000000, 0, 0})
                          |> Timex.Ecto.DateTime.dump
    {:ok, obsolete_started_at} = obsolete_started_at
                          |> Ecto.DateTime.cast
    obsolete_pomodoro = %Pomodoro{minutes: pomodoro_minutes, type: "pomodoro", started_at: obsolete_started_at}

    Repo.create_pomodoro_for(@user_id, obsolete_pomodoro)
  end

  defp get_today_and_tomorrow do
    today_dt = Timex.Date.universal
    tomorrow_dt = Timex.Date.add(today_dt, {60*60*24/1000000, 0, 0})
    today = today_dt |> Timex.DateFormat.format!("{YYYY}/{0M}/{0D}")
    tomorrow = tomorrow_dt |> Timex.DateFormat.format!("{YYYY}/{0M}/{0D}")
    {today, tomorrow}
  end
end
