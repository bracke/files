with GNAT.CRC32;

package body Files_Suite.Support.Images is

   function Be32 (Value : Interfaces.Unsigned_32) return String is
      use Interfaces;
   begin
      return
        [Character'Val (Shift_Right (Value, 24) and 16#FF#), Character'Val (Shift_Right (Value, 16) and 16#FF#),
         Character'Val (Shift_Right (Value, 8) and 16#FF#), Character'Val (Value and 16#FF#)];
   end Be32;

   --  A size as Be32 writes it.
   function Be32 (Value : Natural) return String is (Be32 (Interfaces.Unsigned_32 (Value)));

   function Byte (Value : Natural) return Character is
   begin
      return Character'Val (Value);
   end Byte;

   function Minimal_Png_Header
     (Width  : Natural;
      Height : Natural)
      return String is
   begin
      return
        Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#) &
        Byte (0) & Byte (0) & Byte (0) & Byte (13) & "IHDR" &
        Be32 (Width) & Be32 (Height) &
        Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
   end Minimal_Png_Header;

   function Stored_Zlib_Stream
     (Payload : String)
      return String
   is
      S1 : Natural := 1;
      S2 : Natural := 0;
      Len : constant Natural := Payload'Length;
      NLen : constant Natural := 65_535 - Len;
   begin
      for Value of Payload loop
         S1 := (S1 + Character'Pos (Value)) mod 65_521;
         S2 := (S2 + S1) mod 65_521;
      end loop;

      return
        Byte (16#78#) & Byte (16#01#) &
        Byte (16#01#) &
        Byte (Len mod 256) & Byte ((Len / 256) mod 256) &
        Byte (NLen mod 256) & Byte ((NLen / 256) mod 256) &
        Payload &
        Byte ((S2 / 256) mod 256) & Byte (S2 mod 256) &
        Byte ((S1 / 256) mod 256) & Byte (S1 mod 256);
   end Stored_Zlib_Stream;

   function Chunk
     (Kind : String;
      Data : String)
      return String
   is
      Context : GNAT.CRC32.CRC32;
      Value   : Interfaces.Unsigned_32;
   begin
      GNAT.CRC32.Initialize (Context);
      GNAT.CRC32.Update (Context, Kind & Data);
      Value := GNAT.CRC32.Get_Value (Context);
      return
        Be32 (Natural'(Data'Length)) & Kind & Data & Be32 (Value);
   end Chunk;

   function Minimal_Png_RGB
     (Width   : Natural;
      Height  : Natural;
      Payload : String)
      return String is
   begin
      return
        Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#) &
        Chunk
          ("IHDR",
           Be32 (Width) & Be32 (Height) &
           Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0)) &
        Chunk ("IDAT", Stored_Zlib_Stream (Payload)) &
        Chunk ("IEND", "");
   end Minimal_Png_RGB;

   function Red_Jpeg_8x8 return String is
      Hex : constant String :=
           "FFD8FFE000104A46494600010100000100010000FFDB0043000302020302020303030304030304050805050404050A07" &
           "0706080C0A0C0C0B0A0B0B0D0E12100D0E110E0B0B1016101113141515150C0F171816141812141514FFDB0043010304" &
           "0405040509050509140D0B0D141414141414141414141414141414141414141414141414141414141414141414141414" &
           "1414141414141414141414141414FFC00011080008000803011100021101031101FFC400140001000000000000000000" &
           "00000000000008FFC40014100100000000000000000000000000000000FFC40015010101000000000000000000000000" &
           "00000709FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F003A03154DFFD9";
      Bytes : String (1 .. Hex'Length / 2);
   begin
      for Index in Bytes'Range loop
         Bytes (Index) :=
           Character'Val (Natural'Value ("16#" & Hex (Hex'First + 2 * (Index - 1) .. Hex'First + 2 * Index - 1) & "#"));
      end loop;
      return Bytes;
   end Red_Jpeg_8x8;

   function Minimal_Jpeg_With_Fill
     (Width  : Natural;
      Height : Natural)
      return String is
   begin
      return
        Byte (16#FF#) & Byte (16#D8#) &
        Byte (16#FF#) & Byte (16#FF#) & Byte (16#C0#) &
        Byte (0) & Byte (8) & Byte (8) &
        Byte ((Height / 16#100#) mod 256) &
        Byte (Height mod 256) &
        Byte ((Width / 16#100#) mod 256) &
        Byte (Width mod 256);
   end Minimal_Jpeg_With_Fill;

end Files_Suite.Support.Images;
