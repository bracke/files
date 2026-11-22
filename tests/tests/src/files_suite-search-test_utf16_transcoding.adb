with Files.Text_Encoding;
separate (Files_Suite.Search)
   --  UTF-16 text is told by its byte order mark, or by its NUL pattern when
   --  it has none, and transcoded unit by unit: a surrogate pair becomes one
   --  character, a lone or mismatched surrogate the replacement character,
   --  and a unit or pair the read cut short is dropped.
   procedure Test_Utf16_Transcoding (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Text_Encoding.Utf16_Layout;

      function B (Value : Natural) return Character is (Character'Val (Value));

      function U8 (Text : Wide_Wide_String) return String is
        (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));

      --  Each unit of Units as two bytes in the order Little says.
      function Utf16 (Units : Wide_Wide_String; Little : Boolean) return String is
         Result : String (1 .. 2 * Units'Length);
         At_Byte : Positive := 1;
      begin
         for Unit of Units loop
            declare
               Code : constant Natural := Wide_Wide_Character'Pos (Unit);
               High : constant Character := B (Code / 256);
               Low  : constant Character := B (Code mod 256);
            begin
               Result (At_Byte .. At_Byte + 1) := (if Little then Low & High else High & Low);
               At_Byte := At_Byte + 2;
            end;
         end loop;
         return Result;
      end Utf16;

      Le_Bom : constant String := B (16#FF#) & B (16#FE#);
      Be_Bom : constant String := B (16#FE#) & B (16#FF#);
      --  U+1F600 as its surrogate pair.
      Pair   : constant Wide_Wide_String :=
        Wide_Wide_Character'Val (16#D83D#) & Wide_Wide_Character'Val (16#DE00#);
      Smile  : constant String := U8 ([Wide_Wide_Character'Val (16#1F600#)]);
      Fffd   : constant String := U8 ([Wide_Wide_Character'Val (16#FFFD#)]);

      function Text_Of (Raw : String) return String renames Files.Text_Encoding.Searchable_Text;
   begin
      --  The layout.
      Assert (Files.Text_Encoding.Utf16_Layout_Of (Le_Bom & Utf16 ("ab", True))
              = Files.Text_Encoding.Little_Endian_Marked, "a little-endian mark");
      Assert (Files.Text_Encoding.Utf16_Layout_Of (Be_Bom & Utf16 ("ab", False))
              = Files.Text_Encoding.Big_Endian_Marked, "a big-endian mark");
      Assert (Files.Text_Encoding.Utf16_Layout_Of (Utf16 ("plain text", True))
              = Files.Text_Encoding.Little_Endian, "unmarked little-endian text by its NULs");
      Assert (Files.Text_Encoding.Utf16_Layout_Of (Utf16 ("plain text", False))
              = Files.Text_Encoding.Big_Endian, "unmarked big-endian text by its NULs");
      Assert (Files.Text_Encoding.Utf16_Layout_Of ("plain text") = Files.Text_Encoding.Not_Utf16,
              "ASCII is not UTF-16");

      --  The text.
      Assert_Equal (Text_Of (Le_Bom & Utf16 ("caf" & Wide_Wide_Character'Val (16#E9#), True)), U8 ("café"),
                    "little-endian text after its mark");
      Assert_Equal (Text_Of (Be_Bom & Utf16 ("caf" & Wide_Wide_Character'Val (16#E9#), False)), U8 ("café"),
                    "big-endian text after its mark");
      Assert_Equal (Text_Of (Le_Bom & Utf16 ("a" & Pair & "b", True)), "a" & Smile & "b",
                    "a surrogate pair is one character");
      Assert_Equal (Text_Of (Be_Bom & Utf16 ("a" & Pair & "b", False)), "a" & Smile & "b",
                    "a big-endian surrogate pair is one character");
      Assert_Equal
        (Text_Of (Le_Bom & Utf16 ("a" & Wide_Wide_Character'Val (16#DE00#) & "b", True)), "a" & Fffd & "b",
         "a lone low surrogate is the replacement character");
      Assert_Equal
        (Text_Of (Le_Bom & Utf16 ("a" & Wide_Wide_Character'Val (16#D83D#) & "b", True)), "a" & Fffd & "b",
         "a high surrogate without its low half is the replacement character");
      Assert_Equal (Text_Of (Le_Bom & Utf16 ("ab", True) & B (16#63#)), "ab",
                    "an odd trailing byte, half a unit, is dropped");
      Assert_Equal (Text_Of (Le_Bom & Utf16 ("ab" & Pair (Pair'First .. Pair'First), True)), "ab",
                    "a pair the read cut after its high half is dropped");
      Assert_Equal (Text_Of (Le_Bom), "", "a mark alone is empty text");
   end Test_Utf16_Transcoding;
