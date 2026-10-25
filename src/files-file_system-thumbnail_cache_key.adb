separate (Files.File_System)
function Thumbnail_Cache_Key
  (Source_Path : String)
   return String
is
   use Ada.Streams;
   Text : constant String :=
     Source_Path & ASCII.NUL
     & Files.File_Identities.Token (Source_Path) & ASCII.NUL
     & Files.File_Identities.Revision (Source_Path);
   Data : Stream_Element_Array (1 .. Stream_Element_Offset (Text'Length));
   Context : CryptoLib.Hashes.SHA256_Context;
   Digest : CryptoLib.Hashes.SHA256_Digest;
   Hex : constant String := "0123456789abcdef";
   Result : String (1 .. 64);
begin
   for Index in Text'Range loop
      Data (Stream_Element_Offset (Index - Text'First + 1)) :=
        Stream_Element (Character'Pos (Text (Index)));
   end loop;
   CryptoLib.Hashes.Initialize_SHA256 (Context);
   CryptoLib.Hashes.Update (Context, Data);
   Digest := CryptoLib.Hashes.Finalize (Context);
   for Index in Digest'Range loop
      Result ((Index - Digest'First) * 2 + 1) :=
        Hex (Natural (Digest (Index)) / 16 + 1);
      Result ((Index - Digest'First) * 2 + 2) :=
        Hex (Natural (Digest (Index)) mod 16 + 1);
   end loop;
   return Result;
end Thumbnail_Cache_Key;
