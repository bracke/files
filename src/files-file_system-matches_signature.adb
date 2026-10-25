separate (Files.File_System)
--  True when the first Pattern'Length bytes read into Buffer (of which Last
--  were read) equal Pattern. Buffer and Pattern are both 1-based.
function Matches_Signature
  (Buffer  : Ada.Streams.Stream_Element_Array;
   Last    : Ada.Streams.Stream_Element_Offset;
   Pattern : Ada.Streams.Stream_Element_Array)
   return Boolean
is
begin
   return Last >= Pattern'Last and then Buffer (Pattern'Range) = Pattern;
end Matches_Signature;
