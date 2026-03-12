defmodule MusicLibrary.RecordsOnThisDayEmailTest do
  use MusicLibrary.DataCase

  import Swoosh.TestAssertions

  alias MusicLibrary.Fixtures
  alias MusicLibrary.Records.Record
  alias MusicLibrary.RecordsOnThisDayEmail

  setup do
    Application.put_env(:music_library, RecordsOnThisDayEmail,
      from_email: "test@example.com",
      to_email: "recipient@example.com",
      mailer: MusicLibrary.Mailer,
      base_url: "http://localhost:4000"
    )

    on_exit(fn ->
      Application.delete_env(:music_library, RecordsOnThisDayEmail)
    end)
  end

  describe "send/1" do
    test "sends email when records match the date" do
      # Create a record with a release date matching March 5
      record =
        Fixtures.Records.record(%{
          release_date: "2020-03-05",
          title: "Test Album"
        })

      date = ~D[2025-03-05]
      assert {:ok, :sent} = RecordsOnThisDayEmail.send(date)

      assert_email_sent(fn email ->
        assert email.subject =~ "Records on 5 March"
        html = email.html_body
        assert html =~ record.title
        assert html =~ Record.artist_names(record)
        assert html =~ "5 years ago"
        assert html =~ "http://localhost:4000/collection/#{record.id}"
      end)
    end

    test "skips sending when no records match" do
      # Create a record with a release date that won't match
      Fixtures.Records.record(%{release_date: "2020-01-01"})

      date = ~D[2025-06-15]
      assert {:ok, :no_records} = RecordsOnThisDayEmail.send(date)

      refute_email_sent()
    end

    test "groups records with the same musicbrainz_id" do
      shared_mbid = Ecto.UUID.generate()

      cd =
        Fixtures.Records.record(%{
          release_date: "2020-03-05",
          title: "Grouped Album",
          musicbrainz_id: shared_mbid,
          format: :cd
        })

      vinyl =
        Fixtures.Records.record(%{
          release_date: "2020-03-05",
          title: "Grouped Album",
          musicbrainz_id: shared_mbid,
          format: :vinyl
        })

      date = ~D[2025-03-05]
      assert {:ok, :sent} = RecordsOnThisDayEmail.send(date)

      assert_email_sent(fn email ->
        html = email.html_body
        # Title appears once as group header
        assert html =~ "Grouped Album"
        assert html =~ "5 years ago"
        # Both formats appear as sub-items
        assert html =~ "CD"
        assert html =~ "Vinyl"
        # Both records have detail links
        assert html =~ "/collection/#{cd.id}"
        assert html =~ "/collection/#{vinyl.id}"
      end)
    end

    test "shows anniversary styling for milestone years" do
      # 10 year anniversary (gold)
      Fixtures.Records.record(%{
        release_date: "2015-07-20",
        title: "Gold Anniversary Album"
      })

      date = ~D[2025-07-20]
      assert {:ok, :sent} = RecordsOnThisDayEmail.send(date)

      assert_email_sent(fn email ->
        html = email.html_body
        assert html =~ "Gold Anniversary Album"
        assert html =~ "10 years ago"
        # Gold color
        assert html =~ "#b45309"
      end)
    end
  end
end
