with Ada.Streams;
with CryptoLib.Hashes;

--  SHA-256 as the program writes it: 64 lower-case hex digits. The content,
--  tree and thumbnail-key digests all use these, so they cannot differ in
--  how a digest is spelled.
private package Files.File_System.Digests is

   --  A SHA-256 digest written as lower-case hex.
   subtype Hex_Digest is String (1 .. 64);

   --  @param Digest A finished SHA-256 digest.
   --  @return Digest as 64 lower-case hex digits.
   function Hex (Digest : CryptoLib.Hashes.SHA256_Digest) return Hex_Digest;

   --  @param Text Bytes held in a String.
   --  @return The same bytes as a stream element array indexed from 1.
   function To_Bytes (Text : String) return Ada.Streams.Stream_Element_Array;

   --  Feed Text's bytes to Context; an empty Text adds nothing.
   --
   --  @param Context The running hash.
   --  @param Text Bytes held in a String.
   procedure Update (Context : in out CryptoLib.Hashes.SHA256_Context; Text : String);

   --  @param Text Bytes held in a String.
   --  @return The SHA-256 of Text as lower-case hex.
   function SHA256_Hex (Text : String) return Hex_Digest;
end Files.File_System.Digests;
