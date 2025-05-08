defmodule Salx.Repo do
  use Ecto.Repo,
    otp_app: :salx,
    adapter: Ecto.Adapters.Postgres

  use Paginator
end
