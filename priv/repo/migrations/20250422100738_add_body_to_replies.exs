defmodule Salx.Repo.Migrations.AddBodyToReplies do
  use Ecto.Migration

  def change do
    alter table(:replies) do
      add :body, :text, null: false
    end
  end
end
