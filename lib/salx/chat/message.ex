defmodule Salx.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset
  alias Salx.Accounts.User
  alias Salx.Chat.{Reaction, Reply, Room}

  schema "messages" do
    field :body, :string
    belongs_to :room, Room
    belongs_to :user, User
    has_many :reactions, Reaction
    has_many :replies, Reply

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
