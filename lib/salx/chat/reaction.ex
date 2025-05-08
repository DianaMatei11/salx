defmodule Salx.Chat.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  alias Salx.Accounts.User
  alias Salx.Chat.Message

  schema "reactions" do
    field :emoji, :string
    belongs_to :user, User
    belongs_to :message, Message
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :message_id, :user_id])
    |> validate_required([:emoji, :message_id, :user_id])
    |> unique_constraint([:emoji, :message_id, :user_id])
  end
end
