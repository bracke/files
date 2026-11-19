with Files.Diagnostics;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with Ada.Wide_Wide_Characters.Handling;
with I18N.Normalization;
with Guikit.Utf8;
with Hostkit.Path_Text;

package body Files.Types is

   function Is_Continuation (Value : Character) return Boolean is
      Code : constant Natural := Character'Pos (Value);
   begin
      return Code in 16#80# .. 16#BF#;
   end Is_Continuation;

   function Next_Scope (Scope : Search_Scope) return Search_Scope is
   begin
      case Scope is
         when Filter_Here =>
            return Search_Names;
         when Search_Names =>
            return Search_Contents;
         when Search_Contents =>
            return Filter_Here;
      end case;
   end Next_Scope;

   function Split_Path_List (List : String; Separator : Character) return String_Vectors.Vector is
      Result : String_Vectors.Vector;
      First  : Integer := List'First;
   begin
      for Index in List'Range loop
         if List (Index) = Separator then
            Result.Append (Ada.Strings.Unbounded.To_Unbounded_String (List (First .. Index - 1)));
            First := Index + 1;
         end if;
      end loop;
      Result.Append (Ada.Strings.Unbounded.To_Unbounded_String (List (First .. List'Last)));
      return Result;
   end Split_Path_List;

   function Trim_Blanks (Text : String) return String is
      First : Integer := Text'First;
      Last  : Integer := Text'Last;

      function Blank (Value : Character) return Boolean is
        (Value = ' ' or else Value = ASCII.HT or else Value = ASCII.CR);
   begin
      while First <= Last and then Blank (Text (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Blank (Text (Last)) loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Trim_Blanks;

   function Extension_Start (Name : String) return Natural is
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' then
            return (if Index > Name'First and then Index < Name'Last then Index else 0);
         end if;
      end loop;
      return 0;
   end Extension_Start;

   function Stem_Of (Name : String) return String is
      Dot : constant Natural := Extension_Start (Name);
   begin
      return (if Dot = 0 then Name else Name (Name'First .. Dot - 1));
   end Stem_Of;

   function Extension_Of (Name : String) return String is
      Dot : constant Natural := Extension_Start (Name);
   begin
      return (if Dot = 0 then "" else Name (Dot + 1 .. Name'Last));
   end Extension_Of;

   --  Whether a folder named Name is a package that shows as one item, its
   --  extension naming what it is (macOS's "Mail.app", "Photos.photoslibrary",
   --  "Notes.rtfd"): app, appex, bundle, component, framework, kext, mpkg,
   --  pkg, plugin, prefpane, qlgenerator, mdimporter, saver, xpc, rtfd,
   --  photoslibrary, xcodeproj, xcworkspace, playground, matched without
   --  regard to ASCII case.
   function Is_Package_Name (Name : String) return Boolean is
      E : constant String := To_Lower_Ascii (Extension_Of (Name));
   begin
      return E = "app" or else E = "appex" or else E = "bundle" or else E = "component"
        or else E = "framework" or else E = "kext" or else E = "mpkg" or else E = "pkg"
        or else E = "plugin" or else E = "prefpane" or else E = "qlgenerator" or else E = "mdimporter"
        or else E = "saver" or else E = "xpc" or else E = "rtfd" or else E = "photoslibrary"
        or else E = "xcodeproj" or else E = "xcworkspace" or else E = "playground";
   end Is_Package_Name;

   function Name_Stem (Name : String; Is_Directory : Boolean) return String is
     (if Is_Directory and then not Is_Package_Name (Name) then Name else Stem_Of (Name));

   function Name_Extension (Name : String; Is_Directory : Boolean) return String is
     (if Is_Directory and then not Is_Package_Name (Name) then "" else Extension_Of (Name));

   function Leaf_Of (Path : String) return String renames Hostkit.Path_Text.Leaf;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Text;

   function To_Lower_Ascii (Text : String) return String is
      Result : String := Text;
   begin
      for Char of Result loop
         if Char in 'A' .. 'Z' then
            Char := Character'Val (Character'Pos (Char) + 32);
         end if;
      end loop;
      return Result;
   end To_Lower_Ascii;

   function To_Lower_Unicode (Text : String) return String is
   begin
      if (for all C of Text => Character'Pos (C) < 128) or else not Guikit.Utf8.Is_Valid (Text) then
         return To_Lower_Ascii (Text);
      end if;
      return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
        (Ada.Wide_Wide_Characters.Handling.To_Lower (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Text)));
   end To_Lower_Unicode;

   function To_Upper_Ascii (Text : String) return String is
      Result : String := Text;
   begin
      for Char of Result loop
         Char := To_Upper_Ascii (Char);
      end loop;
      return Result;
   end To_Upper_Ascii;

   function Fold_For_Sort (Text : String) return String is
      --  Never a codepoint: marks a byte that starts no UTF-8 character.
      Invalid   : constant := 16#11_0000#;
      Result    : Ada.Strings.Unbounded.Unbounded_String;
      Index     : Integer := Text'First;
      Start     : Integer;
      Codepoint : Natural := 0;

      --  A combining mark: an accent stored as a character of its own.
      function Is_Mark (Value : Natural) return Boolean is
        (Value in 16#300# .. 16#36F# | 16#1AB0# .. 16#1AFF# | 16#1DC0# .. 16#1DFF#
                | 16#20D0# .. 16#20FF# | 16#FE20# .. 16#FE2F# | 16#3099# .. 16#309A#);

      --  Value in lower case, by the Unicode simple mapping Ada carries.
      function Lower (Value : Natural) return Natural is
      begin
         if Value < 16#80# then
            return (if Value in 16#41# .. 16#5A# then Value + 16#20# else Value);
         end if;
         return Wide_Wide_Character'Pos (Ada.Wide_Wide_Characters.Handling.To_Lower (Wide_Wide_Character'Val (Value)));
      end Lower;

      --  The base ASCII letter(s) of a lowercase Latin letter, or "" when it
      --  has none (a non-letter, or another script).
      function Latin_Base (Value : Natural) return String is
      begin
         case Value is
            when 16#E0# .. 16#E5# | 16#101# | 16#103# | 16#105# | 16#1CE# | 16#1DF# | 16#1E1# | 16#1FB#
               | 16#201# | 16#203# | 16#227# => return "a";
            when 16#E6# | 16#1E3# | 16#1FD# => return "ae";
            when 16#E7# | 16#107# | 16#109# | 16#10B# | 16#10D# => return "c";
            when 16#F0# | 16#10F# | 16#111# => return "d";
            when 16#E8# .. 16#EB# | 16#113# | 16#115# | 16#117# | 16#119# | 16#11B# | 16#205# | 16#207#
               | 16#229# => return "e";
            when 16#11D# | 16#11F# | 16#121# | 16#123# | 16#1E7# | 16#1F5# => return "g";
            when 16#125# | 16#127# | 16#21F# => return "h";
            when 16#EC# .. 16#EF# | 16#129# | 16#12B# | 16#12D# | 16#12F# | 16#131# | 16#1D0# | 16#209#
               | 16#20B# => return "i";
            when 16#135# | 16#1F0# => return "j";
            when 16#137# | 16#1E9# => return "k";
            when 16#13A# | 16#13C# | 16#13E# | 16#140# | 16#142# => return "l";
            when 16#F1# | 16#144# | 16#146# | 16#148# | 16#149# | 16#14B# | 16#1F9# => return "n";
            when 16#F2# .. 16#F6# | 16#F8# | 16#14D# | 16#14F# | 16#151# | 16#1A1# | 16#1D2# | 16#1EB#
               | 16#1ED# | 16#1FF# | 16#20D# | 16#20F# | 16#22B# | 16#22D# | 16#22F# | 16#231# => return "o";
            when 16#153# => return "oe";
            when 16#155# | 16#157# | 16#159# | 16#211# | 16#213# => return "r";
            when 16#15B# | 16#15D# | 16#15F# | 16#161# | 16#219# => return "s";
            when 16#163# | 16#165# | 16#167# | 16#21B# => return "t";
            when 16#FE# => return "th";
            when 16#F9# .. 16#FC# | 16#169# | 16#16B# | 16#16D# | 16#16F# | 16#171# | 16#173# | 16#1B0#
               | 16#1D4# | 16#1D6# | 16#1D8# | 16#1DA# | 16#1DC# | 16#215# | 16#217# => return "u";
            when 16#175# => return "w";
            when 16#FD# | 16#FF# | 16#177# | 16#233# => return "y";
            when 16#17A# | 16#17C# | 16#17E# => return "z";
            when 16#DF# => return "ss";
            --  Latin Extended Additional: the dotted, hooked and Vietnamese
            --  letters, each lower case at an odd codepoint after its capital.
            when 16#1E00# .. 16#1E95# =>
               case Value - Value mod 2 is
                  when 16#1E00# => return "a";
                  when 16#1E02# .. 16#1E06# => return "b";
                  when 16#1E08# => return "c";
                  when 16#1E0A# .. 16#1E12# => return "d";
                  when 16#1E14# .. 16#1E1C# => return "e";
                  when 16#1E1E# => return "f";
                  when 16#1E20# => return "g";
                  when 16#1E22# .. 16#1E2A# => return "h";
                  when 16#1E2C# .. 16#1E2E# => return "i";
                  when 16#1E30# .. 16#1E34# => return "k";
                  when 16#1E36# .. 16#1E3C# => return "l";
                  when 16#1E3E# .. 16#1E42# => return "m";
                  when 16#1E44# .. 16#1E4A# => return "n";
                  when 16#1E4C# .. 16#1E52# => return "o";
                  when 16#1E54# .. 16#1E56# => return "p";
                  when 16#1E58# .. 16#1E5E# => return "r";
                  when 16#1E60# .. 16#1E68# => return "s";
                  when 16#1E6A# .. 16#1E70# => return "t";
                  when 16#1E72# .. 16#1E7A# => return "u";
                  when 16#1E7C# .. 16#1E7E# => return "v";
                  when 16#1E80# .. 16#1E88# => return "w";
                  when 16#1E8A# .. 16#1E8C# => return "x";
                  when 16#1E8E# => return "y";
                  when others => return "z";
               end case;
            when 16#1E96# => return "h";
            when 16#1E97# => return "t";
            when 16#1E98# => return "w";
            when 16#1E99# => return "y";
            when 16#1EA0# .. 16#1EB7# => return "a";
            when 16#1EB8# .. 16#1EC7# => return "e";
            when 16#1EC8# .. 16#1ECB# => return "i";
            when 16#1ECC# .. 16#1EE3# => return "o";
            when 16#1EE4# .. 16#1EF1# => return "u";
            when 16#1EF2# .. 16#1EF9# => return "y";
            when others => return "";
         end case;
      end Latin_Base;

      --  The base letter of a polytonic Greek letter (U+1F00 .. U+1FFF, the
      --  breathings, accents and iota subscript of ancient and liturgical
      --  Greek), upper or lower case; Value itself for the block's spacing
      --  marks and gaps.
      function Polytonic_Base (Value : Natural) return Natural is
         Alpha   : constant := 16#3B1#;
         Epsilon : constant := 16#3B5#;
         Eta     : constant := 16#3B7#;
         Iota    : constant := 16#3B9#;
         Omicron : constant := 16#3BF#;
         Rho     : constant := 16#3C1#;
         Upsilon : constant := 16#3C5#;
         Omega   : constant := 16#3C9#;
      begin
         case Value is
            when 16#1F00# .. 16#1F0F# | 16#1F70# .. 16#1F71# | 16#1F80# .. 16#1F8F#
               | 16#1FB0# .. 16#1FB4# | 16#1FB6# .. 16#1FBC# => return Alpha;
            when 16#1F10# .. 16#1F1F# | 16#1F72# .. 16#1F73# | 16#1FC8# .. 16#1FC9# => return Epsilon;
            when 16#1F20# .. 16#1F2F# | 16#1F74# .. 16#1F75# | 16#1F90# .. 16#1F9F#
               | 16#1FC2# .. 16#1FC4# | 16#1FC6# .. 16#1FC7# | 16#1FCA# .. 16#1FCC# => return Eta;
            when 16#1F30# .. 16#1F3F# | 16#1F76# .. 16#1F77# | 16#1FD0# .. 16#1FD3#
               | 16#1FD6# .. 16#1FDB# => return Iota;
            when 16#1F40# .. 16#1F4F# | 16#1F78# .. 16#1F79# | 16#1FF8# .. 16#1FF9# => return Omicron;
            when 16#1FE4# .. 16#1FE5# | 16#1FEC# => return Rho;
            when 16#1F50# .. 16#1F5F# | 16#1F7A# .. 16#1F7B# | 16#1FE0# .. 16#1FE3#
               | 16#1FE6# .. 16#1FEB# => return Upsilon;
            when 16#1F60# .. 16#1F6F# | 16#1F7C# .. 16#1F7D# | 16#1FA0# .. 16#1FAF#
               | 16#1FF2# .. 16#1FF4# | 16#1FF6# .. 16#1FF7# | 16#1FFA# .. 16#1FFC# => return Omega;
            when others => return Value;
         end case;
      end Polytonic_Base;

      --  The base letter of a lowercase Greek or Cyrillic letter with an
      --  accent, of a voiced kana, or Value itself.
      function Other_Base (Value : Natural) return Natural is
      begin
         case Value is
            when 16#3AC# => return 16#3B1#;
            when 16#3AD# => return 16#3B5#;
            when 16#3AE# => return 16#3B7#;
            when 16#3AF# | 16#390# | 16#3CA# => return 16#3B9#;
            when 16#3CC# => return 16#3BF#;
            when 16#3CD# | 16#3B0# | 16#3CB# => return 16#3C5#;
            when 16#3CE# => return 16#3C9#;
            when 16#3C2# => return 16#3C3#;
            when 16#450# | 16#451# | 16#4D7# => return 16#435#;
            when 16#453# => return 16#433#;
            when 16#457# => return 16#456#;
            when 16#45C# => return 16#43A#;
            when 16#439# | 16#45D# | 16#4E3# | 16#4E5# => return 16#438#;
            when 16#45E# | 16#4EF# | 16#4F1# | 16#4F3# => return 16#443#;
            when 16#4C2# | 16#4DD# => return 16#436#;
            when 16#4D1# | 16#4D3# => return 16#430#;
            when 16#4DF# => return 16#437#;
            when 16#4E7# => return 16#43E#;
            when 16#4ED# => return 16#44D#;
            when 16#4F5# => return 16#447#;
            when 16#4F9# => return 16#44B#;
            --  Hiragana, then katakana (the same layout 16#60# on): a voiced
            --  or half-voiced kana folds to the plain one before it.
            when 16#304C# .. 16#3062# | 16#30AC# .. 16#30C2# =>
               return (if Value mod 2 = 0 then Value - 1 else Value);
            when 16#3065# | 16#3067# | 16#3069# | 16#30C5# | 16#30C7# | 16#30C9# => return Value - 1;
            when 16#3070# .. 16#307D# => return Value - (Value - 16#306F#) mod 3;
            when 16#30D0# .. 16#30DD# => return Value - (Value - 16#30CF#) mod 3;
            when 16#3094# => return 16#3046#;
            when 16#30F4# => return 16#30A6#;
            when 16#30F7# .. 16#30FA# => return Value - 8;
            when 16#309E# | 16#30FE# => return Value - 1;
            when 16#1F00# .. 16#1FFF# => return Polytonic_Base (Value);
            when others => return Value;
         end case;
      end Other_Base;

      --  The codepoint at Index, without moving past it; Invalid at the end.
      function Peek return Natural is
         Ahead : Integer := Index;
         Value : Natural := Invalid;
      begin
         if Ahead <= Text'Last then
            Guikit.Utf8.Decode_Next_Codepoint (Text, Ahead, Value, Replacement_Codepoint => Invalid);
         end if;
         return Value;
      end Peek;

      --  Move Index past the codepoint Peek answered.
      procedure Skip is
         Ignored : Natural;
      begin
         Guikit.Utf8.Decode_Next_Codepoint (Text, Index, Ignored, Replacement_Codepoint => Invalid);
      end Skip;
   begin
      while Index <= Text'Last loop
         Start := Index;
         Guikit.Utf8.Decode_Next_Codepoint (Text, Index, Codepoint, Replacement_Codepoint => Invalid);
         if Codepoint = Invalid then
            Ada.Strings.Unbounded.Append (Result, Text (Start .. Index - 1));
         elsif Is_Mark (Codepoint) then
            null;
         elsif Codepoint in 16#1100# .. 16#1112# and then Peek in 16#1161# .. 16#1175# then
            --  A Hangul syllable stored as its jamo: composed, as Unicode
            --  composes it, so it sorts as the syllable a user types.
            declare
               Syllable : Natural := 16#AC00# + ((Codepoint - 16#1100#) * 21 + (Peek - 16#1161#)) * 28;
            begin
               Skip;
               if Peek in 16#11A8# .. 16#11C2# then
                  Syllable := Syllable + (Peek - 16#11A7#);
                  Skip;
               end if;
               Ada.Strings.Unbounded.Append (Result, Guikit.Utf8.Encode (Syllable));
            end;
         else
            declare
               Lowered : constant Natural := Lower (Codepoint);
               Base    : constant String := Latin_Base (Lowered);
            begin
               if Base /= "" then
                  Ada.Strings.Unbounded.Append (Result, Base);
               elsif Lowered < 16#80# then
                  Ada.Strings.Unbounded.Append (Result, Character'Val (Lowered));
               else
                  Ada.Strings.Unbounded.Append (Result, Guikit.Utf8.Encode (Other_Base (Lowered)));
               end if;
            end;
         end if;
      end loop;

      return Ada.Strings.Unbounded.To_String (Result);
   end Fold_For_Sort;

   function Fold_Case (Text : String) return String is
      --  Never a codepoint: marks a byte that starts no UTF-8 character.
      Invalid : constant := 16#11_0000#;
      Result  : Ada.Strings.Unbounded.Unbounded_String;
      Index   : Integer := Text'First;
      Run     : Integer := Text'First;

      --  A well-formed run, folded through Unicode.
      function Fold_Run (Run_Text : String) return String is
      begin
         if (for all C of Run_Text => Character'Pos (C) < 128) then
            return To_Lower_Ascii (Run_Text);
         end if;
         declare
            Composed : constant String :=
              (if I18N.Normalization.Available then I18N.Normalization.Normalize (Run_Text, I18N.Normalization.NFC)
               else Run_Text);
         begin
            return Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode
              (Ada.Wide_Wide_Characters.Handling.To_Lower
                 (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Composed)));
         end;
      exception
         when Swallowed : others =>
            Files.Diagnostics.Note (Swallowed, "Files.Types");
            return To_Lower_Ascii (Run_Text);
      end Fold_Run;
   begin
      if (for all C of Text => Character'Pos (C) < 128) then
         return To_Lower_Ascii (Text);
      end if;
      while Index <= Text'Last loop
         declare
            Start : constant Integer := Index;
            Code  : Natural;
         begin
            Guikit.Utf8.Decode_Next_Codepoint (Text, Index, Code, Replacement_Codepoint => Invalid);
            if Code = Invalid then
               --  The run before it is folded; the stray byte stays as is.
               Ada.Strings.Unbounded.Append (Result, Fold_Run (Text (Run .. Start - 1)));
               Ada.Strings.Unbounded.Append (Result, Text (Start .. Index - 1));
               Run := Index;
            end if;
         end;
      end loop;
      Ada.Strings.Unbounded.Append (Result, Fold_Run (Text (Run .. Text'Last)));
      return Ada.Strings.Unbounded.To_String (Result);
   end Fold_Case;

   function Trim_To_Character (Raw : String) return String is
      Lead : Natural := Raw'Last;
   begin
      --  Step back over at most three continuation bytes (10xxxxxx).
      while Lead >= Raw'First
        and then Raw'Last - Lead < 3
        and then Is_Continuation (Raw (Lead))
      loop
         Lead := Lead - 1;
      end loop;
      if Lead < Raw'First then
         return Raw;
      end if;
      declare
         Code   : constant Natural := Character'Pos (Raw (Lead));
         Needed : constant Natural :=
           (if Code in 16#C0# .. 16#DF# then 2
            elsif Code in 16#E0# .. 16#EF# then 3
            elsif Code in 16#F0# .. 16#F7# then 4
            else 1);
      begin
         if Raw'Last - Lead + 1 < Needed then
            return Raw (Raw'First .. Lead - 1);
         end if;
         return Raw;
      end;
   end Trim_To_Character;

   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean
   is
   begin
      if Needle = "" then
         return True;
      end if;

      return Ada.Strings.Fixed.Index (Fold_Case (Haystack), Fold_Case (Needle)) > 0;
   end Contains_Case_Insensitive;

   function Move_Column
     (Order    : Detail_Column_Order;
      Column   : Detail_Column;
      To_Index : Detail_Column_Index)
      return Detail_Column_Order
   is
      Target  : Detail_Column_Index := To_Index;
      From    : Detail_Column_Index := Detail_Column_Index'First;
      Found   : Boolean := False;
      Reduced : Detail_Column_Order;
      Count   : Natural := 0;
      Result  : Detail_Column_Order;
      Read    : Natural := 0;
   begin
      --  Name is pinned to the first slot and never moves; nor may any column
      --  displace it from the first slot.
      if Column = Name_Column then
         return Order;
      elsif Target < Detail_Column_Index'First + 1 then
         Target := Detail_Column_Index'First + 1;
      end if;

      --  Collect the order minus Column into Reduced, recording Column's slot.
      for Index in Order'Range loop
         if Order (Index) = Column then
            From := Index;
            Found := True;
         else
            Count := Count + 1;
            Reduced (Count) := Order (Index);
         end if;
      end loop;

      if not Found or else From = Target then
         return Order;
      end if;

      --  Re-emit the reduced sequence, inserting Column at the target slot.
      for Index in Result'Range loop
         if Index = Target then
            Result (Index) := Column;
         else
            Read := Read + 1;
            Result (Index) := Reduced (Read);
         end if;
      end loop;

      return Result;
   end Move_Column;

end Files.Types;
