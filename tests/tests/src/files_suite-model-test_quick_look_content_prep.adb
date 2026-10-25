separate (Files_Suite.Model)
   procedure Test_Quick_Look_Content_Prep (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Quick_Look.Content_Kind;

      function Many_Lines (Count : Positive) return String is
         Buffer : Unbounded_String;
      begin
         for I in 1 .. Count loop
            Append (Buffer, "line" & ASCII.LF);
         end loop;
         return To_String (Buffer);
      end Many_Lines;
   begin
      --  A short text file yields Text content with the leading lines.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "notes.txt", Filetype => "text/plain", Icon_Id => "text",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 12,
              Is_Image => False, Image_Path => "/tmp/notes.txt",
              Raw_Bytes => "alpha" & ASCII.LF & "beta" & ASCII.LF & "gamma");
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "a text file yields Text content");
         Files_Suite.Support.Assert_Equal (Natural (Content.Text_Lines.Length), 3, "all three short lines are carried");
         Files_Suite.Support.Assert_Equal
           (To_String (Content.Text_Lines.First_Element),
            "alpha",
            "the first line is preserved");
         Assert (not Content.Text_Truncated, "a short file is not truncated");
      end;

      --  An oversize text file is capped to Max_Preview_Lines and flagged.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "big.log", Filetype => "text/plain", Icon_Id => "text",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 9_999,
              Is_Image => False, Image_Path => "/tmp/big.log",
              Raw_Bytes => Many_Lines (Files.Quick_Look.Max_Preview_Lines + 25));
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "an oversize text file is still Text content");
         Assert
           (Natural (Content.Text_Lines.Length) <= Files.Quick_Look.Max_Preview_Lines,
            "the preview caps the number of lines");
         Assert (Content.Text_Truncated, "an oversize file is flagged truncated");
      end;

      --  A binary file (embedded NUL) falls back to the info card.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "app.bin", Filetype => "application/octet-stream", Icon_Id => "binary",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 64,
              Is_Image => False, Image_Path => "/tmp/app.bin",
              Raw_Bytes => "MZ" & ASCII.NUL & "payload");
      begin
         Assert (Content.Kind = Files.Quick_Look.Info_Content, "a binary file falls back to Info content");
      end;

      --  An image item yields Image content carrying its source path.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "photo.png", Filetype => "image/png", Icon_Id => "image",
              Kind => Files.Types.Regular_File_Item, Size_Available => True, Size => 2048,
              Is_Image => True, Image_Path => "/tmp/photo.png", Raw_Bytes => "");
      begin
         Assert (Content.Kind = Files.Quick_Look.Image_Content, "an image item yields Image content");
         Files_Suite.Support.Assert_Equal
           (To_String (Content.Image_Path),
            "/tmp/photo.png",
            "image content carries the source path");
      end;

      --  A directory yields the metadata info card with name and type.
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content :=
           Files.Quick_Look.Prepare_Content
             (Name => "Documents", Filetype => "inode/directory", Icon_Id => "folder",
              Kind => Files.Types.Directory_Item, Size_Available => False, Size => 0,
              Is_Image => False, Image_Path => "/tmp/Documents", Raw_Bytes => "");
      begin
         Assert (Content.Kind = Files.Quick_Look.Info_Content, "a directory yields Info content");
         Files_Suite.Support.Assert_Equal (To_String (Content.Name), "Documents", "info content carries the item name");
         Files_Suite.Support.Assert_Equal
           (To_String (Content.Filetype),
            "inode/directory",
            "info content carries the item type");
      end;
   end Test_Quick_Look_Content_Prep;
