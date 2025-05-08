defmodule SalxWeb.UserComponents do
  use SalxWeb, :html

  alias Salx.Accounts.User

  attr :user, User
  attr :class, :string, default: "h-8 w-8 rounded"
  attr :rest, :map, default: %{}

  def user_avatar(assigns) do
    ~H"""
    <img data-user-avatar-id={@user.id} src={user_avatar_path(@user)} class={@class} {@rest} />
    """
  end

  defp user_avatar_path(user) do
    if user.avatar_path do
      ~p"/uploads/#{user.avatar_path}"
    else
      ~p"/images/1.svg"
    end
  end
end
