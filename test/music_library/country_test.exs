defmodule MusicLibrary.CountryTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.Country

  describe "to_emoji/1" do
    test "converts alpha-2 codes" do
      assert Country.to_emoji("US") == "🇺🇸"
      assert Country.to_emoji("PL") == "🇵🇱"
      assert Country.to_emoji("GB") == "🇬🇧"
    end

    test "is case insensitive" do
      assert Country.to_emoji("us") == "🇺🇸"
      assert Country.to_emoji("pl") == "🇵🇱"
    end

    test "converts subdivision codes" do
      assert Country.to_emoji("GB-SCT") == "🏴󠁧󠁢󠁳󠁣󠁴󠁿"
      assert Country.to_emoji("GB-WLS") == "🏴󠁧󠁢󠁷󠁬󠁳󠁿"
      assert Country.to_emoji("GB-ENG") == "🏴󠁧󠁢󠁥󠁮󠁧󠁿"
    end

    test "maps GB-CYM to GB-WLS" do
      assert Country.to_emoji("GB-CYM") == Country.to_emoji("GB-WLS")
    end

    test "converts alpha-3 codes" do
      assert Country.to_emoji("USA") == "🇺🇸"
      assert Country.to_emoji("GBR") == "🇬🇧"
      assert Country.to_emoji("POL") == "🇵🇱"
    end

    test "converts IETF language tags" do
      assert Country.to_emoji("en-US") == "🇺🇸"
      assert Country.to_emoji("pl-PL") == "🇵🇱"
    end
  end
end
