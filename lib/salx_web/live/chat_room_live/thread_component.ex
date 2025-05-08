defmodule SalxWeb.ChatRoomLive.ThreadComponent do
  use SalxWeb, :live_component

  alias Salx.Chat
  alias Salx.Chat.Reply

  import SalxWeb.ChatComponents

  def render(assigns) do
    ~H"""
    <div
      class="flex flex-col shrink-0 w-1/4 max-w-xs border-l border-slate-300 bg-slate-100"
      id="thread-component"
      phx-hook="Thread"
    >
      <div class="flex items-center shrink-0 h-16 border-b border-slate-300 px-4">
        <div>
          <h2 class="text-sm font-semibold leading-none">Thread</h2>
           <a class="text-xs leading-none" href="#">#{@room.name}</a>
        </div>
        
        <button
          class="flex items-center justify-center w-6 h-6 rounded hover:bg-gray-300 ml-auto"
          phx-click="close-thread"
        >
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </button>
      </div>
      
      <div id="thread-message-with-replies" class="flex flex-col grow overflow-auto">
        <div class="border-b border-slate-300">
          <.message
            message={@message}
            dom_id="thread-message"
            current_user={@current_user}
            in_thread?={true}
            timezone={@timezone}
          />
        </div>
        
        <div id="thread-replies" phx-update="stream">
          <.message
            :for={{dom_id, reply} <- @streams.replies}
            current_user={@current_user}
            dom_id={dom_id}
            message={reply}
            in_thread?={true}
            timezone={@timezone}
          />
        </div>
      </div>
      
      <div :if={@joined?} class="h-12 pb-4">
        <.form
          for={@form}
          id="new-reply-form"
          phx-change="validate-reply"
          phx-submit="submit-reply"
          phx-target={@myself}
          class="flex items-center border-2 border-slate-300 rounded-sm p-1"
        >
          <textarea
            class="grow text-sm px-3 border-l border-slate-300 mx-1 resize-none bg-slate-50"
            cols=""
            id="thread-message-textarea"
            name={@form[:body].name}
            placeholder="Reply in thread..."
            phx-debounce
            phx-hook="ChatMessageTextarea"
            rows="1"
          >
    <%= Phoenix.HTML.Form.normalize_value("textarea", @form[:body].value) %>
    </textarea>
          <button class="shrink flex items-center justify-center h-6 w-6 rounded hover:bg-slate-200">
            <.icon name="hero-paper-airplane" class="h-4 w-4" />
          </button>
        </.form>
      </div>
    </div>
    """
  end

  # Removed undefined `attrs` block as it is not used in the module context.

  def update(assigns, socket) do
    socket
    |> assign_form(Chat.change_reply(%Reply{}))
    |> stream(:replies, assigns.message.replies, reset: true)
    |> assign(assigns)
    |> ok()
  end

  def assign_form(socket, changeset) do
    IO.inspect(changeset, label: "Changeset in assign_form")
    assign(socket, :form, to_form(changeset))
  end

  def handle_event("submit-reply", %{"reply" => message_params}, socket) do
    %{assigns: %{current_user: current_user, message: message}} = socket

    if !Chat.joined?(socket.assigns.room, current_user) do
      raise "not allowed"
    end

    # Adaugă câmpurile lipsă
    message_params =
      Map.merge(message_params, %{
        "message_id" => message.id,
        "user_id" => current_user.id,
        "body" => message_params["body"]
      })

    case Chat.create_reply(message, message_params, current_user) do
      {:ok, _reply} ->
        socket
        |> assign_form(Chat.change_reply(%Reply{}))
        |> noreply()

      {:error, changeset} ->
        socket
        |> assign_form(changeset)
        |> noreply()
    end
  end

  def handle_event("validate-reply", %{"reply" => message_params}, socket) do
    changeset = Chat.change_reply(%Reply{}, message_params)

    {:noreply, assign_form(socket, changeset)}
  end
end
