defmodule Helpers do
  def debug! do
    Logger.configure(level: :debug)
  end

  def info! do
    Logger.configure(level: :info)
  end
end

import Helpers
