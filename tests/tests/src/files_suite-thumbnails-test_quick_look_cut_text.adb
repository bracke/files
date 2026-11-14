with Guikit.Utf8;
separate (Files_Suite.Thumbnails)
   --  A text file longer than the preview's byte cap shows as truncated even
   --  with few lines, and the text shown never ends inside a cut-off line or
   --  a cut-off UTF-8 character.
   procedure Test_Quick_Look_Cut_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      --  U+20AC, three bytes: the 8 KiB cap falls inside one.
      Euro     : constant String := Character'Val (16#E2#) & Character'Val (16#82#) & Character'Val (16#AC#);

      --  Count characters of Euro, as one line.
      function Euros (Count : Positive) return String is
         Line : Unbounded_String;
      begin
         for Index in 1 .. Count loop
            Append (Line, Euro);
         end loop;
         return To_String (Line);
      end Euros;

      function Preview (Name : String) return Files.Quick_Look.Quick_Look_Content is
         Load : constant Files.File_System.Directory_Load_Result := Files.File_System.Load_Directory (Root, Settings);
      begin
         for Item of Load.Items loop
            if To_String (Item.Name) = Name then
               return Files.Operations.Prepare_Quick_Look (Item);
            end if;
         end loop;
         Assert (False, Name & " is listed");
         return (others => <>);
      end Preview;

      use type Files.Quick_Look.Content_Kind;
   begin
      Reset_Root;
      --  Three lines of about 6.8 KiB each, 20 KiB in all.
      Write_Binary_File
        (Join (Root, "three-lines.txt"),
         Euros (2_275) & ASCII.LF & Euros (2_275) & ASCII.LF & Euros (2_275) & ASCII.LF);
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content := Preview ("three-lines.txt");
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "the cut file previews as text");
         Assert (Content.Text_Truncated, "a file cut at the byte cap is truncated, with only three lines");
         Files_Suite.Support.Assert_Equal
           (Natural (Content.Text_Lines.Length), 1, "the line the cap cut off is not shown");
         Assert (Guikit.Utf8.Is_Valid (To_String (Content.Text_Lines.Last_Element)),
                 "the last shown text is whole UTF-8");
      end;

      --  One line longer than the cap: it is the only line, so it is kept, cut
      --  back to a whole character.
      Write_Binary_File (Join (Root, "one-line.txt"), Euros (6_827));
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content := Preview ("one-line.txt");
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "the long line previews as text");
         Assert (Content.Text_Truncated, "a single line cut at the byte cap is truncated");
         Files_Suite.Support.Assert_Equal
           (Natural (Content.Text_Lines.Length), 1, "the only line is kept");
         Assert (Length (Content.Text_Lines.Last_Element) > 0
                 and then Length (Content.Text_Lines.Last_Element) mod 3 = 0
                 and then Guikit.Utf8.Is_Valid (To_String (Content.Text_Lines.Last_Element)),
                 "the only line ends on a whole character");
      end;

      --  A short file that fits is neither cut nor truncated.
      Write_Binary_File (Join (Root, "short.txt"), Euros (3) & ASCII.LF & Euros (2));
      declare
         Content : constant Files.Quick_Look.Quick_Look_Content := Preview ("short.txt");
      begin
         Assert (Content.Kind = Files.Quick_Look.Text_Content, "the short file previews as text");
         Assert (not Content.Text_Truncated, "a file within the cap is not truncated");
         Files_Suite.Support.Assert_Equal
           (Natural (Content.Text_Lines.Length), 2, "a short file keeps its unterminated last line");
      end;
   end Test_Quick_Look_Cut_Text;
