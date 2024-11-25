defmodule Helpers do
  def debug! do
    Logger.configure(level: :debug)
  end

  def info! do
    Logger.configure(level: :info)
  end

  def warning! do
    Logger.configure(level: :warning)
  end
end

import Helpers
