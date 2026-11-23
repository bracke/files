package body Files.Images.Testing is

   function U32_BE
     (Data  : Ada.Streams.Stream_Element_Array;
      First : Ada.Streams.Stream_Element_Offset)
      return Natural renames Files.Images.U32_BE;

end Files.Images.Testing;
