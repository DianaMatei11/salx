defmodule Salx.Chat do
  alias ThousandIsland.AcceptorSupervisor
  alias Expo.Message
  alias Salx.Repo
  alias Salx.Chat.{Message, Reply, Reaction, Room, RoomMembership}
  alias Salx.Accounts.User

  import Ecto.Query
  import Ecto.Changeset

  @pubsub Salx.PubSub
  @room_page_size 10

  def list_rooms do
    Repo.all(from Room, order_by: [asc: :name])
  end

  def change_room(room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end

  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def list_messages_in_room(%Room{id: room_id}, opts \\ []) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: :inserted_at, desc: :id)
    |> preload_message_user_and_replies()
    |> preload_reactions()
    |> Repo.paginate(
      after: opts[:after],
      cursor_fields: [inserted_at: :asc, id: :asc]
    )
  end

  def change_message(message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def create_message(room, attrs, user) do
    with {:ok, message} <-
           %Message{room: room, user: user, replies: [], reactions: []}
           |> Message.changeset(attrs)
           |> Repo.insert() do
      Repo.preload(message, :user)
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})
      {:ok, message}
    end
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)
    Repo.delete(message)
    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:message_deleted, message})
  end

  def delete_reply_by_id(id, %User{id: user_id}) do
    with %Reply{} = reply <-
           from(r in Reply, where: r.id == ^id and r.user_id == ^user_id)
           |> Repo.one() do
      Repo.delete(reply)

      message = get_message!(reply.message_id)

      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:deleted_reply, message})
    end
  end

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_to_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  defp topic(room_id), do: "chat_room:#{room_id}"

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end

  def list_joined_rooms_with_unread_counts(%User{} = user) do
    from(room in Room,
      join: membership in assoc(room, :memberships),
      where: membership.user_id == ^user.id,
      left_join: message in assoc(room, :messages),
      on: message.id > membership.last_read_id,
      group_by: room.id,
      select: {room, count(message.id)},
      order_by: [asc: room.inserted_at]
    )
    |> Repo.all()
  end

  def joined?(%Room{} = room, %User{} = user) do
    Repo.exists?(
      from rm in RoomMembership, where: rm.room_id == ^room.id and rm.user_id == ^user.id
    )
  end

  def list_rooms_with_joined(page, %User{} = user) do
    offset = (page - 1) * @room_page_size

    query =
      from r in Room,
        left_join: m in RoomMembership,
        on: r.id == m.room_id and m.user_id == ^user.id,
        select: {r, not is_nil(m.id)},
        order_by: [asc: :name],
        limit: ^@room_page_size,
        offset: ^offset

    Repo.all(query)
  end

  def count_room_pages do
    ceil(Repo.aggregate(Room, :count) / @room_page_size)
  end

  def toggle_room_membership(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        Repo.delete(membership)
        {room, false}

      nil ->
        join_room!(room, user)
        {room, true}
    end
  end

  def update_last_read_id(room, user) do
    case Repo.get_by(RoomMembership,
           room_id: room.id,
           user_id: user.id
         ) do
      %RoomMembership{} = membership ->
        id =
          from(m in Message,
            where: m.room_id == ^room.id,
            select: max(m.id)
          )
          |> Repo.one()

        membership
        |> change(%{last_read_id: id})
        |> Repo.update()

      nil ->
        nil
    end
  end

  defp get_membership(room, user) do
    Repo.get_by(RoomMembership, room_id: room.id, user_id: user.id)
  end

  def get_last_read_id(%Room{} = room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        membership.last_read_id

      nil ->
        nil
    end
  end

  def get_message!(id) do
    Message
    |> where([m], m.id == ^id)
    |> preload_message_user_and_replies()
    |> preload_reactions()
    |> Repo.one!()
  end

  def create_reply(%Message{} = message, attrs, user) do
    with {:ok, reply} <-
           %Reply{message: message, user: user}
           |> Reply.changeset(attrs)
           |> Repo.insert() do
      message = get_message!(reply.message_id)
      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:new_reply, message})
      {:ok, reply}
    end
  end

  defp preload_message_user_and_replies(message_query) do
    replies_query = from r in Reply, order_by: [asc: :inserted_at, asc: :id]

    preload(message_query, [
      :user,
      replies: ^{replies_query, [:user]}
    ])
  end

  def change_reply(reply, attrs \\ %{}) do
    Reply.changeset(reply, attrs)
  end

  def add_reaction(emoji, %Message{} = message, %User{} = user) do
    with {:ok, reaction} <-
           %Reaction{message_id: message.id, user_id: user.id}
           |> Reaction.changeset(%{emoji: emoji})
           |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:added_reaction, reaction})

      {:ok, reaction}
    end
  end

  def remove_reaction(
        emoji,
        %Message{} = message,
        %User{} =
          user
      ) do
    with %Reaction{} = reaction <-
           Repo.one(
             from(r in Reaction,
               where:
                 r.message_id == ^message.id and
                   r.user_id == ^user.id and r.emoji == ^emoji
             )
           ),
         {:ok, reaction} <- Repo.delete(reaction) do
      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:removed_reaction, reaction})

      {:ok, reaction}
    end
  end

  defp preload_reactions(message_query) do
    reactions_query = from r in Reaction, order_by: [asc: :id]

    preload(message_query, reactions: ^reactions_query)
  end

  def get_or_create_dm_room(user1_id, user2_id) do
    [u1, u2] = Enum.sort([user1_id, user2_id])

    name = Salx.Accounts.get_user!(u1).username |> String.downcase()

    IO.inspect(name, label: "Trying to get/create DM Room")

    case Repo.get_by(Room, name: name, type: "dm") do
      nil ->
        IO.puts("DM room not found, trying to create...")

        changeset = Room.changeset(%Room{}, %{name: name, type: "dm"})

        case Repo.insert(changeset) do
          {:ok, room} ->
            Enum.each([u1, u2], fn uid ->
              %RoomMembership{}
              |> RoomMembership.changeset(%{user_id: uid, room_id: room.id})
              |> Repo.insert!()
            end)

            IO.inspect(room, label: "DM room created")
            room

          {:error, changeset} ->
            IO.inspect(changeset.errors, label: "Room insert failed")
            # Camera există deja, o returnăm
            Repo.get_by(Room, name: name, type: "dm")
        end

      room ->
        IO.inspect(room, label: "DM room found")
        room
    end
  end

  def get_dm_other_username(room, current_user) do
    room = Repo.preload(room, :users)
    room.users |> Enum.reject(&(&1.id == current_user.id)) |> hd() |> Map.get(:username)
  end
end
