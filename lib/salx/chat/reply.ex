defmodule Salx.Chat.Reply do
  use Ecto.Schema
  import Ecto.Changeset

  alias Salx.Chat.Message
  alias Salx.Accounts.User

  schema "replies" do
    field :body, :string

    belongs_to :message, Message
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [:body, :message_id, :user_id])
    |> validate_required([:message_id, :user_id])
  end
end
