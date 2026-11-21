separate (Files_Suite.Model)
   procedure Test_Text_Encoding_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Long_Text_Path : constant String := Join (Root, "long-line.txt");
      Utf8_Path : constant String := Join (Root, "utf8.txt");
      Binary_Text_Path : constant String := Join (Root, "binary.txt");
      Late_Binary_Text_Path : constant String := Join (Root, "late-binary.txt");
      Sampled_Text_Path : constant String := Join (Root, "sampled.txt");
      Huge_Oneline_Path : constant String := Join (Root, "huge-oneline.txt");
      Split_Utf8_Path : constant String := Join (Root, "split-utf8.txt");
      Overlong_Text_Path : constant String := Join (Root, "overlong.txt");
      Surrogate_Text_Path : constant String := Join (Root, "surrogate.txt");
      Markdown_Path : constant String := Join (Root, "notes.md");
      Utf16_Le_Path : constant String := Join (Root, "utf16le.txt");
      Utf16_Be_Path : constant String := Join (Root, "utf16be.txt");
      Unmarked_Utf16_Path : constant String := Join (Root, "unmarked-utf16.txt");
      Trailing_Le_Path : constant String := Join (Root, "trailing-utf16le.txt");
      Trailing_Be_Path : constant String := Join (Root, "trailing-utf16be.txt");
      NUL : constant Character := Character'Val (0);
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load      : Files.File_System.Directory_Load_Result;
      Found_Long_Text : Boolean := False;
      Found_Utf8 : Boolean := False;
      Found_Binary_Text : Boolean := False;
      Found_Late_Binary_Text : Boolean := False;
      Found_Sampled_Text : Boolean := False;
      Found_Huge_Oneline : Boolean := False;
      Found_Split_Utf8 : Boolean := False;
      Found_Overlong_Text : Boolean := False;
      Found_Surrogate_Text : Boolean := False;
      Found_Markdown : Boolean := False;
      Found_Utf16_Le : Boolean := False;
      Found_Utf16_Be : Boolean := False;
      Found_Unmarked_Utf16 : Boolean := False;
      Found_Trailing_Le : Boolean := False;
      Found_Trailing_Be : Boolean := False;
   begin
      Reset_Root;
      Write_File (Long_Text_Path, String'(1 .. 2048 => 'x'));
      Write_Binary_File (Utf8_Path, "caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File (Binary_Text_Path, "bad" & Character'Val (16#C3#));
      Write_Binary_File (Late_Binary_Text_Path, String'(1 .. 4096 => 'x') & Character'Val (0));
      --  A binary byte only past the 128 KiB encoding sample window: a bounded
      --  scan classifies this by its clean prefix and never reads the NUL.
      Write_Binary_File (Sampled_Text_Path, String'(1 .. 131_072 => 'x') & Character'Val (0));
      --  Bigger than the metadata readers' 8 MiB scan cap and newline-free until
      --  past it: a correctly capped line count stops early and reports the one
      --  trailing partial line (1, capped: "1+"), rather than reading the whole
      --  file to find the two newlines near its end.
      Write_Filler_File
        (Huge_Oneline_Path, 'x', 8_388_610, Character'Val (10) & "A" & Character'Val (10));
      Write_Binary_File
        (Split_Utf8_Path,
         String'(1 .. 4095 => 'x') & Character'Val (16#C3#) & Character'Val (16#A9#));
      Write_Binary_File
        (Overlong_Text_Path,
         "bad" & Character'Val (16#E0#) & Character'Val (16#80#) & Character'Val (16#80#));
      Write_Binary_File
        (Surrogate_Text_Path,
         "bad" & Character'Val (16#ED#) & Character'Val (16#A0#) & Character'Val (16#80#));
      Write_File (Markdown_Path, "# Title" & ASCII.LF & "body");
      --  UTF-16 text, which content search and Quick Look read as text: named
      --  as UTF-16, not as binary for its NUL bytes.
      Write_Binary_File
        (Utf16_Le_Path,
         Character'Val (16#FF#) & Character'Val (16#FE#) & "a" & NUL & ASCII.LF & NUL & "b" & NUL);
      Write_Binary_File
        (Utf16_Be_Path,
         Character'Val (16#FE#) & Character'Val (16#FF#) & NUL & "a" & NUL & ASCII.LF & NUL & "b");
      Write_Binary_File (Unmarked_Utf16_Path, "h" & NUL & "i" & NUL & "!" & NUL);
      --  Two lines, each ending in a line feed: a UTF-16 line feed is a whole
      --  unit, not its 0A byte. U+0A0A (two 0A bytes) is no line feed, and the
      --  NUL after the last line feed starts no third line.
      Write_Binary_File
        (Trailing_Le_Path,
         Character'Val (16#FF#) & Character'Val (16#FE#) & "a" & NUL
         & ASCII.LF & ASCII.LF & ASCII.LF & NUL & "b" & NUL & ASCII.LF & NUL);
      Write_Binary_File
        (Trailing_Be_Path,
         Character'Val (16#FE#) & Character'Val (16#FF#) & NUL & "a"
         & ASCII.LF & ASCII.LF & NUL & ASCII.LF & NUL & "b" & NUL & ASCII.LF);

      Load := Files.File_System.Load_Directory (Root, Settings);

      for Item of Load.Items loop
         if To_String (Item.Name) = "long-line.txt" then
            Found_Long_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|ascii",
               "long text lines count as one physical line");
         elsif To_String (Item.Name) = "utf8.txt" then
            Found_Utf8 := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|utf8",
               "UTF-8 text files expose text encoding metadata");
         elsif To_String (Item.Name) = "binary.txt" then
            Found_Binary_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "invalid text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "late-binary.txt" then
            Found_Late_Binary_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "text encoding metadata scans beyond the first read buffer");
         elsif To_String (Item.Name) = "sampled.txt" then
            Found_Sampled_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|ascii",
               "text encoding sampling stops at a bounded prefix, not the whole file");
         elsif To_String (Item.Name) = "huge-oneline.txt" then
            Found_Huge_Oneline := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1+|ascii",
               "line counting stops at the byte-scan cap instead of reading a huge file, and says so");
         elsif To_String (Item.Name) = "split-utf8.txt" then
            Found_Split_Utf8 := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|utf8",
               "text encoding metadata accepts UTF-8 split across read buffers");
         elsif To_String (Item.Name) = "overlong.txt" then
            Found_Overlong_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "overlong UTF-8 text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "surrogate.txt" then
            Found_Surrogate_Text := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|binary",
               "surrogate UTF-8 text files expose binary encoding metadata");
         elsif To_String (Item.Name) = "utf16le.txt" then
            Found_Utf16_Le := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|2|utf16le",
               "UTF-16 text with a little-endian byte order mark is named UTF-16 LE");
         elsif To_String (Item.Name) = "utf16be.txt" then
            Found_Utf16_Be := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|2|utf16be",
               "UTF-16 text with a big-endian byte order mark is named UTF-16 BE");
         elsif To_String (Item.Name) = "unmarked-utf16.txt" then
            Found_Unmarked_Utf16 := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|1|utf16le",
               "UTF-16 text without a byte order mark is named as the search reads it");
         elsif To_String (Item.Name) = "trailing-utf16le.txt" then
            Found_Trailing_Le := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|2|utf16le",
               "a UTF-16 LE file ending in a line feed counts its lines by unit");
         elsif To_String (Item.Name) = "trailing-utf16be.txt" then
            Found_Trailing_Be := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "text.lines_encoding|2|utf16be",
               "a UTF-16 BE file ending in a line feed counts its lines by unit");
         elsif To_String (Item.Name) = "notes.md" then
            Found_Markdown := True;
            Files_Suite.Support.Assert_Equal
              (Item_Extra (Item),
               "markdown.lines_encoding|2|ascii",
               "Markdown files expose markdown line and encoding metadata");
         end if;
      end loop;

      Assert (Found_Long_Text, "long text line item was loaded");
      Assert (Found_Utf8, "UTF-8 text item was loaded");
      Assert (Found_Binary_Text, "binary text item was loaded");
      Assert (Found_Late_Binary_Text, "late binary text item was loaded");
      Assert (Found_Sampled_Text, "sampled text item was loaded");
      Assert (Found_Huge_Oneline, "huge single-line text item was loaded");
      Assert (Found_Split_Utf8, "split UTF-8 text item was loaded");
      Assert (Found_Overlong_Text, "overlong UTF-8 text item was loaded");
      Assert (Found_Surrogate_Text, "surrogate UTF-8 text item was loaded");
      Assert (Found_Markdown, "Markdown item was loaded");
      Assert (Found_Utf16_Le, "UTF-16 LE item was loaded");
      Assert (Found_Utf16_Be, "UTF-16 BE item was loaded");
      Assert (Found_Unmarked_Utf16, "unmarked UTF-16 item was loaded");
      Assert (Found_Trailing_Le, "UTF-16 LE item with a trailing line feed was loaded");
      Assert (Found_Trailing_Be, "UTF-16 BE item with a trailing line feed was loaded");
   end Test_Text_Encoding_Metadata;
