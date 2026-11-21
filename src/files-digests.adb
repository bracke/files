with Files.Hex_Text;

package body Files.Digests is

   use Ada.Streams;

   function Hex (Digest : CryptoLib.Hashes.SHA256_Digest) return Hex_Digest is
      Result : Hex_Digest;
   begin
      for Index in Digest'Range loop
         Result ((Index - Digest'First) * 2 + 1 .. (Index - Digest'First) * 2 + 2) :=
           Files.Hex_Text.Byte_Lower (Natural (Digest (Index)));
      end loop;
      return Result;
   end Hex;

   function To_Bytes (Text : String) return Stream_Element_Array is
      Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
   begin
      for Index in Text'Range loop
         Data (Stream_Element_Offset (Index - Text'First + 1)) := Character'Pos (Text (Index));
      end loop;
      return Data;
   end To_Bytes;

   procedure Update (Context : in out CryptoLib.Hashes.SHA256_Context; Text : String) is
   begin
      if Text'Length > 0 then
         CryptoLib.Hashes.Update (Context, To_Bytes (Text));
      end if;
   end Update;

   function SHA256_Hex (Text : String) return Hex_Digest is
      Context : CryptoLib.Hashes.SHA256_Context;
   begin
      CryptoLib.Hashes.Initialize_SHA256 (Context);
      Update (Context, Text);
      return Hex (CryptoLib.Hashes.Finalize (Context));
   end SHA256_Hex;
end Files.Digests;
