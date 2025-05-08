defmodule SalxWeb.ChatRoomLive.Edit do
  use SalxWeb, :live_view
  alias Salx.Chat

  import SalxWeb.RoomComponents

  def mount(%{"id" => id}, _sesion, socket) do
    room = Chat.get_room!(id)

    socket =
      if Chat.joined?(room, socket.assigns.current_user) do
        changeset = Chat.change_room(room)

        socket |> assign(page_title: "Edit chat room", room: room) |> assign_form(changeset)
      else
        socket |> put_flash(:error, "Permission denied") |> push_navigate(to: ~p"/")
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-96 mt-12">
      <.header>
        {@page_title}
        <:actions>
          <.link
            class="font-normal text-xs text-blue-600 hover:text-blue-700"
            navigate={~p"/rooms/#{@room}"}
          >
            Back
          </.link>
        </:actions>
      </.header>
       <.room_form form={@form} />
    </div>
    """
  end

  def handle_event("save-room", %{"room" => room_params}, socket) do
    case Chat.update_room(socket.assigns.room, room_params) do
      {:ok, _room} ->
        {:noreply,
         socket
         |> put_flash(:into, "Room update successfilly")
         |> push_navigate(to: ~p"/")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate-room", %{"room" => room_params}, socket) do
    changeset =
      socket.assigns.room
      |> Chat.change_room(room_params)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeSet) do
    assign(socket, :form, to_form(changeSet))
  end
end
