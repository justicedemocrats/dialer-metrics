defmodule Db do
  require Logger
  @live not Application.get_env(:livevox, :test)

  def insert_one(collection, documents) do
    if @live do
      spawn(fn -> Mongo.insert_one(:mongo, collection, documents) end)
    else
      # Logger.debug("DB: insert #{inspect(documents)} into #{collection}")
    end
  end

  def update(collection, match, document) do
    if @live do
      spawn(fn ->
        Mongo.update_many!(:mongo, collection, match, %{"$set" => document}, upsert: true)
      end)
    else
      # Logger.debug("DB: update #{inspect(match)} with #{inspect(document)} into #{collection}")
    end
  end

  def count(collection, query) do
    Mongo.count(:mongo, collection, query, pool: DBConnection.Poolboy)
  end
end
