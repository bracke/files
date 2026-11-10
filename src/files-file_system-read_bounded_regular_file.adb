with Files.Capped_Files;
separate (Files.File_System)
--  Capped_Files.Read_Capped, keeping the start of a file larger than
--  Max_Bytes: Complete says whether that was all of it.
function Read_Bounded_Regular_File
  (Path : String; Max_Bytes : Natural;
   Success, Complete : out Boolean) return String
is
   use type Files.Capped_Files.Read_Status;
   Status : Files.Capped_Files.Read_Status;
   Bytes  : constant String :=
     Files.Capped_Files.Read_Capped
       (Path, Max_Bytes, Files.Capped_Files.Refuse_Links, Status, Keep_Prefix => True);
begin
   Success := Status /= Files.Capped_Files.Read_Failed;
   Complete := Status = Files.Capped_Files.Read_Complete;
   return Bytes;
end Read_Bounded_Regular_File;
