defmodule Salx.Repo.Migrations.AddNewFieldOfTables do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :type, :string, default: "channel"
    end
  end
end
