defmodule Salx.Repo.Migrations.CreateReplies do
  use Ecto.Migration

  def change do
    create table(:replies) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:replies, [:message_id])
    create index(:replies, [:user_id])
  end
end
