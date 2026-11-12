separate (Files.File_System)
function Read_Preview_Text
  (Path : String; Max_Bytes : Natural; Success, Complete : out Boolean) return String
is
begin
   --  A preview deliberately accepts a leading prefix; Complete tells the
   --  caller whether that prefix is the whole file. Strict decoders call
   --  Read_Bounded_Regular_File directly and require Complete.
   return Read_Bounded_Regular_File (Path, Max_Bytes, Success, Complete);
end Read_Preview_Text;
