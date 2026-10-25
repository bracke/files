separate (Files_Suite.Model)
   procedure Test_Grouping_Band_Edges (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Today : constant Ada.Calendar.Time := Files.Grouping.Day_Start (Ada.Calendar.Clock);
      Day   : constant Duration := 86_400.0;

      function Typed (Kind : Files.Types.Item_Kind; Filetype : String) return Positive is
        (Files.Grouping.Band_Of
           (Files.Types.Group_By_Type, Kind, Filetype, False, Today, False, 0, Files.Types.No_Label, Today));

      function Dated (Known : Boolean; At_Time : Ada.Calendar.Time) return Positive is
        (Files.Grouping.Band_Of
           (Files.Types.Group_By_Modified, Files.Types.Regular_File_Item, "", Known, At_Time, False, 0,
            Files.Types.No_Label, Today));

      function Sized (Known : Boolean; Size : Long_Long_Integer) return Positive is
        (Files.Grouping.Band_Of
           (Files.Types.Group_By_Size, Files.Types.Regular_File_Item, "", False, Today, Known, Size,
            Files.Types.No_Label, Today));

      Mib : constant Long_Long_Integer := 1024 * 1024;
   begin
      Files_Suite.Support.Assert_Equal (Typed (Files.Types.Directory_Item, ""), 1, "folders come first");
      Files_Suite.Support.Assert_Equal
        (Typed (Files.Types.Regular_File_Item, "IMAGE/PNG"),
         2,
         "image types, in any case");
      Assert (Typed (Files.Types.Regular_File_Item, "audio/flac") = 3
              and then Typed (Files.Types.Regular_File_Item, "video/mp4") = 4, "audio, then video");
      Files_Suite.Support.Assert_Equal
        (Typed (Files.Types.Regular_File_Item, "text/plain"), 5, "documents (text/plain)");
      Files_Suite.Support.Assert_Equal
        (Typed (Files.Types.Regular_File_Item, "application/pdf"), 5, "documents (application/pdf)");
      Files_Suite.Support.Assert_Equal
        (Typed (Files.Types.Regular_File_Item, "application/vnd.oasis.opendocument.text"),
         5,
         "documents (application/vnd.oasis.opendocument.text)");
      Assert (Typed (Files.Types.Regular_File_Item, "application/zip") = 6
              and then Typed (Files.Types.Regular_File_Item, "application/x-7z-compressed") = 6, "archives");
      Assert (Typed (Files.Types.Regular_File_Item, "application/octet-stream") = 7
              and then Typed (Files.Types.Regular_File_Item, "") = 7, "everything else last");

      Assert (Dated (True, Today) = 1 and then Dated (True, Ada.Calendar.Clock) = 1, "today, from midnight on");
      Files_Suite.Support.Assert_Equal
        (Dated (True, Today + 3.0 * Day),
         1,
         "a time past now counts as today, not as earlier");
      Assert (Dated (True, Today - 1.0) = 2 and then Dated (True, Today - 6.0 * Day + 60.0) = 2,
              "the six days before today");
      Files_Suite.Support.Assert_Equal (Dated (True, Today - 7.0 * Day), 3, "older than that");
      Files_Suite.Support.Assert_Equal (Dated (False, Today), 4, "an unknown time last");

      Assert (Sized (True, 0) = 1 and then Sized (True, -5) = 1, "empty");
      Assert (Sized (True, 1) = 2 and then Sized (True, Mib - 1) = 2, "under a MiB");
      Assert (Sized (True, Mib) = 3 and then Sized (True, 1024 * Mib - 1) = 3, "under a GiB");
      Files_Suite.Support.Assert_Equal (Sized (True, 1024 * Mib), 4, "a GiB and up");
      Files_Suite.Support.Assert_Equal (Sized (False, 0), 5, "an unknown size last");
   end Test_Grouping_Band_Edges;
