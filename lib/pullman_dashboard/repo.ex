defmodule PullmanDashboard.Repo do
  use Ecto.Repo,
    otp_app: :pullman_dashboard,
    adapter: Ecto.Adapters.MyXQL
end
