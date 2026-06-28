with Ada.Characters.Handling;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with Textrender.Fonts;

with Files.UTF8;

package body Files.Fonts is
   use Ada.Strings.Unbounded;
   use type Ada.Directories.File_Kind;
   use type Textrender.Fonts.Glyph_Lookup_Result;
   use type Textrender.Fonts.Load_Result;

   type Font_Path_Array is array (Positive range <>) of Unbounded_String;
   package Font_Path_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Unbounded_String);

   Max_Discovered_Fonts : constant Natural := 256;
   Max_Search_Depth : constant Natural := 4;

   Candidate_Paths : constant Font_Path_Array :=
     [To_Unbounded_String ("/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/noto/NotoMono-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/vlgothic/VL-Gothic-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/vlgothic/VL-PGothic-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"),
      To_Unbounded_String ("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
      To_Unbounded_String ("/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc"),
      To_Unbounded_String ("/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc"),
      To_Unbounded_String ("/usr/share/fonts/truetype/noto/NotoSerifCJK-Regular.ttc"),
      To_Unbounded_String ("/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/unifont/unifont.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/freefont/FreeSans.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"),
      To_Unbounded_String ("/usr/share/fonts/truetype/fonts-japanese-gothic.ttf"),
      To_Unbounded_String ("/System/Library/Fonts/PingFang.ttc"),
      To_Unbounded_String ("C:\Windows\Fonts\malgun.ttf"),
      To_Unbounded_String ("C:\Windows\Fonts\msgothic.ttc"),
      To_Unbounded_String ("C:\Windows\Fonts\seguiemj.ttf"),
      To_Unbounded_String ("C:\Windows\Fonts\segoeui.ttf"),
      To_Unbounded_String ("C:\Windows\Fonts\arial.ttf")];

   Cached_Default_Override : Unbounded_String;
   Cached_Default_Path     : Unbounded_String;
   Cached_Default_Ready    : Boolean := False;
   Cached_Text_Override    : Unbounded_String;
   Cached_Text_Input       : Unbounded_String;
   Cached_Text_Path        : Unbounded_String;
   Cached_Text_Ready       : Boolean := False;

   Font_Search_Roots : constant Font_Path_Array :=
     [To_Unbounded_String ("/usr/share/fonts"),
      To_Unbounded_String ("/usr/local/share/fonts"),
      To_Unbounded_String ("/Library/Fonts"),
      To_Unbounded_String ("/System/Library/Fonts")];

   function Safe_Environment_Value
     (Name : String)
      return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Is_Ordinary_File
     (Path : String)
      return Boolean is
   begin
      return Path /= ""
        and then Ada.Directories.Exists (Path)
        and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File;
   exception
      when others =>
         return False;
   end Is_Ordinary_File;

   function To_Lower
     (Text : String)
      return String
   is
      Result : String (Text'Range);
   begin
      for Index in Text'Range loop
         Result (Index) := Ada.Characters.Handling.To_Lower (Text (Index));
      end loop;

      return Result;
   end To_Lower;

   function Has_Suffix
     (Text   : String;
      Suffix : String)
      return Boolean is
   begin
      return Text'Length >= Suffix'Length
        and then Text (Text'Last - Suffix'Length + 1 .. Text'Last) = Suffix;
   end Has_Suffix;

   function Is_Font_File
     (Path : String)
      return Boolean
   is
      Lower : constant String := To_Lower (Path);
   begin
      return Has_Suffix (Lower, ".ttf")
        or else Has_Suffix (Lower, ".otf");
   end Is_Font_File;

   function Is_Known_Unsupported_Renderer_Font
     (Path : String)
      return Boolean
   is
      --  Match the file's simple name, not the whole path, so a font merely
      --  living in a directory whose name contains one of these substrings
      --  (e.g. ".../liberation/SomeOtherFont.ttf", or an explicit
      --  FILES_FONT_PATH under such a directory) is not wrongly blocked.
      function Simple_Name return String is
      begin
         return Ada.Directories.Simple_Name (Path);
      exception
         when others =>
            return Path;
      end Simple_Name;

      Lower : constant String := To_Lower (Simple_Name);
   begin
      return Ada.Strings.Fixed.Index (Lower, "droidsansfallbackfull.ttf") > 0
        or else Ada.Strings.Fixed.Index (Lower, "liberation") > 0
        or else Ada.Strings.Fixed.Index (Lower, "notocoloremoji.ttf") > 0
        or else Ada.Strings.Fixed.Index (Lower, "unifont.ttf") > 0;
   end Is_Known_Unsupported_Renderer_Font;

   procedure Append_Unique
     (Paths : in out Font_Path_Vectors.Vector;
      Path  : String) is
   begin
      if Path = "" then
         return;
      end if;

      for Existing of Paths loop
         if To_String (Existing) = Path then
            return;
         end if;
      end loop;

      Paths.Append (To_Unbounded_String (Path));
   end Append_Unique;

   procedure Sort_Paths
     (Paths : in out Font_Path_Vectors.Vector)
   is
      Best : Positive;
      Temp : Unbounded_String;
   begin
      if Natural (Paths.Length) < 2 then
         return;
      end if;

      for Left in Paths.First_Index .. Paths.Last_Index - 1 loop
         Best := Left;
         for Right in Left + 1 .. Paths.Last_Index loop
            if To_String (Paths.Element (Right)) < To_String (Paths.Element (Best)) then
               Best := Right;
            end if;
         end loop;

         if Best /= Left then
            Temp := Paths.Element (Left);
            Paths.Replace_Element (Left, Paths.Element (Best));
            Paths.Replace_Element (Best, Temp);
         end if;
      end loop;
   end Sort_Paths;

   procedure Scan_Font_Directory
     (Paths : in out Font_Path_Vectors.Vector;
      Root  : String;
      Depth : Natural)
   is
      Search  : Ada.Directories.Search_Type;
      Font_Entry : Ada.Directories.Directory_Entry_Type;
      Started : Boolean := False;
   begin
      if Natural (Paths.Length) >= Max_Discovered_Fonts
        or else Depth > Max_Search_Depth
        or else Root = ""
        or else not Ada.Directories.Exists (Root)
        or else Ada.Directories.Kind (Root) /= Ada.Directories.Directory
      then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Root,
         "",
         [Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search)
        and then Natural (Paths.Length) < Max_Discovered_Fonts
      loop
         Ada.Directories.Get_Next_Entry (Search, Font_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Font_Entry);
            Full : constant String := Ada.Directories.Full_Name (Font_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               if Ada.Directories.Kind (Font_Entry) = Ada.Directories.Directory then
                  Scan_Font_Directory (Paths, Full, Depth + 1);
               elsif Is_Font_File (Full) and then not Is_Known_Unsupported_Renderer_Font (Full) then
                  Append_Unique (Paths, Full);
               end if;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Started then
            begin
               Ada.Directories.End_Search (Search);
            exception
               when others =>
                  null;
            end;
         end if;
   end Scan_Font_Directory;

   function Candidate_Fonts return Font_Path_Vectors.Vector is
      Paths      : Font_Path_Vectors.Vector;
      Discovered : Font_Path_Vectors.Vector;
   begin
      for Path of Candidate_Paths loop
         if Is_Font_File (To_String (Path))
           and then not Is_Known_Unsupported_Renderer_Font (To_String (Path))
         then
            Append_Unique (Paths, To_String (Path));
         end if;
      end loop;

      for Root of Font_Search_Roots loop
         Scan_Font_Directory (Discovered, To_String (Root), 0);
      end loop;

      Sort_Paths (Discovered);
      for Path of Discovered loop
         Append_Unique (Paths, To_String (Path));
      end loop;

      return Paths;
   end Candidate_Fonts;

   function Is_Loadable_Font
     (Path : String)
      return Boolean
   is
      Font : Textrender.Fonts.Font;

      function Has_Drawable_Glyph
        (Codepoint : Textrender.Fonts.Codepoint)
         return Boolean
      is
         Glyph : Textrender.Fonts.Glyph_Info;
      begin
         return Textrender.Fonts.Lookup_Glyph (Font, Codepoint, Glyph) = Textrender.Fonts.Glyph_Found
           and then not Glyph.Is_Empty;
      end Has_Drawable_Glyph;

      function Has_Drawable_ASCII_Sample return Boolean is
         Sample : constant String := "files/tmp-09.txt";
      begin
         for Char of Sample loop
            if not Has_Drawable_Glyph (Textrender.Fonts.Codepoint (Character'Pos (Char))) then
               return False;
            end if;
         end loop;

         return True;
      end Has_Drawable_ASCII_Sample;
   begin
      if not Is_Ordinary_File (Path) then
         return False;
      elsif Is_Known_Unsupported_Renderer_Font (Path) then
         return False;
      end if;

      if Textrender.Fonts.Load (Font, Path) /= Textrender.Fonts.Loaded then
         Textrender.Fonts.Reset (Font);
         return False;
      end if;

      if not Has_Drawable_ASCII_Sample
        or else not Has_Drawable_Glyph (Textrender.Fonts.Codepoint (Character'Pos ('?')))
      then
         Textrender.Fonts.Reset (Font);
         return False;
      end if;
      Textrender.Fonts.Reset (Font);
      return True;
   exception
      when others =>
         Textrender.Fonts.Reset (Font);
         return False;
   end Is_Loadable_Font;

   function Glyph_Coverage_Score
     (Path : String)
      return Integer
   is
      type Codepoint_Array is array (Positive range <>) of Textrender.Fonts.Codepoint;

      Probe_Codepoints : constant Codepoint_Array :=
        [16#00E5#,
         16#00E6#,
         16#00E9#,
         16#00F8#,
         16#00FC#,
         16#0142#,
         16#00F1#,
         16#0416#,
         16#0439#,
         16#03A9#,
         16#05D0#,
         16#0627#,
         16#0905#,
         16#3042#,
         16#AC00#,
         16#6587#,
         16#4EF6#];
      Score            : Integer := 0;
      Font             : Textrender.Fonts.Font;
      Glyph            : Textrender.Fonts.Glyph_Info;
   begin
      if not Is_Loadable_Font (Path) then
         return -1;
      end if;

      if Textrender.Fonts.Load (Font, Path) /= Textrender.Fonts.Loaded then
         Textrender.Fonts.Reset (Font);
         return -1;
      end if;

      for Codepoint of Probe_Codepoints loop
         if Textrender.Fonts.Lookup_Glyph (Font, Codepoint, Glyph) = Textrender.Fonts.Glyph_Found
           and then not Glyph.Is_Empty
         then
            Score := Score + 1;
         end if;
      end loop;
      Textrender.Fonts.Reset (Font);
      return Score;
   exception
      when others =>
         Textrender.Fonts.Reset (Font);
         return -1;
   end Glyph_Coverage_Score;

   function Text_Coverage_Score
     (Path : String;
      Text : String)
      return Integer
   is
      Index     : Integer := Text'First;
      Codepoint : Natural := 0;
      Score     : Integer := 0;
      Missing   : Natural := 0;
      Font      : Textrender.Fonts.Font;
      Glyph     : Textrender.Fonts.Glyph_Info;
   begin
      if not Is_Loadable_Font (Path) then
         return Integer'First;
      end if;

      if Textrender.Fonts.Load (Font, Path) /= Textrender.Fonts.Loaded then
         Textrender.Fonts.Reset (Font);
         return Integer'First;
      end if;

      while Index <= Text'Last loop
         declare
            Unit_Start : constant Integer := Index;
         begin
            Files.UTF8.Decode_Next_Display_Codepoint (Text, Index, Codepoint);
            if Codepoint > 16#7F#
              and then Codepoint <= 16#10FFFF#
              and then
                (Files.UTF8.Display_Units (Text (Unit_Start .. Index - 1)) > 0
                 or else Files.UTF8.Is_Required_Zero_Width_Codepoint (Codepoint))
            then
               if Textrender.Fonts.Lookup_Glyph
                    (Font, Textrender.Fonts.Codepoint (Codepoint), Glyph) = Textrender.Fonts.Glyph_Found
                 and then
                   (not Glyph.Is_Empty
                    or else Files.UTF8.Is_Required_Zero_Width_Codepoint (Codepoint))
               then
                  Score := Score + 1;
               else
                  Missing := Missing + 1;
               end if;
            end if;
         end;
      end loop;

      Textrender.Fonts.Reset (Font);
      if Missing > Natural (Integer'Last / 1_000) then
         return Integer'First;
      end if;

      return Score - Integer (Missing) * 1_000;
   exception
      when others =>
         Textrender.Fonts.Reset (Font);
         return Integer'First;
   end Text_Coverage_Score;

   function Default_Font_Path return String is
      Override_Path : constant String := Safe_Environment_Value ("FILES_FONT_PATH");
      Best_Path  : Unbounded_String;
      Best_Score : Integer := -1;

      procedure Remember (Path : String) is
      begin
         Cached_Default_Override := To_Unbounded_String (Override_Path);
         Cached_Default_Path := To_Unbounded_String (Path);
         Cached_Default_Ready := True;
      end Remember;
   begin
      if Cached_Default_Ready
        and then To_String (Cached_Default_Override) = Override_Path
      then
         return To_String (Cached_Default_Path);
      end if;

      if Is_Loadable_Font (Override_Path) then
         Remember (Override_Path);
         return Override_Path;
      end if;

      for Path of Candidate_Paths loop
         if Is_Font_File (To_String (Path))
           and then not Is_Known_Unsupported_Renderer_Font (To_String (Path))
           and then Is_Loadable_Font (To_String (Path))
         then
            Remember (To_String (Path));
            return To_String (Path);
         end if;
      end loop;

      declare
         Candidates : constant Font_Path_Vectors.Vector := Candidate_Fonts;
      begin
         for Path of Candidates loop
            declare
               Value : constant String := To_String (Path);
               Score : constant Integer := Glyph_Coverage_Score (Value);
            begin
               if Score > Best_Score then
                  Best_Path := Path;
                  Best_Score := Score;
               end if;
            end;
         end loop;
      end;

      if Best_Score >= 0 then
         Remember (To_String (Best_Path));
         return To_String (Best_Path);
      end if;

      Remember ("");
      return "";
   exception
      when others =>
         return "";
   end Default_Font_Path;

   function Font_Path_For_Text
     (Text : String)
      return String
   is
      Override_Path : constant String := Safe_Environment_Value ("FILES_FONT_PATH");
      Default_Path  : constant String := Default_Font_Path;
      Best_Path     : Unbounded_String := To_Unbounded_String (Default_Path);
      Best_Text     : Integer := Text_Coverage_Score (Default_Path, Text);
      Best_Static   : Integer := Glyph_Coverage_Score (Default_Path);

      procedure Consider_Font (Path : String) is
         Text_Score   : constant Integer := Text_Coverage_Score (Path, Text);
         Static_Score : constant Integer := Glyph_Coverage_Score (Path);
      begin
         if Text_Score = Integer'First or else Static_Score < 0 then
            return;
         end if;

         if Text_Score > Best_Text
           or else (Text_Score = Best_Text and then Static_Score > Best_Static)
         then
            Best_Path := To_Unbounded_String (Path);
            Best_Text := Text_Score;
            Best_Static := Static_Score;
         end if;
      end Consider_Font;

      procedure Remember (Path : String) is
      begin
         Cached_Text_Override := To_Unbounded_String (Override_Path);
         Cached_Text_Input := To_Unbounded_String (Text);
         Cached_Text_Path := To_Unbounded_String (Path);
         Cached_Text_Ready := True;
      end Remember;
   begin
      if Cached_Text_Ready
        and then To_String (Cached_Text_Override) = Override_Path
        and then To_String (Cached_Text_Input) = Text
      then
         return To_String (Cached_Text_Path);
      end if;

      if Text = "" then
         Remember (Default_Path);
         return Default_Path;
      elsif Is_Loadable_Font (Override_Path) then
         Consider_Font (Override_Path);
      end if;

      if Best_Text >= 0 then
         Remember (To_String (Best_Path));
         return To_String (Best_Path);
      end if;

      for Path of Candidate_Paths loop
         if Is_Font_File (To_String (Path))
           and then not Is_Known_Unsupported_Renderer_Font (To_String (Path))
         then
            Consider_Font (To_String (Path));
         end if;
      end loop;

      if Best_Text < 0 then
         declare
            Candidates : constant Font_Path_Vectors.Vector := Candidate_Fonts;
         begin
            for Path of Candidates loop
               Consider_Font (To_String (Path));
            end loop;
         end;
      end if;

      Remember (To_String (Best_Path));
      return To_String (Best_Path);
   exception
      when others =>
         return Default_Path;
   end Font_Path_For_Text;

end Files.Fonts;
