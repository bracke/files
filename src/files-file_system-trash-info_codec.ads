--  The Path= value of a freedesktop.org trash info file: the original path,
--  percent-encoded as RFC 2396 allows (the Trash specification's
--  "escaped as in URIs"). Encode writes it; Decode reads one back, and
--  Decode (Encode (P)) = P for every P.
package Files.File_System.Trash.Info_Codec is
   --  @param Path An original path, as bytes.
   --  @return Path with every byte but the unreserved ones (letters,
   --    digits, '-', '.', '_', '~') and '/' written as %XX (upper-case hex).
   function Encode (Path : String) return String;

   --  @param Value A Path= value.
   --  @return Value with each %XX (either hex case) read back as its byte;
   --    a '%' not followed by two hex digits is kept as it is.
   function Decode (Value : String) return String;
end Files.File_System.Trash.Info_Codec;
