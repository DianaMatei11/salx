defmodule Salx.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset
  alias Salx.Accounts.User
  alias Salx.Chat.{Message, RoomMembership}

  schema "rooms" do
    field :name, :string
    field :topic, :string
    field :type, :string, default: "channel"
    has_many :memberships, RoomMembership
    has_many :messages, Message

    many_to_many :users, User, join_through: RoomMembership

    timestamps()
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :topic, :type])
    |> validate_required(:name)
    |> validate_length(:name, max: 80)
    |> validate_format(:name, ~r/\A[a-z0-9-]+\z/,
      message: "can only contain lowercase letters, numbers and dashes"
    )
    |> validate_length(:topic, max: 200)
    |> unsafe_validate_unique(:name, Salx.Repo)
    |> unique_constraint(:name)
  end
end
