separate (Files_Suite.Operations)
   procedure Write_Info_Metadata_Fixtures is
      procedure Write_Late_JPEG (Path : String) is
         use type Ada.Streams.Stream_IO.Count;
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         String'Write
           (Ada.Streams.Stream_IO.Stream (File), Byte (16#FF#) & Byte (16#D8#));
         --  Sparse APP segments put the first dimensions marker just beyond
         --  the metadata scan budget without writing an eight-megabyte fixture.
         for Segment in 1 .. 128 loop
            String'Write
              (Ada.Streams.Stream_IO.Stream (File),
               Byte (16#FF#) & Byte (16#E0#) & Byte (16#FF#) & Byte (16#FF#));
            Ada.Streams.Stream_IO.Set_Index
              (File, Ada.Streams.Stream_IO.Index (File) +
                 Ada.Streams.Stream_IO.Count (65_533));
         end loop;
         String'Write
           (Ada.Streams.Stream_IO.Stream (File),
            Byte (16#FF#) & Byte (16#C0#) & Byte (0) & Byte (7) & Byte (8) &
            Byte (0) & Byte (16) & Byte (0) & Byte (32));
         Ada.Streams.Stream_IO.Close (File);
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Write_Late_JPEG;
   begin
      Write_File (Join (Root, "meta.txt"), "abcd");
      Write_File (Join (Root, "zmarkdown.md"), "# Title" & ASCII.LF & "body");
      Write_Binary_File (Join (Root, "zsheet.xlsx"), "PK" & Character'Val (1) & Character'Val (2));
      Write_Binary_File
        (Join (Root, "zbinary.pdf"),
         "%PDF-1.7" & Character'Val (16#FF#) & ASCII.LF
         & "1 0 obj <</Type /Page>>" & ASCII.LF
         & "2 0 obj <</Type /Pages /Count 1>>");
      Write_Binary_File (Join (Root, "zutf8.txt"), "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Join (Root, "zbinary.txt"), "bad" & Character'Val (16#C3#));
      Write_File
        (Join (Root, "zunit.adb"),
         "procedure Unit is" & ASCII.LF & "begin" & ASCII.LF & "null;" & ASCII.LF & "end;");
      Write_File (Join (Root, "zdata.json"), "{""ok"":true}");
      Write_File (Join (Root, "zdoc.xml"), "<root/>");
      Write_Binary_File
        (Join (Root, "zheader.png"),
         Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) &
         Byte (16#1A#) & Byte (16#0A#) & Byte (0) & Byte (0) & Byte (0) &
         Byte (13) & "IHDR" & Byte (0) & Byte (0) & Byte (0) & Byte (32) &
         Byte (0) & Byte (0) & Byte (0) & Byte (16));
      Write_Binary_File
        (Join (Root, "zbad.png"),
         Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) &
         Byte (16#1A#) & Byte (16#0A#) & Byte (0) & Byte (0) & Byte (0) &
         Byte (13) & "NOPE" & Byte (0) & Byte (0) & Byte (0) & Byte (32) &
         Byte (0) & Byte (0) & Byte (0) & Byte (16));
      Write_Late_JPEG (Join (Root, "zlate.jpg"));
   end Write_Info_Metadata_Fixtures;
