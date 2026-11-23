with Ada.Streams;

--  Test-only access to private subprograms of Files.Images, kept out of the program.
package Files.Images.Testing is

   --  The big-endian 32-bit value at Data (First .. First + 3), as image
   --  formats store sizes and lengths. A value past Natural'Last (the high
   --  bit set, which only a crafted file has) comes back as Natural'Last, so
   --  a caller's bound refuses it rather than the arithmetic raising.
   --
   --  @param Data Bytes holding the value.
   --  @param First Index of its most significant byte.
   --  @return The value, clamped to Natural'Last.
   function U32_BE
     (Data  : Ada.Streams.Stream_Element_Array;
      First : Ada.Streams.Stream_Element_Offset)
      return Natural;

end Files.Images.Testing;
