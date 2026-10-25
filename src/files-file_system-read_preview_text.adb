separate (Files.File_System)
function Read_Preview_Text
  (Path : String; Max_Bytes : Natural; Success : out Boolean) return String
is
   Complete : Boolean;
   Result : constant String := Read_Bounded_Regular_File
     (Path, Max_Bytes, Success, Complete);

   procedure Ignore_Completion (Value : Boolean) is
      pragma Unreferenced (Value);
   begin
      null;
   end Ignore_Completion;
begin
   --  A preview deliberately accepts a leading prefix; strict decoders call
   --  Read_Bounded_Regular_File directly and require Complete.
   Ignore_Completion (Complete);
   return Result;
end Read_Preview_Text;
