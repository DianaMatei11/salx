defmodule Salx.Chat.RoomMembership do
  use Ecto.Schema
  import Ecto.Changeset

  alias Salx.Accounts.User
  alias Salx.Chat.Room

  schema "room_memberships" do
    belongs_to :user, User
    belongs_to :room, Room

    field :last_read_id, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room_membership, attrs) do
    room_membership
    |> cast(attrs, [:user_id, :room_id])
    |> validate_required([:user_id, :room_id])
  end
end
