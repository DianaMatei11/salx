defmodule Salx.Repo.Migrations.AddUsernameToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :username, :citext, null: false
    end

    # Pas 4: Creăm indexul unic pe username
    create unique_index(:users, :username)
  end
end
