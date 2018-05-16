defmodule LevelWeb.Schema do
  @moduledoc false

  use Absinthe.Schema
  import_types LevelWeb.Schema.Types

  alias Level.Repo
  alias Level.Spaces

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(:db, Dataloader.Ecto.new(Repo))

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  query do
    @desc "The currently authenticated user."
    field :viewer, :user do
      resolve(fn _, %{context: %{current_user: current_user}} ->
        {:ok, current_user}
      end)
    end

    @desc "Fetches a space membership by space id."
    field :space_membership, :space_membership do
      arg :space_id, non_null(:id)
      resolve &Level.Connections.space_membership/3
    end
  end

  mutation do
    @desc "Create a space."
    field :create_space, type: :create_space_payload do
      arg :name, non_null(:string)
      arg :slug, non_null(:string)

      resolve &Level.Mutations.create_space/2
    end

    @desc "Mark a space setup step as complete."
    field :complete_setup_step, type: :complete_setup_step_payload do
      arg :space_id, non_null(:id)
      arg :state, non_null(:space_setup_state)
      arg :is_skipped, non_null(:boolean)

      resolve &Level.Mutations.complete_setup_step/2
    end

    @desc "Create a group."
    field :create_group, type: :create_group_payload do
      arg :space_id, non_null(:id)
      arg :name, non_null(:string)
      arg :description, :string
      arg :is_private, :boolean

      resolve &Level.Mutations.create_group/2
    end

    @desc "Create multiple groups."
    field :bulk_create_groups, type: :bulk_create_groups_payload do
      arg :space_id, non_null(:id)
      arg :names, non_null(list_of(:string))

      resolve &Level.Mutations.bulk_create_groups/2
    end

    @desc "Update a group."
    field :update_group, type: :update_group_payload do
      arg :space_id, non_null(:id)
      arg :group_id, non_null(:id)
      arg :name, :string
      arg :description, :string
      arg :is_private, :boolean

      resolve &Level.Mutations.update_group/2
    end

    @desc "Create a post."
    field :create_post, type: :create_post_payload do
      arg :space_id, non_null(:id)
      arg :body, non_null(:string)

      resolve &Level.Mutations.create_post/2
    end
  end

  subscription do
    @desc "Triggered when a group bookmark is created."
    field :group_bookmark_created, :group_bookmark_created_payload do
      arg :space_membership_id, non_null(:id)
      config &space_user_topic/2
    end
  end

  def space_user_topic(%{space_membership_id: id}, %{context: %{current_user: user}}) do
    case Spaces.get_space_user(user, id) do
      {:ok, space_user} -> {:ok, topic: id}
      err -> err
    end
  end
end
