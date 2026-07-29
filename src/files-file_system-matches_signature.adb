separate (Files.File_System)
   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean
   is
      use type Ada.Streams.Stream_Element_Array;
   begin
      return Last >= Pattern'Last and then Buffer (Pattern'Range) = Pattern;
   end Matches_Signature;
